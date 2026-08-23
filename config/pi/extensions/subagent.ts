import { type ChildProcess, execFileSync, spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { StringDecoder } from 'node:string_decoder';
import { StringEnum } from '@earendil-works/pi-ai';
import {
  type ExtensionAPI,
  type ExtensionContext,
  getAgentDir,
} from '@earendil-works/pi-coding-agent';
import { Text } from '@earendil-works/pi-tui';
import { Type } from 'typebox';

// Subagents are long-lived `pi --mode rpc` peers. A child auto-discovers this
// same extension, so the depth counter is the recursion guard: a counter rather
// than a boolean keeps the invariant inspectable from `env` inside a child.
const DEPTH_ENV = 'PI_SUBAGENT_DEPTH';
const NAME_ENV = 'PI_SUBAGENT_NAME';

// A subagent is a peer, not a leaf: it gets the dispatch tools too. That makes
// the tree height the thing to bound. 2 buys the shape people actually want —
// a lead splits the work, each worker splits its own — and stops there.
const MAX_DEPTH = 2;

const DEPTH = Number(process.env[DEPTH_ENV] ?? '0') || 0;
const IS_ROOT = DEPTH === 0;
const CAN_SPAWN = DEPTH < MAX_DEPTH;

// The root answers to a human who can watch the fleet and interrupt it; a
// subagent has no such supervision, so its own fan-out is deliberately narrow.
// Nothing caps spend, so depth and this taper are the only bound on how large a
// tree can get — 20 at the root, 4 under each of those.
const MAX_LIVE_CHILDREN = IS_ROOT ? 20 : 4;

// Every await on a child is bounded. A parent tool that blocks forever on a
// child wedges the human's session, which is strictly worse than a stale answer.
const COMMAND_TIMEOUT_MS = 20_000;
const ACK_TIMEOUT_MS = 60_000;
const WAIT_CAP_SECONDS = 600;
const STARTUP_TIMEOUT_MS = 60_000;
const TERM_GRACE_MS = 2_000;
const KILL_GRACE_MS = 5_000;
const SPAWN_STAGGER_MS = 200;
const STALL_MS = 5 * 60_000;

const MAX_LINE_BYTES = 4 * 1024 * 1024;
const STDERR_RING_BYTES = 8 * 1024;
const EVENT_RING = 1500;
const TOOL_TEXT_CAP = 8_000;
const SNIPPET_CAP = 1_200;
const NEWS_CAP = 4_000;

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

// Copied verbatim from pi's dist/modes/rpc/jsonl.js. Node readline also splits
// on U+2028/U+2029, which are legal inside JSON strings, so it is not
// protocol-compliant here. The only addition is the oversized-line guard.
function attachJsonlLineReader(
  stream: NodeJS.ReadableStream,
  onLine: (line: string) => void,
  onOversized?: () => void,
): () => void {
  const decoder = new StringDecoder('utf8');
  let buffer = '';
  const emitLine = (line: string) => {
    onLine(line.endsWith('\r') ? line.slice(0, -1) : line);
  };
  const onData = (chunk: Buffer | string) => {
    buffer += typeof chunk === 'string' ? chunk : decoder.write(chunk);
    while (true) {
      const newlineIndex = buffer.indexOf('\n');
      if (newlineIndex === -1) break;
      emitLine(buffer.slice(0, newlineIndex));
      buffer = buffer.slice(newlineIndex + 1);
    }
    if (buffer.length > MAX_LINE_BYTES) {
      buffer = '';
      onOversized?.();
    }
  };
  const onEnd = () => {
    buffer += decoder.end();
    if (buffer.length > 0) {
      emitLine(buffer);
      buffer = '';
    }
  };
  stream.on('data', onData);
  stream.on('end', onEnd);
  return () => {
    stream.off('data', onData);
    stream.off('end', onEnd);
  };
}

// pi is installed from the nix store behind a `node .../cli.js` shim, so a bare
// spawn("pi") depends on PATH being inherited intact. Re-enter the exact script
// this process is running whenever that is a real file on disk; the /$bunfs/
// check rejects bun's virtual single-file-executable path, which does not exist.
function getPiInvocation(args: string[]): { command: string; args: string[] } {
  const currentScript = process.argv[1];
  const isBunVirtualScript = currentScript?.startsWith('/$bunfs/root/');
  if (currentScript && !isBunVirtualScript && fs.existsSync(currentScript)) {
    return { command: process.execPath, args: [currentScript, ...args] };
  }

  const execName = path.basename(process.execPath).toLowerCase();
  const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
  if (!isGenericRuntime) return { command: process.execPath, args };

  return { command: 'pi', args };
}

function cap(text: string, limit: number): string {
  if (text.length <= limit) return text;
  return `${text.slice(0, limit)}\n[...${text.length - limit} chars omitted]`;
}

function firstLine(text: string, limit = 160): string {
  const line = text.replace(/\s+/g, ' ').trim();
  return line.length > limit ? `${line.slice(0, limit)}…` : line;
}

function fmtAge(ms: number): string {
  const s = Math.max(0, Math.round(ms / 1000));
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m${s % 60}s`;
  return `${Math.floor(m / 60)}h${m % 60}m`;
}

function fmtCost(n: number): string {
  return `$${n.toFixed(n < 1 ? 3 : 2)}`;
}

const STOPWORDS = new Set([
  'the',
  'a',
  'an',
  'and',
  'or',
  'to',
  'of',
  'in',
  'on',
  'for',
  'with',
  'this',
  'that',
  'is',
  'are',
  'be',
  'please',
  'then',
  'from',
  'into',
  'using',
  'use',
  'all',
  'any',
  'it',
  'its',
  'by',
  'at',
  'as',
  'we',
  'you',
  'your',
  'my',
  'our',
  'make',
  'do',
  'find',
  'out',
  'should',
  'can',
  'not',
  'but',
]);

function kebab(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40);
}

// Names derive from the task so a handle is self-documenting in the roster line
// and in the log filenames; a random word list would not be.
function deriveName(
  task: string,
  taken: Set<string>,
  explicit?: string,
): string {
  let base = explicit ? kebab(explicit) : '';
  if (!base) {
    const words = task
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter((w) => w.length > 2 && !STOPWORDS.has(w))
      .slice(0, 3);
    base = kebab(words.join('-'));
  }
  if (!base) base = 'agent';
  if (!taken.has(base)) return base;
  for (let i = 2; i < 100; i++) {
    const candidate = `${base}-${i}`;
    if (!taken.has(candidate)) return candidate;
  }
  return `${base}-${Date.now()}`;
}

function isAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return (err as NodeJS.ErrnoException).code === 'EPERM';
  }
}

// pids are recycled, so never signal a swept pid without confirming it still
// looks like one of our orphaned children. pi rewrites its process title to a
// bare "pi", so the argv is not enough to tell an orphan from the human's own
// interactive session — but an orphan has been reparented to init, and an
// interactive pi has a real shell as its parent.
function looksLikeOrphanedChild(pid: number): boolean {
  try {
    const out = execFileSync(
      'ps',
      ['-p', String(pid), '-o', 'ppid=,command='],
      { timeout: 2000 },
    )
      .toString()
      .trim();
    const [ppid, ...rest] = out.split(/\s+/);
    const command = rest.join(' ');
    const isPi =
      /(^|[/\\])pi$/.test(rest[0] ?? '') ||
      (command.includes('--mode') && command.includes('rpc'));
    return isPi && Number(ppid) === 1;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// child-side mode
// ---------------------------------------------------------------------------

function registerChildTools(pi: ExtensionAPI) {
  pi.registerTool({
    name: 'message_parent',
    label: 'Message Parent',
    description: [
      'Send a message to the parent agent that dispatched you. The parent sees it',
      'asynchronously and may reply by injecting a message into your context.',
    ].join(' '),
    promptSnippet: 'Send a message or question to the parent agent',
    promptGuidelines: [
      "Use message_parent when a decision is genuinely the parent's to make.",
    ],
    parameters: Type.Object({
      message: Type.String({
        description:
          'Self-contained message; the parent does not see your transcript',
      }),
      expects_reply: Type.Boolean({
        description:
          'True if you are blocked without an answer; false if this is informational',
      }),
    }),
    async execute(_toolCallId, params) {
      const tail = params.expects_reply
        ? 'The parent may reply by injecting a message into your context. Keep making progress on anything that does not depend on the answer.'
        : 'No reply is expected. Continue.';
      return {
        content: [{ type: 'text', text: `Delivered to parent.\n${tail}` }],
        details: { expects_reply: params.expects_reply },
      };
    },
  });
}

// ---------------------------------------------------------------------------
// parent-side: per-child protocol client and state
// ---------------------------------------------------------------------------

const KEEP_EVENTS = new Set([
  'agent_start',
  'agent_settled',
  'turn_start',
  'turn_end',
  'message_start',
  'message_end',
  'tool_execution_start',
  'tool_execution_end',
  'queue_update',
  'extension_error',
  'extension_ui_request',
  'compaction_start',
  'response',
  'message_update',
]);

type LogRecord = { t: number; kind: string; text: string };
type NewsKind = 'finished' | 'spoke' | 'died' | 'stalled' | 'conflict';
interface News {
  kind: NewsKind;
  name: string;
  at: number;
  text: string;
  wake: boolean;
}

type AckOutcome =
  | 'delivered'
  | 'child_exited'
  | 'timeout'
  | 'aborted'
  | 'not_delivered';
interface AckWaiter {
  settle: (outcome: AckOutcome) => void;
  armed: boolean;
}

interface SpawnSpec {
  task: string;
  name?: string;
  system_prompt?: string;
  model?: string;
}

class Subagent {
  readonly name: string;
  readonly task: string;
  readonly logPath: string;
  readonly startedAt = Date.now();

  proc?: ChildProcess;
  state: 'starting' | 'working' | 'idle' | 'exited' = 'starting';
  lastActivityAt = Date.now();
  turns = 0;
  costUsd = 0;
  // What this child's own subagents have spent. Its usage events only ever
  // account for its own tokens, so without this a $3 subtree reads as $0.04.
  descendantCostUsd = 0;
  contextPercent?: number;
  currentTool?: string;
  lastText = '';
  // Assembled from text_delta events so the attach view can show a reply as it
  // is written. message_update carries no cumulative snapshot, only the delta.
  partialText = '';
  exitCode?: number | null;
  exitSignal?: NodeJS.Signals | null;
  stopping = false;
  stalledReported = false;
  droppedLines = 0;
  sessionFile?: string;
  filesTouched = new Set<string>();

  private readonly records: LogRecord[] = [];
  private readonly acks = new Map<string, AckWaiter>();
  private readonly pending = new Map<
    string,
    {
      resolve: (v: any) => void;
      reject: (e: Error) => void;
      timer: NodeJS.Timeout;
    }
  >();
  private readonly exitWaiters = new Set<() => void>();
  private readonly settleWaiters = new Set<() => void>();
  private sendChain: Promise<unknown> = Promise.resolve();
  private stderrRing = '';
  private logStream?: fs.WriteStream;
  private tmpDir?: string;
  private ranSinceSettle = false;

  constructor(spec: SpawnSpec, name: string, logPath: string) {
    this.name = name;
    this.task = spec.task;
    this.logPath = logPath;
  }

  get alive(): boolean {
    return this.state !== 'exited';
  }

  // Cost is reported, never enforced; this is the only figure worth showing.
  get subtreeCostUsd(): number {
    return this.costUsd + this.descendantCostUsd;
  }

  // -- lifecycle ------------------------------------------------------------

  start(
    command: string,
    args: string[],
    cwd: string,
    env: NodeJS.ProcessEnv,
    tmpDir: string,
  ) {
    this.tmpDir = tmpDir;
    fs.mkdirSync(path.dirname(this.logPath), { recursive: true });
    this.logStream = fs.createWriteStream(this.logPath, { flags: 'a' });

    // stdin MUST be a pipe owned solely by this process: rpc mode exits on stdin
    // EOF, and the write end dies with the parent, so every form of parent death
    // (including SIGKILL, which skips session_shutdown) reaps the child.
    // Never `detached`, never stdio[0] "ignore".
    const proc = spawn(command, args, {
      cwd,
      env,
      shell: false,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    this.proc = proc;

    attachJsonlLineReader(
      proc.stdout!,
      (line) => this.onLine(line),
      () => {
        this.droppedLines++;
      },
    );

    // An undrained stderr pipe fills at 64KB and blocks the child mid-turn
    // forever. pi rebinds console.log to stderr, so this carries child logging.
    proc.stderr!.on('data', (chunk: Buffer) => {
      this.stderrRing = (this.stderrRing + chunk.toString()).slice(
        -STDERR_RING_BYTES,
      );
    });

    proc.on('error', (err) => {
      this.record('error', `spawn failed: ${err.message}`);
      this.onExit(1, null);
    });
    proc.on('exit', (code, signal) => this.onExit(code, signal));
  }

  private onExit(code: number | null, signal: NodeJS.Signals | null) {
    if (this.state === 'exited') return;
    this.state = 'exited';
    this.exitCode = code;
    this.exitSignal = signal;
    this.lastActivityAt = Date.now();
    this.record('exit', `exit code=${code} signal=${signal}`);
    this.logStream?.end();

    for (const [, waiter] of this.acks) waiter.settle('child_exited');
    this.acks.clear();
    for (const [, p] of this.pending) {
      clearTimeout(p.timer);
      p.reject(new Error(`subagent ${this.name} exited`));
    }
    this.pending.clear();
    for (const w of this.exitWaiters) w();
    this.exitWaiters.clear();
    for (const w of this.settleWaiters) w();
    this.settleWaiters.clear();

    // The temp prompt file must outlive the process: resolvePromptInput falls
    // back to treating the argument as literal text when the path is gone, so a
    // child that reloads resources after deletion would append the literal tmp
    // path to its own system prompt.
    if (this.tmpDir)
      fs.rm(this.tmpDir, { recursive: true, force: true }, () => {});
  }

  async stop(): Promise<void> {
    if (!this.proc || this.state === 'exited') return;
    this.stopping = true;
    const proc = this.proc;
    try {
      proc.stdin?.end();
    } catch {}
    const done = this.waitForExit();
    const term = setTimeout(() => {
      try {
        proc.kill('SIGTERM');
      } catch {}
    }, TERM_GRACE_MS);
    const kill = setTimeout(() => {
      try {
        proc.kill('SIGKILL');
      } catch {}
    }, KILL_GRACE_MS);
    await done;
    clearTimeout(term);
    clearTimeout(kill);
  }

  waitForExit(): Promise<void> {
    if (this.state === 'exited') return Promise.resolve();
    return new Promise((resolve) => this.exitWaiters.add(resolve));
  }

  waitForSettle(): Promise<void> {
    if (this.state === 'exited' || this.state === 'idle')
      return Promise.resolve();
    return new Promise((resolve) => this.settleWaiters.add(resolve));
  }

  // -- protocol -------------------------------------------------------------

  // The reader is fire-and-forget, so back-to-back commands would interleave
  // across await points. One command in flight per child, always correlated.
  send(
    type: string,
    extra: Record<string, unknown> = {},
    timeoutMs = COMMAND_TIMEOUT_MS,
    signal?: AbortSignal,
  ): Promise<any> {
    const run = async () => {
      if (signal?.aborted) throw new Error('cancelled');
      if (this.state === 'exited' || !this.proc?.stdin?.writable) {
        throw new Error(`subagent ${this.name} is not running`);
      }
      const id = randomUUID();
      const promise = new Promise<any>((resolve, reject) => {
        const fail = (msg: string) => {
          this.pending.delete(id);
          signal?.removeEventListener('abort', onAbort);
          reject(new Error(msg));
        };
        const timer = setTimeout(
          () =>
            fail(
              `subagent ${this.name}: ${type} timed out after ${timeoutMs}ms`,
            ),
          timeoutMs,
        );
        const onAbort = () => {
          clearTimeout(timer);
          fail('cancelled');
        };
        signal?.addEventListener('abort', onAbort, { once: true });
        this.pending.set(id, {
          resolve: (v) => {
            signal?.removeEventListener('abort', onAbort);
            resolve(v);
          },
          reject,
          timer,
        });
      });
      this.proc.stdin.write(`${JSON.stringify({ id, type, ...extra })}\n`);
      return promise;
    };
    const next = this.sendChain.then(run, run);
    this.sendChain = next.catch(() => {});
    return next;
  }

  private onLine(line: string) {
    if (!line) return;
    // Filter before JSON.parse: bash tool_execution_update carries the FULL
    // accumulated output every 100ms (up to 50KB, ~500KB/s per child), and
    // parsing it just to discard it is the whole cost.
    const head = line.slice(0, 240);
    const match = /"type"\s*:\s*"([a-z_]+)"/.exec(head);
    if (match && !KEEP_EVENTS.has(match[1])) return;

    let event: any;
    try {
      event = JSON.parse(line);
    } catch {
      return;
    }
    if (typeof event?.type !== 'string' || !KEEP_EVENTS.has(event.type)) return;

    this.lastActivityAt = Date.now();
    try {
      this.handleEvent(event);
    } catch {
      // A malformed event must never take down the parent's reader.
    }
  }

  private handleEvent(event: any) {
    switch (event.type) {
      case 'response': {
        const p = event.id ? this.pending.get(event.id) : undefined;
        if (!p) return;
        clearTimeout(p.timer);
        this.pending.delete(event.id);
        if (event.success === false)
          p.reject(new Error(String(event.error ?? 'command failed')));
        else p.resolve(event.data);
        return;
      }
      // Any child-side extension may call ctx.ui.confirm(); ctx.hasUI is true in
      // rpc mode and createDialogPromise has no default timeout, so an unanswered
      // dialog hangs the child forever. Always decline.
      case 'extension_ui_request': {
        const method = String(event.method ?? '');
        if (method === 'confirm')
          this.reply({
            type: 'extension_ui_response',
            id: event.id,
            confirmed: false,
          });
        else if (
          method === 'select' ||
          method === 'input' ||
          method === 'editor'
        ) {
          this.reply({
            type: 'extension_ui_response',
            id: event.id,
            cancelled: true,
          });
        }
        return;
      }
      case 'agent_start':
        this.state = 'working';
        this.ranSinceSettle = true;
        this.stalledReported = false;
        this.record('run', 'run started');
        return;
      case 'agent_settled': {
        this.state = 'idle';
        this.currentTool = undefined;
        this.record('settled', 'run settled');
        for (const [, waiter] of this.acks) {
          // Armed means the command response was already read, and stdout is
          // ordered, so this settle is strictly after our write. A message still
          // pending here is stranded (B1: nothing will drain the queue again).
          if (waiter.armed) waiter.settle('not_delivered');
        }
        for (const w of this.settleWaiters) w();
        this.settleWaiters.clear();
        if (this.ranSinceSettle) {
          this.ranSinceSettle = false;
          emitNews(
            this,
            'finished',
            this.lastText ? cap(this.lastText, SNIPPET_CAP) : '(no final text)',
          );
        }
        return;
      }
      case 'turn_start':
        this.turns++;
        this.partialText = '';
        return;
      case 'message_update': {
        const delta = event.assistantMessageEvent;
        if (delta?.type === 'text_start') this.partialText = '';
        else if (delta?.type === 'text_delta')
          this.partialText += String(delta.delta ?? '');
        else return;
        this.lastActivityAt = Date.now();
        notifyAttach();
        return;
      }
      case 'message_start': {
        if (event.message?.role !== 'user') return;
        const text = contentText(event.message.content);
        for (const [sentinel, waiter] of this.acks) {
          if (text.includes(sentinel)) {
            this.acks.delete(sentinel);
            waiter.settle('delivered');
          }
        }
        // Kept whole: the attach view wraps this as prose, and firstLine's
        // default clipped the task down to 160 characters before it got there.
        this.record('user', cap(stripSentinel(text), 4_000));
        return;
      }
      case 'message_end': {
        const msg = event.message;
        if (msg?.role !== 'assistant') return;
        const cost = msg.usage?.cost?.total;
        if (typeof cost === 'number') this.costUsd += cost;
        let text = '';
        for (const part of msg.content ?? []) {
          if (
            part?.type === 'text' &&
            typeof part.text === 'string' &&
            part.text.trim()
          )
            text = part.text;
        }
        if (text) {
          this.lastText = text;
          this.record('assistant', cap(text, 4_000));
        }
        // The finished message is now a record; keep the stream from showing twice.
        this.partialText = '';
        return;
      }
      case 'tool_execution_start': {
        const tool = String(event.toolName ?? '');
        this.currentTool = tool;
        this.record('tool', `${tool} ${argDigest(tool, event.args)}`);
        if (tool === 'message_parent') {
          const msg = String(event.args?.message ?? '');
          const expects = event.args?.expects_reply === true;
          emitNews(
            this,
            'spoke',
            `${expects ? '(expects reply) ' : ''}${cap(msg, SNIPPET_CAP)}`,
          );
        }
        if (tool === 'write' || tool === 'edit')
          noteFileTouch(this, String(event.args?.path ?? ''));
        return;
      }
      case 'tool_execution_end': {
        this.currentTool = undefined;
        const text = contentText(event.result?.content);
        this.record(
          'result',
          `${event.toolName}${event.isError ? ' ERROR' : ''}: ${firstLine(text, 2_000)}`,
        );
        return;
      }
      case 'extension_error':
        this.record(
          'error',
          `${event.extensionPath ?? '?'}: ${firstLine(String(event.error ?? ''))}`,
        );
        return;
      case 'compaction_start':
        this.record('compaction', `compaction (${event.reason ?? '?'})`);
        return;
      default:
        return;
    }
  }

  private reply(obj: unknown) {
    try {
      this.proc?.stdin?.write(`${JSON.stringify(obj)}\n`);
    } catch {}
  }

  record(kind: string, text: string) {
    const rec: LogRecord = { t: Date.now() - this.startedAt, kind, text };
    this.records.push(rec);
    if (this.records.length > EVENT_RING) this.records.shift();
    this.logStream?.write(`${JSON.stringify(rec)}\n`);
    refreshUi();
    notifyAttach();
  }

  getRecords(): LogRecord[] {
    return this.records;
  }

  get stderrTail(): string {
    return this.stderrRing;
  }

  // -- delivery ack (B1 + B2) ----------------------------------------------

  registerAck(sentinel: string): {
    promise: Promise<AckOutcome>;
    arm: () => void;
    cancel: () => void;
  } {
    let settle!: (o: AckOutcome) => void;
    const promise = new Promise<AckOutcome>((resolve) => {
      let done = false;
      settle = (o) => {
        if (done) return;
        done = true;
        this.acks.delete(sentinel);
        resolve(o);
      };
    });
    const waiter: AckWaiter = { settle, armed: false };
    this.acks.set(sentinel, waiter);
    return {
      promise,
      arm: () => {
        waiter.armed = true;
      },
      cancel: () => settle('aborted'),
    };
  }
}

function contentText(content: unknown): string {
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  return content
    .filter((p: any) => p?.type === 'text' && typeof p.text === 'string')
    .map((p: any) => p.text)
    .join('\n');
}

function stripSentinel(text: string): string {
  return text.replace(/\[\[sa:[0-9a-f-]+\]\]\s*/i, '');
}

function argDigest(tool: string, args: any): string {
  if (!args || typeof args !== 'object') return '';
  if (tool === 'bash') return firstLine(String(args.command ?? ''), 1_000);
  if (typeof args.path === 'string') return args.path;
  if (typeof args.pattern === 'string') return args.pattern;
  const keys = Object.keys(args).slice(0, 3);
  return keys
    .map((k) => `${k}=${firstLine(scalarish(args[k]), 400)}`)
    .join(' ');
}

// String(x) on anything structured is "[object Object]", which is how a nested
// subagent_spawn — the single most informative call in a tree — rendered in the
// attach view. JSON is not prettier but it is the only form that says anything.
function scalarish(value: unknown): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'object') {
    try {
      return JSON.stringify(value);
    } catch {
      return '[unserializable]';
    }
  }
  return String(value);
}

// ---------------------------------------------------------------------------
// parent-side: fleet, mailbox, ui
// ---------------------------------------------------------------------------

const fleet = new Map<string, Subagent>();
const mailbox: News[] = [];
let flushTimer: NodeJS.Timeout | undefined;
let uiTimer: NodeJS.Timeout | undefined;
let uiActive = false;
let uiCtx: ExtensionContext | undefined;
let parentBusy = false;

// `ctx.ui` is a getter that THROWS once the ctx goes stale (session replacement,
// reload, or shutdown) — optional chaining does not help, because uiCtx itself is
// still non-null. Timers outlive the ctx that scheduled them, so an unguarded
// access here takes down the whole pi process from a callback nothing awaits.
// Open attach views re-render from here: a child's records only change when its
// stdout produces an event, so there is nothing to poll.
const attachListeners = new Set<() => void>();
const spokeWaiters = new Set<(name: string) => void>();
const attachTicks = new Set<() => void>();
const viewTicks = new WeakMap<object, () => void>();
let spinnerTimer: NodeJS.Timeout | undefined;
function notifyAttach() {
  for (const fn of attachListeners) {
    try {
      fn();
    } catch {}
  }
}

function safeUi(): ExtensionContext['ui'] | undefined {
  try {
    return uiCtx?.ui;
  } catch {
    uiCtx = undefined;
    return undefined;
  }
}

// Same hazard as safeUi: every ExtensionContext getter asserts liveness, `cwd`
// included, and this one is reached from child stdout events that keep arriving
// after the parent's session is torn down.
function safeCwd(): string {
  try {
    return uiCtx?.cwd ?? process.cwd();
  } catch {
    uiCtx = undefined;
    return process.cwd();
  }
}
let shuttingDown = false;
let lastSpawnAt = 0;
let registryDir = '';
let sessionDir = '';
let api: ExtensionAPI | undefined;
let cachedAppendSystemPrompt = '';

function liveChildren(): Subagent[] {
  return [...fleet.values()].filter((c) => c.alive);
}

function emitNews(child: Subagent, kind: NewsKind, text: string) {
  if (shuttingDown) return;
  // Always wake the parent on terminal news. This was briefly a per-spawn knob
  // and the model reliably chose the non-waking value, so a finished subagent
  // sat silent until the human happened to type — the exact failure the async
  // design exists to avoid. The editor-busy guard in flushNews is what keeps
  // waking polite.
  const wake = kind === 'finished' || kind === 'died';
  mailbox.push({ kind, name: child.name, at: Date.now(), text, wake });
  // A subagent that asks a question goes quiet waiting for the answer. If the
  // parent is sitting in subagent_wait, both stall until the timeout, so a
  // subagent speaking has to break the wait just as settling does.
  if (kind === 'spoke') for (const w of [...spokeWaiters]) w(child.name);
  scheduleFlush();
}

function noteFileTouch(child: Subagent, filePath: string) {
  if (!filePath) return;
  const abs = path.isAbsolute(filePath)
    ? filePath
    : path.resolve(safeCwd(), filePath);
  child.filesTouched.add(abs);
  // withFileMutationQueue is per-process and pi's edit is read-modify-write with
  // no mtime check, so two children editing one file silently lose a write with
  // both reporting success. Detection has to be immediate — at completion the
  // parent can no longer redirect the other child.
  for (const other of fleet.values()) {
    if (other === child || !other.alive) continue;
    if (other.filesTouched.has(abs)) {
      emitNews(
        child,
        'conflict',
        `${child.name} and ${other.name} both mutated ${abs}`,
      );
      return;
    }
  }
}

function renderNews(items: News[]): string {
  const lines = items.map((n) => `${n.kind.padEnd(8)} ${n.name}: ${n.text}`);
  return cap(lines.join('\n\n'), NEWS_CAP);
}

function scheduleFlush(delayMs = 400) {
  if (flushTimer) return;
  flushTimer = setTimeout(flushNews, delayMs);
}

function flushNews() {
  flushTimer = undefined;
  if (!api || mailbox.length === 0) return;

  const wake = mailbox.some((n) => n.wake);
  // Waking the parent while the human is mid-sentence would steal their turn.
  const editorBusy = (safeUi()?.getEditorText?.() ?? '').trim().length > 0;
  if (wake && editorBusy) {
    scheduleFlush(5_000);
    return;
  }
  // sendMessage routes on isStreaming BEFORE it looks at triggerTurn: handed to
  // a streaming parent this becomes agent.steer(), which is only drained if that
  // run makes another LLM call. A parent that settles first — the common case,
  // since it typically just announced the spawn and stopped — leaves the news
  // queued until the human types, which reads as the subagent having silently
  // done nothing. Wake-worthy news therefore waits for the parent to settle,
  // where triggerTurn starts a run outright.
  if (wake && parentBusy) {
    scheduleFlush(1_000);
    return;
  }

  const items = mailbox.splice(0, mailbox.length);
  const message = {
    customType: 'subagent-news',
    content: renderNews(items),
    display: true,
    details: { items },
  };

  // One coalesced delivery, never N. pi's default steeringMode is one-at-a-time,
  // so four separate steers would land across four parent turns and thrash it.
  if (wake) api.sendMessage(message, { triggerTurn: true });
  else if (parentBusy) api.sendMessage(message, { deliverAs: 'steer' });
  else api.sendMessage(message, { deliverAs: 'nextTurn' });
}

function drainMailbox(names?: Set<string>): News[] {
  if (!names) return mailbox.splice(0, mailbox.length);
  const taken: News[] = [];
  for (let i = mailbox.length - 1; i >= 0; i--) {
    if (names.has(mailbox[i].name)) taken.unshift(...mailbox.splice(i, 1));
  }
  return taken;
}

function childLine(c: Subagent): string {
  const idle = fmtAge(Date.now() - c.lastActivityAt);
  const where =
    c.state === 'exited'
      ? `exited(${c.exitSignal ?? c.exitCode})`
      : c.currentTool
        ? `tool:${c.currentTool}`
        : firstLine(c.lastText, 48) || c.state;
  const ctxPct =
    c.contextPercent === undefined ? '' : ` ctx${c.contextPercent}%`;
  // Only split out the subtree total when there is one, so a flat fleet reads
  // exactly as it did before.
  const cost =
    c.descendantCostUsd > 0
      ? `${fmtCost(c.subtreeCostUsd)}(+sub)`
      : fmtCost(c.costUsd);
  return `${c.name} [${c.state}] t${c.turns} ${cost}${ctxPct} idle:${idle} ${where}`;
}

function refreshUi() {
  // Nobody renders a subagent's status line, and in rpc mode every setStatus and
  // setWidget is a real line on the stdout its own parent is parsing — twice a
  // second, for as long as it has children of its own.
  if (!IS_ROOT || uiTimer) return;
  uiTimer = setTimeout(() => {
    uiTimer = undefined;
    const ui = safeUi();
    if (!ui) return;
    const live = liveChildren();
    if (live.length === 0) {
      if (!uiActive) return;
      uiActive = false;
      ui.setStatus('subagent', undefined);
      ui.setWidget('subagent', undefined);
      return;
    }
    uiActive = true;
    const cost = [...fleet.values()].reduce(
      (sum, c) => sum + c.subtreeCostUsd,
      0,
    );
    ui.setStatus('subagent', `subagents: ${live.length} live ${fmtCost(cost)}`);
    const rows = live.slice(0, 5).map(childLine);
    if (live.length > 5) rows.push(`… ${live.length - 5} more`);
    ui.setWidget('subagent', ['── subagents ──', ...rows]);
  }, 500);
}

// ---------------------------------------------------------------------------
// parent-side: on-disk registry (survives extension rebinding and parent death)
// ---------------------------------------------------------------------------

// A process only ever sees its own children's usage events, never its
// grandchildren's, so subtree cost has to cross the process boundary somehow.
// The registry directory is already keyed by pid and already swept, so each
// process publishes one number into it — what its whole fleet has spent — and
// reads the same file for each of its children. One small read per live child
// every couple of seconds, and it composes to any depth without a protocol.
let publishedFleetCost = -1;

function fleetCostPath(pid: number): string {
  return path.join(getAgentDir(), 'subagents', String(pid), 'fleet-cost');
}

function syncSubtreeCosts() {
  if (fleet.size === 0) return;
  for (const child of liveChildren()) {
    const pid = child.proc?.pid;
    if (!pid) continue;
    let published = 0;
    try {
      published = Number(fs.readFileSync(fleetCostPath(pid), 'utf-8')) || 0;
    } catch {
      continue;
    }
    child.descendantCostUsd = published;
  }
  const total = [...fleet.values()].reduce((s, c) => s + c.subtreeCostUsd, 0);
  if (total === publishedFleetCost) return;
  publishedFleetCost = total;
  try {
    fs.mkdirSync(registryDir, { recursive: true });
    fs.writeFileSync(path.join(registryDir, 'fleet-cost'), String(total));
  } catch {}
  refreshUi();
}

function writeRegistry() {
  try {
    // Do not litter an empty directory for every pi process that never spawned.
    if (fleet.size === 0 && !fs.existsSync(registryDir)) return;
    fs.mkdirSync(registryDir, { recursive: true });
    const entries = [...fleet.values()]
      .filter((c) => c.alive && c.proc?.pid)
      .map((c) => ({
        name: c.name,
        pid: c.proc!.pid,
        startedAt: c.startedAt,
        logPath: c.logPath,
      }));
    fs.writeFileSync(
      path.join(registryDir, 'registry.json'),
      JSON.stringify(entries),
    );
  } catch {}
}

// `/clear`, `/reload`, `/new`, `/resume` and `/fork` all rebind extensions while
// children keep running, and emergencyTerminalExit/uncaughtCrash skip
// session_shutdown entirely. Anything the in-process Map lost is reaped here.
function sweepStaleRegistries() {
  const root = path.join(getAgentDir(), 'subagents');
  let entries: fs.Dirent[];
  try {
    entries = fs.readdirSync(root, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const pid = Number(entry.name);
    if (!Number.isInteger(pid) || pid === process.pid) continue;
    if (isAlive(pid)) continue;
    const dir = path.join(root, entry.name);
    try {
      const listed = JSON.parse(
        fs.readFileSync(path.join(dir, 'registry.json'), 'utf-8'),
      ) as Array<{ pid: number }>;
      for (const item of listed) {
        if (isAlive(item.pid) && looksLikeOrphanedChild(item.pid)) {
          try {
            process.kill(item.pid, 'SIGTERM');
          } catch {}
        }
      }
    } catch {}
    fs.rm(dir, { recursive: true, force: true }, () => {});
  }
}

// ---------------------------------------------------------------------------
// parent-side: spawning
// ---------------------------------------------------------------------------

function buildSystemPrompt(spec: SpawnSpec): string {
  const parts = [
    'You are a subagent invoked by a caller agent, running in your own pi process with your own context window.',
    "You cannot see the caller's conversation. Your task statement is the whole brief.",
    'Report substantive findings in your final assistant message; the caller reads that, not your intermediate output.',
    'Use message_parent to raise a blocking question or a finding the caller needs before you finish.',
    // The child computes this itself from its own env, but it has to be stated:
    // the dispatch tools are simply absent at the last level, and a model that
    // planned around having them wastes a turn discovering they are not there.
    DEPTH + 1 < MAX_DEPTH
      ? 'You can dispatch subagents of your own with subagent_spawn; they cannot dispatch further.'
      : 'You cannot dispatch subagents of your own.',
  ];
  // --append-system-prompt suppresses discovery of ~/.pi/agent/APPEND_SYSTEM.md
  // and project .pi/APPEND_SYSTEM.md, so the parent's already-resolved append
  // text has to be carried across explicitly or the child silently loses it.
  const out = [parts.join(' ')];
  if (cachedAppendSystemPrompt.trim())
    out.push(cachedAppendSystemPrompt.trim());
  if (spec.system_prompt?.trim()) out.push(spec.system_prompt.trim());
  return out.join('\n\n');
}

async function spawnChild(
  spec: SpawnSpec,
  name: string,
  ctx: ExtensionContext,
): Promise<Subagent> {
  const child = new Subagent(
    spec,
    name,
    path.join(registryDir, `${name}.jsonl`),
  );
  fleet.set(name, child);

  const tmpDir = await fs.promises.mkdtemp(
    path.join(os.tmpdir(), 'pi-subagent-'),
  );
  const promptPath = path.join(tmpDir, 'append-system-prompt.md');
  await fs.promises.writeFile(promptPath, buildSystemPrompt(spec), {
    encoding: 'utf-8',
    mode: 0o600,
  });

  const model =
    spec.model ??
    (ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined);
  const args = [
    '--mode',
    'rpc',
    // Child sessions share the parent's cwd and would otherwise pollute the
    // human's /resume picker.
    '--session-dir',
    sessionDir ||
      path.join(getAgentDir(), 'subagent-sessions', `pid-${process.pid}`),
    '--name',
    `subagent-${name}`,
    '--append-system-prompt',
    promptPath,
  ];
  if (model) args.push('--model', model);
  if (ctx.thinkingLevel) args.push('--thinking', ctx.thinkingLevel);
  // A non-interactive child resolving trust for the first time answers "no" and
  // silently loses project .pi/settings.json, extensions, skills and SYSTEM.md.
  args.push(ctx.isProjectTrusted() ? '--approve' : '--no-approve');

  const invocation = getPiInvocation(args);
  child.start(
    invocation.command,
    invocation.args,
    ctx.cwd,
    {
      ...process.env,
      [DEPTH_ENV]: String(DEPTH + 1),
      [NAME_ENV]: name,
    },
    tmpDir,
  );

  writeRegistry();
  child.proc?.on('exit', () => {
    writeRegistry();
    refreshUi();
    if (!child.stopping) {
      emitNews(
        child,
        'died',
        `exited code=${child.exitCode} signal=${child.exitSignal}\n${cap(child.stderrTail, 800)}`,
      );
      if (IS_ROOT) safeUi()?.notify(`subagent ${name} crashed`, 'error');
    }
    if (IS_ROOT && liveChildren().length === 0)
      safeUi()?.notify('all subagents finished', 'info');
  });

  void primeChild(child, spec.task);
  return child;
}

// Runs detached from the spawn tool so the tool returns immediately.
async function primeChild(child: Subagent, task: string) {
  const deadline = Date.now() + STARTUP_TIMEOUT_MS;
  while (Date.now() < deadline && child.alive) {
    try {
      const state = await child.send('get_state', {}, 5_000);
      child.sessionFile = state?.sessionFile;
      break;
    } catch {
      if (!child.alive) return;
      await new Promise((r) => setTimeout(r, 500));
    }
  }
  if (!child.alive) return;
  // Without this, queued messages dribble in one per turn.
  await child.send('set_steering_mode', { mode: 'all' }).catch(() => {});
  await child
    .send('prompt', { message: task, streamingBehavior: 'steer' })
    .catch((err) => {
      child.record(
        'error',
        `failed to deliver task: ${(err as Error).message}`,
      );
    });
}

// ---------------------------------------------------------------------------
// parent-side: bounded waits
// ---------------------------------------------------------------------------

function withDeadline<T>(
  promise: Promise<T>,
  ms: number,
  onTimeout: () => T,
  signal?: AbortSignal,
  onAbort?: () => T,
): Promise<T> {
  return new Promise<T>((resolve) => {
    let done = false;
    const finish = (v: T) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      signal?.removeEventListener('abort', abortHandler);
      resolve(v);
    };
    const timer = setTimeout(() => finish(onTimeout()), ms);
    const abortHandler = () => finish((onAbort ?? onTimeout)());
    if (signal?.aborted) {
      finish((onAbort ?? onTimeout)());
      return;
    }
    signal?.addEventListener('abort', abortHandler, { once: true });
    promise.then(finish, () => finish(onTimeout()));
  });
}

// ---------------------------------------------------------------------------
// parent-side: log rendering
// ---------------------------------------------------------------------------

function renderLog(
  child: Subagent,
  view: string,
  filter: string | undefined,
  limit: number,
): string {
  const footer = [
    '',
    `Full event log (JSONL, one record per line): ${child.logPath}`,
    child.sessionFile ? `Child session: ${child.sessionFile}` : '',
  ]
    .filter(Boolean)
    .join('\n');

  if (view === 'final') {
    return `${child.name} last assistant message:\n\n${cap(child.lastText || '(none)', TOOL_TEXT_CAP)}\n${footer}`;
  }

  let records = child.getRecords();
  if (filter) {
    const needle = filter.toLowerCase();
    records = records.filter(
      (r) => r.text.toLowerCase().includes(needle) || r.kind.includes(needle),
    );
  }
  const shown = records.slice(-limit);
  const lines = shown.map(
    (r) =>
      `[+${fmtAge(r.t)}] ${r.kind.padEnd(10)} ${view === 'transcript' ? r.text : firstLine(r.text, 140)}`,
  );
  const head = `${child.name} (${view}) — ${shown.length} of ${records.length} matching records, ${child.turns} turns, ${fmtCost(child.subtreeCostUsd)}`;
  return `${head}\n\n${cap(lines.join('\n'), TOOL_TEXT_CAP)}\n${footer}`;
}

function harvest(child: Subagent): string {
  const files = [...child.filesTouched];
  return [
    `${child.name}: ${child.state === 'exited' ? `exited(${child.exitSignal ?? child.exitCode})` : child.state}`,
    `turns: ${child.turns}  cost: ${fmtCost(child.subtreeCostUsd)}  ran: ${fmtAge(Date.now() - child.startedAt)}`,
    `files modified: ${files.length ? files.join(', ') : '(none detected)'}`,
    '',
    'Last message:',
    cap(child.lastText || '(none)', SNIPPET_CAP),
    '',
    `Log retained at ${child.logPath}`,
  ].join('\n');
}

function textResult(text: string, details: Record<string, unknown> = {}) {
  return {
    content: [{ type: 'text' as const, text: cap(text, TOOL_TEXT_CAP) }],
    details,
  };
}

// ---------------------------------------------------------------------------
// parent-side: tools
// ---------------------------------------------------------------------------

function registerParentTools(pi: ExtensionAPI) {
  pi.registerTool({
    name: 'subagent_spawn',
    label: 'Spawn Subagents',
    description: [
      'Start one or more subagents, each a copy of you in its own process with its own context window.',
      'A subagent sees none of this conversation, so each task must be self-contained.',
    ].join(' '),
    promptSnippet: 'Start background subagents on self-contained tasks',
    promptGuidelines: [
      'Use subagent_spawn to fan out work whose intermediate output would bloat this context; subagents report back on their own.',
    ],
    parameters: Type.Object({
      agents: Type.Array(
        Type.Object({
          task: Type.String({
            description:
              'Self-contained brief; the subagent sees none of this conversation',
          }),
          name: Type.Optional(
            Type.String({
              description:
                'Handle for this subagent; derived from the task if omitted',
            }),
          ),
          system_prompt: Type.Optional(
            Type.String({
              description: 'Extra system-prompt text for this subagent',
            }),
          ),
          model: Type.Optional(
            Type.String({
              description:
                "provider/id override; defaults to this session's model",
            }),
          ),
        }),
        { description: 'One entry per subagent; all start in parallel' },
      ),
    }),

    async execute(_id, params, _signal, _onUpdate, ctx) {
      uiCtx = ctx;
      const specs = params.agents ?? [];
      if (specs.length === 0) return textResult('Provide at least one agent.');

      const liveCount = liveChildren().length;
      if (liveCount + specs.length > MAX_LIVE_CHILDREN) {
        return textResult(
          `Refusing to spawn: ${liveCount} subagent(s) already alive and the cap is ${MAX_LIVE_CHILDREN}. ` +
            `Stop finished ones with subagent_stop.`,
        );
      }

      const taken = new Set(fleet.keys());
      const started: string[] = [];
      for (const spec of specs) {
        if (!spec.task?.trim()) continue;
        const name = deriveName(spec.task, taken, spec.name);
        taken.add(name);
        // auth.json's lock busy-spins synchronously (10 retries x 20ms), so
        // simultaneous starts stall each other.
        const wait = Math.max(0, lastSpawnAt + SPAWN_STAGGER_MS - Date.now());
        if (wait > 0) await new Promise((r) => setTimeout(r, wait));
        lastSpawnAt = Date.now();
        await spawnChild(spec as SpawnSpec, name, ctx);
        started.push(name);
      }
      refreshUi();

      return textResult(
        [
          `Started ${started.length} subagent(s): ${started.join(', ')}.`,
          'They report back on their own.',
        ].join('\n'),
        { started },
      );
    },
  });

  pi.registerTool({
    name: 'subagent_send',
    label: 'Message Subagent',
    description: [
      'Send a message to a subagent. Returns once the subagent has taken it into context,',
      "not when it answers; the answer arrives later as news.",
    ].join(' '),
    promptSnippet: 'Send a message or reply to a running subagent',
    promptGuidelines: [],
    parameters: Type.Object({
      name: Type.String({ description: 'Subagent handle' }),
      message: Type.String({
        description: "Message text; cannot start with '/'",
      }),
    }),

    async execute(_id, params, signal, _onUpdate, ctx) {
      uiCtx = ctx;
      const child = fleet.get(params.name);
      if (!child)
        return textResult(
          `No subagent named "${params.name}". Live: ${
            liveChildren()
              .map((c) => c.name)
              .join(', ') || 'none'
          }.`,
        );
      if (!child.alive) {
        return textResult(
          `Subagent "${child.name}" has already exited (code=${child.exitCode} signal=${child.exitSignal}); nothing was sent.\n\n${harvest(child)}`,
        );
      }
      // Extension commands cannot be queued, and skill/template expansion would
      // rewrite the text before it is queued.
      if (params.message.trimStart().startsWith('/')) {
        return textResult(
          "Messages starting with '/' are extension commands and cannot be delivered to a subagent.",
        );
      }

      // Presence-matching queue_update.steering[] is not a sound receipt: it is a
      // string[] matched by indexOf, so duplicate text, template expansion, and a
      // same-text prompt all corrupt it, and abort strands entries forever.
      // A unique sentinel observed on the child's user message_start is the same
      // instant with none of that bookkeeping, and it works identically on the
      // idle prompt path where nothing is ever queued.
      const sentinel = `[[sa:${randomUUID()}]]`;
      const payload = `${sentinel}\n${params.message}`;
      // Registered BEFORE the write: queue_update is emitted before the command
      // response, so a waiter registered afterwards has already missed it.
      const ack = child.registerAck(sentinel);

      // B1: the queue only ever drains from inside runLoop, so a steer sent to an
      // idle child sits forever with no further queue_update and no way out.
      // Liveness decides the command, not convenience.
      let route: 'prompt' | 'steer' = 'prompt';
      try {
        const state = await child.send(
          'get_state',
          {},
          COMMAND_TIMEOUT_MS,
          signal,
        );
        route = state?.isStreaming === true ? 'steer' : 'prompt';
        if (route === 'steer') {
          await child.send(
            'steer',
            { message: payload },
            COMMAND_TIMEOUT_MS,
            signal,
          );
        } else {
          // streamingBehavior closes the race where the child starts a run
          // between get_state and this write: pi then queues it as a steer
          // instead of erroring.
          await child.send(
            'prompt',
            { message: payload, streamingBehavior: 'steer' },
            COMMAND_TIMEOUT_MS,
            signal,
          );
        }
        ack.arm();
      } catch (err) {
        ack.cancel();
        return textResult(
          `Could not send to "${child.name}": ${(err as Error).message}`,
        );
      }

      const outcome = await withDeadline<AckOutcome>(
        ack.promise,
        ACK_TIMEOUT_MS,
        () => 'timeout',
        signal,
        () => 'aborted',
      );
      ack.cancel();

      const suffix = `\n\nThe subagent's reply, if any, arrives later as subagent news. Do not wait for it here.`;
      switch (outcome) {
        case 'delivered':
          return textResult(
            `Delivered to "${child.name}" via the ${route} path; the subagent has it in context now.${suffix}`,
            { outcome, route },
          );
        case 'child_exited':
          return textResult(
            `Subagent "${child.name}" exited before taking the message.\n\n${harvest(child)}`,
            { outcome },
          );
        case 'not_delivered':
          return textResult(
            `Subagent "${child.name}" settled without consuming the message — it is stranded in its queue and will not be read. ` +
              `Send it again now that the subagent is idle.`,
            { outcome },
          );
        case 'aborted':
          return textResult(
            `Wait cancelled. The message was handed to "${child.name}" but delivery is unconfirmed.`,
            { outcome },
          );
        default:
          return textResult(
            `No delivery confirmation from "${child.name}" within ${ACK_TIMEOUT_MS / 1000}s. It is queued; the subagent is likely mid-turn. ` +
              `This is not an error and the subagent is still running.`,
            { outcome },
          );
      }
    },
  });

  pi.registerTool({
    name: 'subagent_wait',
    label: 'Wait For Subagents',
    description: [
      'Block until subagents settle or one messages you, up to a timeout.',
      'A timeout is a normal outcome, not a failure.',
    ].join(' '),
    promptSnippet: 'Wait for running subagents to settle',
    promptGuidelines: [],
    parameters: Type.Object({
      names: Type.Optional(
        Type.Array(Type.String(), {
          description: 'Subagents to wait for; defaults to all live ones',
        }),
      ),
      until: Type.Optional(
        StringEnum(['any', 'all'] as const, {
          description:
            'Return on the first settle (default) or when all settle',
        }),
      ),
      timeout_seconds: Type.Number({
        description: `Required. Capped at ${WAIT_CAP_SECONDS}.`,
      }),
    }),

    async execute(_id, params, signal, _onUpdate, ctx) {
      uiCtx = ctx;
      const targets = params.names?.length
        ? params.names
            .map((n) => fleet.get(n))
            .filter((c): c is Subagent => !!c)
        : liveChildren();
      if (targets.length === 0)
        return textResult('No matching subagents to wait for.');

      const timeoutMs =
        Math.max(1, Math.min(params.timeout_seconds || 60, WAIT_CAP_SECONDS)) *
        1000;
      const until = params.until ?? 'any';
      const settles = targets.map((c) => c.waitForSettle());
      const combined =
        until === 'all'
          ? Promise.all(settles).then(() => undefined)
          : Promise.race(settles);

      const names = new Set(targets.map((c) => c.name));
      let spokeWaiter: ((name: string) => void) | undefined;
      const spoke = new Promise<'spoke'>((resolve) => {
        spokeWaiter = (name: string) => {
          if (names.has(name)) resolve('spoke');
        };
        spokeWaiters.add(spokeWaiter);
      });

      let result: 'settled' | 'spoke' | 'timeout' | 'aborted';
      try {
        result = await withDeadline<
          'settled' | 'spoke' | 'timeout' | 'aborted'
        >(
          Promise.race([combined.then(() => 'settled' as const), spoke]),
          timeoutMs,
          () => 'timeout',
          signal,
          () => 'aborted',
        );
      } finally {
        if (spokeWaiter) spokeWaiters.delete(spokeWaiter);
      }

      // Drain so the same news is not also delivered as a steer.
      const news = drainMailbox(new Set(targets.map((c) => c.name)));
      const header =
        result === 'settled'
          ? `Wait satisfied (${until}).`
          : result === 'spoke'
            ? 'A subagent sent you a message. Answer it with subagent_send if it is waiting on you.'
            : result === 'aborted'
            ? 'Wait cancelled. The subagents are still running — nothing was stopped.'
            : `Timed out after ${timeoutMs / 1000}s. This is NOT an error: the subagents below are still running normally. Do not stop them for this reason.`;

      return textResult(
        [
          header,
          '',
          targets.map(childLine).join('\n'),
          news.length ? `\n${renderNews(news)}` : '',
        ].join('\n'),
        { result },
      );
    },
  });

  pi.registerTool({
    name: 'subagent_log',
    label: 'Subagent Log',
    description: [
      "Read what a subagent has been doing. 'outline' is one line per event,",
      "'transcript' the same untruncated, 'final' just its last message.",
    ].join(' '),
    promptSnippet:
      "Read a subagent's activity outline, transcript, or final message",
    parameters: Type.Object({
      name: Type.String({ description: 'Subagent handle' }),
      view: Type.Optional(
        StringEnum(['outline', 'transcript', 'final'] as const),
      ),
      filter: Type.Optional(
        Type.String({
          description: 'Case-insensitive substring filter over log lines',
        }),
      ),
      limit: Type.Optional(
        Type.Number({ description: 'Max lines, default 60, cap 200' }),
      ),
    }),

    async execute(_id, params, _signal, _onUpdate, ctx) {
      uiCtx = ctx;
      const child = fleet.get(params.name);
      if (!child)
        return textResult(
          `No subagent named "${params.name}". Known: ${[...fleet.keys()].join(', ') || 'none'}.`,
        );
      const limit = Math.max(1, Math.min(params.limit ?? 60, 200));
      return textResult(
        renderLog(child, params.view ?? 'outline', params.filter, limit),
      );
    },
  });

  pi.registerTool({
    name: 'subagent_status',
    label: 'Subagent Status',
    description:
      'One line per subagent: state, turns, cost, context usage, idle time, and what it is doing right now.',
    promptSnippet: 'Show the state of every subagent in this session',
    parameters: Type.Object({}),

    async execute(_id, _params, signal, _onUpdate, ctx) {
      uiCtx = ctx;
      if (fleet.size === 0) return textResult('No subagents in this session.');
      await Promise.all(
        liveChildren().map(async (c) => {
          const stats = await withDeadline<any>(
            c.send('get_session_stats', {}, 5_000, signal),
            5_000,
            () => undefined,
            signal,
            () => undefined,
          );
          const pct = stats?.contextUsage?.percent;
          if (typeof pct === 'number') c.contextPercent = Math.round(pct);
        }),
      );
      const lines = [...fleet.values()].map(childLine);
      return textResult(
        lines.join('\n'),
      );
    },
  });

  pi.registerTool({
    name: 'subagent_stop',
    label: 'Stop Subagent',
    description:
      "Stop a subagent (or 'all') and report what it accomplished. The log is retained and remains readable.",
    promptSnippet: 'Stop a subagent and harvest what it accomplished',
    parameters: Type.Object({
      name: Type.String({ description: "Subagent handle, or 'all'" }),
    }),

    async execute(_id, params, _signal, _onUpdate, ctx) {
      uiCtx = ctx;
      const targets =
        params.name === 'all'
          ? liveChildren()
          : [fleet.get(params.name)].filter((c): c is Subagent => !!c);
      if (targets.length === 0)
        return textResult(`No matching subagent for "${params.name}".`);
      const reports: string[] = [];
      for (const child of targets) {
        await withDeadline<void>(
          child.stop(),
          KILL_GRACE_MS + 2_000,
          () => undefined,
        );
        reports.push(harvest(child));
      }
      drainMailbox(new Set(targets.map((c) => c.name)));
      writeRegistry();
      refreshUi();
      return textResult(reports.join('\n\n---\n\n'));
    },
  });
}

