# codex-workers

A Claude Code skill and a small bridge script that let any Claude Code
session start Codex workers, send them tasks and get their answers back.
Installed for every project by `nixpkgs/home-manager/modules/codex-workers.nix`:

- `~/.claude/skills/codex-workers` links to this directory, so edits here take
  effect without a rebuild.
- `codex-bridge` on PATH runs `bridge.py` with a Nix-pinned Python. Standard
  library only, Python 3.10+.

| Command | What it does |
|---------|--------------|
| `codex-bridge spawn --name <name> --task "<task>"` | Start a worker on the shared Codex daemon, bridge it to the calling Claude session and queue the task |
| `codex-bridge list` | List live Claude and Codex sessions in the current directory |
| `codex-bridge stop --thread <thread> --archive` | Stop a worker's bridge and archive its thread |
| `codex-bridge serve --thread <thread> --relay-to uds:<claude socket>` | Bridge a daemon-hosted Codex session you started yourself |
| `codex-bridge send --to uds:<claude socket> --message -` | Send a message to a Claude session from the shell |

## How it works

1. `spawn` creates a thread with a one-word `codex exec` turn, so the thread
   exists and nothing holds it.
2. It starts `serve` in the background. `serve` listens on
   `/tmp/cc-socks/codex-<thread>.sock`, an address Claude can reach with
   SendMessage, and passes each incoming message to the worker with
   `codex queue --resume`. That command also loads the thread on the daemon.
3. `spawn` queues the task. The brief tells Codex to follow the project's
   `AGENTS.md`, keep to its files and not commit.
4. `serve` tails the thread's rollout file and sends the final message of
   every finished turn to Claude's socket, which `spawn` read from
   `CLAUDE_CODE_MESSAGING_SOCKET`.

The bridge forwards replies itself because Codex can't. Codex's `read-only`
and `workspace-write` sandboxes block connecting to Claude's socket, and also
block the shell's here-document temp files, so a sandboxed worker could never
send a reply. The bridge runs outside the sandbox, so forwarding works in
every sandbox mode.

## Bridging a Codex session you started yourself

```console
codex --remote unix://                       # or: codex --remote unix:// resume <thread>
codex-bridge serve --thread <thread> --relay-to uds:/tmp/cc-socks/<claude-pid>.sock
```

`codex-bridge list` shows each Claude session's socket. A plain Codex TUI
(without `--remote unix://`) owns its thread and can't take bridged messages.

## Notes

- Messages from Claude reach Codex labelled as untrusted peer input. Nothing
  here changes Claude or Codex permission settings.
- Claude's peer socket protocol is private and may change. Tested with Claude
  Code 2.1.316 and Codex CLI 0.166.0.
