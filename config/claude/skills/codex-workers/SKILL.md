---
name: codex-workers
description: Load when the user asks you to hand work to Codex, spin up Codex workers or agents, get a second opinion or review from Codex, or split work across Codex sessions in parallel. Covers starting a worker, messaging it, receiving its reports and shutting it down.
---

# Codex workers

You can start Codex sessions in the current project, give them tasks and talk
to them while they work. Each worker runs on the shared local Codex daemon. A
small bridge process forwards your messages to it and sends its answers back
to you.

Everything goes through the `codex-bridge` command (on PATH, installed by
home-manager). It acts on the directory you run it from.

## Start a worker

```console
codex-bridge spawn --name <name> --task "<task>" [--sandbox read-only] [--model M] [--effort low|medium|high]
```

- `<name>` is a short label such as `fix-auth-tests` or `review-api`. It shows
  in `codex-bridge list` and in every report.
- The task is the worker's whole brief. It cannot see this conversation, so
  include file paths, the goal, constraints and what "done" means. Codex reads
  the project's `AGENTS.md` on its own; don't repeat it.
- For a long brief, pass `--task -` and pipe it on stdin:
  `codex-bridge spawn --name x --task - <<'EOF' ... EOF`.
- The default sandbox is `workspace-write`: it can edit files in the project
  but has no network. Use `--sandbox read-only` for review and research.
  Only use `--sandbox danger-full-access` if the user asks for it.
- `--directory <path>` starts the worker somewhere other than the current
  directory, for example a git worktree.

`spawn` prints the worker's `thread`, its `bridge` address
(`uds:/tmp/cc-socks/codex-<thread>.sock`) and a log path. Keep the bridge
address: it's how you message the worker.

## Get results

Don't poll. When a worker finishes a turn, its final message arrives in this
conversation as a peer message that starts with `From Codex:` and
`Codex worker <name> (thread ...) finished a turn.` Several workers can report
in any order.

A report is what Codex says it did, not proof. Before you tell the user the
work is done, check the diff yourself (`git status`, `git diff`), run the
project's checks on it, and fix anything that fails or send it back to the
worker.

## Send a follow-up

Use SendMessage with the bridge address as `to`:

```text
SendMessage(to: "uds:/tmp/cc-socks/codex-<thread>.sock", message: "...")
```

It's queued as the worker's next turn, and the answer comes back the same way.
Use this for review feedback, corrections or a next step.

## Stop a worker

```console
codex-bridge stop --thread <thread> --archive
```

Stop every worker you started once its work is checked. Without `--archive`
only the bridge stops and the thread stays in Codex's session list.

## Running several at once

- Workers share the checkout they start in. Give each one its own set of
  files and say so in the brief. Two workers editing the same file overwrite
  each other. For overlapping work, give each one a git worktree with
  `--directory`.
- Make shared edits yourself after the workers report: lockfiles, route or
  navigation tables, changelogs, anything every task would touch.
- Workers are told not to commit, push or switch branches unless the task
  says so. You own the branch and the commit.
- `codex-bridge list` shows live Claude and Codex sessions in the current
  directory. `HOST` should be `daemon` for your workers.

## Troubleshooting

- No report after a long while: read the log path printed by `spawn`. Lines
  `queued peer message` and `relayed turn` show traffic in each direction.
  The worker's full transcript is at
  `~/.codex/sessions/**/rollout-*-<thread>.jsonl`.
- `no Claude reply address`: `spawn` reads `CLAUDE_CODE_MESSAGING_SOCKET`,
  which Claude Code sets for its commands. Outside Claude Code, pass
  `--reply-to uds:<socket>`.
- `could not start the shared Codex daemon`: Codex isn't installed, signed in
  or running. Tell the user; this needs them.
- The user can watch or take over a worker in their terminal with
  `codex --remote unix:// resume <thread>`.