// ---------------------------------------------------------------------------
// entry point
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// parent-side: live attach view
// ---------------------------------------------------------------------------

const ATTACH_BODY_ROWS = 24;
const SPINNER = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

// A subagent's work is otherwise invisible: the parent only ever surfaces its
// final report, and the widget one line. This renders the child's event stream
// as it arrives, so a human can watch what it is actually doing.
type ViewLine = { text: string; tone: string };

// Colours are applied after wrapping and truncation, never before: padEnd counts
// escape bytes, so a coloured line padded by raw length breaks the right border.
const wrapPlain = (
  text: string,
  width: number,
  indent = '',
  maxLines = 0,
): string[] => {
  const out: string[] = [];
  for (const para of text.split('\n')) {
    if (!para.trim()) {
      out.push('');
      continue;
    }
    let line = indent;
    for (const word of para.trim().split(/\s+/)) {
      if (line.trim() && line.length + 1 + word.length > width) {
        out.push(line);
        line = indent + word;
      } else {
        line = line.trim() ? `${line} ${word}` : indent + word;
      }
    }
    if (line.trim()) out.push(line);
  }
  if (maxLines > 0 && out.length > maxLines) {
    const kept = out.slice(0, maxLines);
    kept.push(`… ${out.length - maxLines} more lines`);
    return kept;
  }
  return out;
};

