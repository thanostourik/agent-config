---
name: t3-fan-out
description: Use when the user wants several T3 threads started and coordinated, one per task.
---

# T3 fan-out

You are the coordinator. Each task gets its own T3 thread and worktree. You
start them, wait for them, hand out verification, and report once at the end.

## Models

A thread runs on the model and effort the user names for it, for example
"CHA-889 on Codex gpt-6-astra xhigh, the rest default". A thread the user does
not name runs on `claudeAgent` / `claude-opus-5-5` with effort `high`.

Before starting anything, call `orchestrator_capabilities` and check every
combination you will use: the provider instance, the model id, and the effort
value in that model's effort option (its id differs by provider: `effort`,
`reasoningEffort`, `reasoning_effort`, ...). If one does not exist, ask the
user. Never use another model or effort instead.

## Parallel verification

Services share ports across repos, so by default only one thread verifies at a
time. Read the target project's instructions (`AGENTS.md`, `CLAUDE.md`, and
the docs they point to). If they allow parallel verification, in any wording,
every thread verifies as soon as its PR is open.

## Start

Start one thread per task with `t3_thread_launch`:

- `title`: the issue key and a few words.
- `workspaceStrategy`: `{type: "worktree", baseRef: "main", branch,
  startFromOrigin: true}`, with the project's main branch as `baseRef`.
- `branch`: `<prefix>/ISSUE-123-short-name`, prefix `feature/`, `fix/`, or
  `chore/`. Omit the issue id when there is none.
- `modelSelection`: `{instanceId, model, options}` from the check above.
- `message`: the first prompt.

The child cannot see this conversation, so the first prompt stands alone. It
holds the task, the issue key, the branch name, and everything the user said
about this task. It ends with:

- Implement the change, commit, push, and open the PR.
- Without parallel verification: do not verify yet. End with the PR link and
  wait; the coordinator will tell you when to verify.
- With parallel verification: then verify the way the project does, and end
  with a one-line verdict, the PR link, and what is unverified.

Keep every returned `threadId`. If a launch fails or its response is lost,
check `t3_thread_list` before you launch again.

## Wait

Wait with `t3_thread_wait`, one thread after another, with a long
`timeoutMs`. On `timedOut`, call it again. A wait can return before the thread
has answered while its worktree is still being prepared; then wait again.
Read the result with `t3_thread_read`. Do not message the user while you wait.

If a thread ends with a question, answer it from the user's request with
`t3_thread_send`. Ask the user only when the request does not answer it.

## Verify one at a time

Without parallel verification, once a thread has opened its PR, send it
"verify now" with `t3_thread_send`: verify the way the project does, update the
PR description, and end with a one-line verdict, the PR link, and what is
unverified. Wait for it to finish before you send the next thread "verify now".

## Report

When every thread has finished, send one report with one line per thread: its
verdict, its PR link, and what is unverified.
