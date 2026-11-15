---
name: t3-fan-out
description: Use when the user asks to "fan out", or wants several T3 threads or delegates started.
---

# T3 fan-out

You are the coordinator. Each task gets its own new T3 thread and worktree, and
that thread studies the task, decides how to do it, and implements it. You start
the threads, wait for them, tell them when to verify, and report at the end.
Leave the analysis, decisions, and code to the threads. When coordinating needs
a decision that the user or the issues haven't made, ask the user.

## Models

A thread uses the provider, model, and effort the user names for it, for example
"ISSUE-123 on Codex gpt-6-astra xhigh, the rest default". For each unspecified
field, use provider `{{defaults.provider}}`, model `{{defaults.model}}`, and
effort `{{defaults.effort}}`.

Before starting anything, call `orchestrator_capabilities` and check every
combination you will use: the provider instance, the model id, and the effort
value in that model's effort option (its id differs by provider: `effort`,
`reasoningEffort`, `reasoning_effort`, ...). If one does not exist, ask the
user which to use instead.

## Start

Start one thread per task with `t3_thread_launch`:

- `title`: the issue key and a few words.
- `workspaceStrategy`: `{type: "worktree", baseRef: "origin/<main branch>",
  branch: "<branch>", startFromOrigin: true}`. This gives the thread its own
  worktree on a new branch, cut from the remote's main branch. You name the
  branch.
- `modelSelection`: `{instanceId, model, options}` from the Models check.
- `message`: the first prompt.

The thread cannot see this conversation, so the first prompt holds:

- the issue key and link, or the user's own description, quoted as written
- decisions the user stated about this task, marked as theirs
- the closing line from "Verify" below

Keep every returned `threadId`. If a launch fails or its response is lost,
check `t3_thread_list` before you launch again.

## Verify

Services share ports across repos, so threads verify one at a time. Read the
target project's instructions (`AGENTS.md`, `CLAUDE.md`, and the docs they
point to). If they allow parallel verification, in any wording, threads verify
in parallel.

**One at a time.** The first prompt ends with:

    Stop when the PR is open and end your turn with its link. I will tell you when to verify.

When a thread has opened its PR, send it exactly this with `t3_thread_send`:

    Verify now: the shared ports are free. If one is taken, report it as a blocker. End with a one-line verdict and the PR link.

Wait for that thread to finish before you send it to the next one.

**In parallel.** The first prompt ends with:

    Verify when the PR is open. End with a one-line verdict and the PR link.

## Wait

Wait for each thread with `t3_thread_wait` and a long `timeoutMs`, one thread
after another. Stay silent toward the user while you wait.

A wait ends in one of two ways:

- The thread ended its turn. Read its last message with `t3_thread_read`. It is
  the thread's result (a PR link or a verdict) or a question to you.
- The wait timed out. The thread is still working, or it asked a question
  through a question tool and is waiting for the answer. Call
  `t3_pending_request` with `action: "list"` and the `threadId`. With no
  pending question, wait again.

Answer a question from what the user said. When the user's request does not
answer it, ask the user. Reply to a question in a message with
`t3_thread_send`, and to a pending question with `t3_pending_request` and
`action: "respond"`. Then wait for that thread again.

## Report

When every thread has finished, send one report with one line per thread: its
verdict and its PR link.

## Detach

When the user asks to detach, the threads run on their own. Every first prompt
ends with:

    When the PR is open, verify if the project's instructions allow parallel verification, or if nothing else is using the project's shared ports and services. If they are in use, skip verification and say so. End with a one-line verdict and the PR link.

After starting the threads, reply with each thread's link and end your turn.

## Delegates

When the user asks for delegates, each task runs as a delegate of this thread.
The sections above apply, with these differences:

- **Start:** one `delegate_task` per task, with `title`, `task` (the first
  prompt), `isolation: "worktree"`, `mode: "async"`,
  `target: {providerInstanceId, model, options}`, and its own
  `clientRequestId`. After an error, retry with the same `clientRequestId`.
  Keep each returned `taskId` and `childThreadId`.
- **Branch:** a delegate's worktree starts on a `t3/...` branch at your current
  local commit. So the first prompt begins with: `git fetch origin`, then
  `git switch -c <branch> origin/<main branch>`, with the branch you named.
- **Wait:** `t3_thread_wait` on the `childThreadId`. When it finishes, read the
  result with `task_status` and the `taskId`.
- **Questions:** use the `childThreadId` as the `threadId` in
  `t3_pending_request` and `t3_thread_send`.
- **Verify now:** send it with `t3_thread_send` to the `childThreadId`, so the
  same delegate verifies in its own worktree. The send returns a new `taskId`;
  wait for it the same way.