class AttachView {
  private offset = 0;
  private follow = true;
  tick = 0;

  constructor(
    private readonly child: Subagent,
    private readonly theme: { fg: (c: string, t: string) => string },
    private readonly requestRender: () => void,
    private readonly close: () => void,
  ) {}

  private tint(tone: string, text: string): string {
    if (!tone) return text;
    try {
      return this.theme.fg(tone, text);
    } catch {
      return text;
    }
  }

  // Rendered as a transcript rather than an event dump: the point of attaching
  // is to read what the subagent is doing, which is prose and tool calls.
  private lines(inner: number): ViewLine[] {
    const out: ViewLine[] = [];
    const push = (text: string, tone = '') => out.push({ text, tone });

    for (const r of this.child.getRecords()) {
      switch (r.kind) {
        case 'run':
        case 'settled':
          break;
        case 'user':
          push('');
          for (const l of wrapPlain(r.text, inner - 2, ''))
            push(`▌ ${l}`, 'accent');
          break;
        case 'assistant':
          push('');
          for (const l of wrapPlain(r.text, inner)) push(l, '');
          break;
        case 'tool':
          for (const l of wrapPlain(r.text, inner - 4, '', 6))
            push(`  ⏵ ${l}`, 'accent');
          break;
        case 'result':
          for (const l of wrapPlain(r.text, inner - 6, '', 8))
            push(`      ${l}`, 'muted');
          break;
        case 'compaction':
          push(`  ~ ${r.text}`, 'warning');
          break;
        case 'error':
          push(`  ! ${firstLine(r.text, inner - 4)}`, 'error');
          break;
        default:
          push(`  · ${firstLine(r.text, inner - 4)}`, 'muted');
      }
    }

    if (this.child.partialText) {
      push('');
      for (const l of wrapPlain(this.child.partialText, inner)) push(l, '');
    }
    if (this.child.state === 'working') {
      push('');
      push(`${SPINNER[this.tick % SPINNER.length]} Working…`, 'muted');
    }
    return out;
  }

  render(width: number): string[] {
    const inner = Math.max(20, width - 4);
    const c = this.child;
    const all = this.lines(inner);
    const maxOffset = Math.max(0, all.length - ATTACH_BODY_ROWS);
    if (this.follow) this.offset = maxOffset;
    this.offset = Math.min(Math.max(0, this.offset), maxOffset);
    // Scrolling back down to the bottom resumes following, as in a pager.
    if (this.offset >= maxOffset) this.follow = true;
    const body = all.slice(this.offset, this.offset + ATTACH_BODY_ROWS);

    // Every row is padded to the full width. An overlay composites over the
    // transcript beneath it, so a short line leaves the old text showing through.
    const row = (line: ViewLine) => {
      const plain =
        line.text.length > inner ? line.text.slice(0, inner) : line.text;
      const pad = ' '.repeat(inner - plain.length);
      return `│ ${this.tint(line.tone, plain)}${pad} │`;
    };
    const rule = (label: string) => {
      const t = ` ${label} `;
      const trimmed = t.length > inner ? `${t.slice(0, inner - 1)} ` : t;
      return `─${trimmed}${'─'.repeat(Math.max(0, inner + 2 - trimmed.length - 1))}`;
    };

    const title = `${c.name} · ${c.state} · turn ${c.turns} · ${fmtCost(c.subtreeCostUsd)}${c.model ? ` · ${c.model}` : ''}`;
    const pos =
      all.length > ATTACH_BODY_ROWS
        ? ` · ${this.offset + body.length}/${all.length}${this.follow ? ' following' : ''}`
        : '';
    const help = `j/k scroll · g/G top/bottom · f follow · q detach${pos}`;

    const rows = body.length ? body : [{ text: '  (nothing yet)', tone: 'muted' }];
    return [
      `┌${rule(title)}┐`,
      ...rows.map(row),
      ...Array.from({ length: Math.max(0, ATTACH_BODY_ROWS - rows.length) }, () =>
        row({ text: '', tone: '' }),
      ),
      `└${rule(help)}┘`,
    ];
  }

  private scroll(delta: number) {
    if (delta < 0) this.follow = false;
    this.offset += delta;
  }

  // Auto-repeat delivers several sequences coalesced into one chunk, so this
  // must consume a batch rather than match the whole string against one key.
  handleInput(data: string) {
    let i = 0;
    let closing = false;
    while (i < data.length && !closing) {
      const rest = data.slice(i);
      // Escape sequences before the bare ESC that closes the view.
      if (rest.startsWith('\x1b[A')) {
        this.scroll(-1);
        i += 3;
      } else if (rest.startsWith('\x1b[B')) {
        this.scroll(1);
        i += 3;
      } else if (rest.startsWith('\x1b[5~')) {
        this.scroll(-ATTACH_BODY_ROWS);
        i += 4;
      } else if (rest.startsWith('\x1b[6~')) {
        this.scroll(ATTACH_BODY_ROWS);
        i += 4;
      } else {
        const ch = data[i];
        if (ch === 'k') this.scroll(-1);
        else if (ch === 'j') this.scroll(1);
        else if (ch === 'g') {
          this.follow = false;
          this.offset = 0;
        } else if (ch === 'G') this.follow = true;
        else if (ch === 'f') this.follow = !this.follow;
        else if (ch === 'q' || ch === '\x1b' || ch === '\x03') closing = true;
        i += 1;
      }
    }
    // Detaching never stops the child; it keeps working in the background.
    if (closing) {
      this.close();
      return;
    }
    this.requestRender();
  }

  invalidate() {}
}

async function openAttachView(ctx: ExtensionContext, child: Subagent) {
  let listener: (() => void) | undefined;
  let openView: object | undefined;
  try {
    await ctx.ui.custom<null>(
      (tui, theme, _keybindings, done) => {
        listener = () => tui.requestRender();
        attachListeners.add(listener);
        const view = new AttachView(
          child,
          theme,
          () => tui.requestRender(),
          () => done(null),
        );
        // The spinner has to animate on its own clock; child events are far too
        // sparse to drive it, and a still frame is what makes a thinking
        // subagent look dead. Only runs while a view is open.
        spinnerTimer ??= setInterval(() => {
          for (const t of attachTicks) t();
          notifyAttach();
        }, 120);
        const tickFn = () => {
          view.tick++;
        };
        attachTicks.add(tickFn);
        viewTicks.set(view, tickFn);
        openView = view;
        return view;
      },
      {
        overlay: true,
        // Default placement floats this narrow and to the right, over the
        // transcript. A subagent's tool calls need the width to stay legible.
        overlayOptions: { anchor: 'center', width: '92%', margin: 1 },
        onHandle: (handle: { focus: () => void }) => handle.focus(),
      },
    );
  } finally {
    if (listener) attachListeners.delete(listener);
    if (openView) {
      const t = viewTicks.get(openView);
      if (t) attachTicks.delete(t);
    }
    if (attachTicks.size === 0 && spinnerTimer) {
      clearInterval(spinnerTimer);
      spinnerTimer = undefined;
    }
  }
}

export default function subagentExtension(pi: ExtensionAPI) {
  // Not two mutually exclusive modes: everything below the root gets the channel
  // back to its own caller, and everything above the last level gets the
  // dispatch tools. A middle agent is both at once.
  if (!IS_ROOT) registerChildTools(pi);
  if (!CAN_SPAWN) return;

  api = pi;
  registryDir = path.join(getAgentDir(), 'subagents', String(process.pid));

  pi.registerMessageRenderer('subagent-news', (message, options, theme) => {
    const header = theme.fg('accent', '[subagents] ');
    return new Text(
      header + String(message.content ?? ''),
      options.outputPad,
      0,
    );
  });

  pi.on('session_start', async (_event, ctx) => {
    uiCtx = ctx;
    shuttingDown = false;
    sessionDir = path.join(
      getAgentDir(),
      'subagent-sessions',
      kebab(
        path.basename(
          ctx.sessionManager.getSessionFile() ?? `pid-${process.pid}`,
          '.jsonl',
        ),
      ) || `pid-${process.pid}`,
    );
    sweepStaleRegistries();
    refreshUi();
  });

  pi.on('before_agent_start', async (event, ctx) => {
    uiCtx = ctx;
    parentBusy = true;
    // getSystemPromptOptions() lives on ExtensionCommandContext, not on the plain
    // ExtensionContext a tool execute() receives, so cache it from here.
    const appended = (event as any).systemPromptOptions?.appendSystemPrompt;
    if (typeof appended === 'string') cachedAppendSystemPrompt = appended;

    const live = liveChildren();
    if (live.length === 0) return;
    // Survives compaction, unlike an injected message: this is what stops the
    // parent forgetting it has children.
    const roster = live
      .map(
        (c) =>
          `${c.name}(${c.state === 'working' ? `working t${c.turns}` : c.state})`,
      )
      .join(' ');
    return {
      systemPrompt: `${event.systemPrompt}\n\nSubagents alive: ${roster}`,
    };
  });

  pi.on('agent_settled', async (_event, ctx) => {
    uiCtx = ctx;
    parentBusy = false;
    if (mailbox.length > 0) scheduleFlush(200);
  });

  // Fires repeatedly and on every session replacement, so it must be idempotent.
  pi.on('session_shutdown', async () => {
    shuttingDown = true;
    if (flushTimer) clearTimeout(flushTimer);
    flushTimer = undefined;
    const live = liveChildren();
    for (const child of live) child.stopping = true;
    await Promise.all(
      live.map((c) =>
        withDeadline<void>(c.stop(), KILL_GRACE_MS + 2_000, () => undefined),
      ),
    );
    writeRegistry();
    if (uiActive) {
      uiActive = false;
      safeUi()?.setStatus('subagent', undefined);
      safeUi()?.setWidget('subagent', undefined);
    }
  });

  setInterval(syncSubtreeCosts, 2_000).unref?.();

  setInterval(() => {
    const now = Date.now();
    for (const child of liveChildren()) {
      if (
        child.state === 'working' &&
        !child.stalledReported &&
        now - child.lastActivityAt > STALL_MS
      ) {
        child.stalledReported = true;
        emitNews(
          child,
          'stalled',
          `no activity for ${fmtAge(now - child.lastActivityAt)}; last: ${firstLine(child.lastText, 200)}`,
        );
      }
    }
  }, 30_000).unref?.();

  // ctx.ui.custom() resolves to undefined in rpc mode, so the attach view only
  // means anything where there is a human at a terminal.
  if (IS_ROOT)
    pi.registerCommand('subagent', {
      description: 'Watch a running subagent live (no args lists the fleet)',
      handler: async (args, ctx) => {
        const wanted = (args ?? '').trim();
        const all = [...fleet.values()];
        if (all.length === 0) {
          ctx.ui.notify('No subagents in this session.', 'info');
          return;
        }
        const child = wanted
          ? (fleet.get(wanted) ?? all.find((c) => c.name.startsWith(wanted)))
          : (all.find((c) => c.state === 'working') ?? all[all.length - 1]);
        if (!child) {
          ctx.ui.notify(
            `No subagent "${wanted}". Known: ${all.map((c) => c.name).join(', ')}`,
            'error',
          );
          return;
        }
        uiCtx = ctx;
        await openAttachView(ctx, child);
      },
    });

  registerParentTools(pi);
}
