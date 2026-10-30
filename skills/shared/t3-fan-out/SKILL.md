---
name: t3-fan-out
description: Use when the user wants several T3 threads or delegates started and coordinated, one per task.
---

# T3 fan-out

You are the coordinator. Each task gets its own T3 thread and worktree. You
start them, wait for them, hand out verification, and report once at the end.

A fan-out request is not a request to study the task. Do not analyse the
issue, propose fixes, or write code: that is each thread's work.

Make no decisions about the tasks yourself. When coordinating needs one that
the user or the issues haven't made, ask.

## Models

A thread uses the provider, model, and effort the user names for it, for example
"CHA-889 on Codex gpt-6-astra xhigh, the rest default". For each unspecified
field, use provider `{{defaults.provider}}`, model `{{defaults.model}}`, and
effort `{{defaults.effort}}`.

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
  startFromOrigin: true}`, with the project's main branch as `baseRef`. The
  branch goes inside `workspaceStrategy`; a top-level `branch` is ignored. Name
  it `<prefix>/ISSUE-123-short-name`, prefix `feature/`, `fix/`, or `chore/`.
  Omit the issue id when there is none.
- `modelSelection`: `{instanceId, model, options}` from the check above.
- `message`: the first prompt.

The child cannot see this conversation, so the first prompt stands alone. It
passes the task on as the user gave it, not your version of it:

- the issue key and link, or the user's own description, quoted as written
- the branch name
- decisions the user stated about this task, marked as theirs

Do not restate the issue or repeat rules the child's own instructions already
give, such as how to commit, open the PR, or verify. The prompt ends with:

- Implement the change, commit, push, and open the PR.
- Without parallel verification: do not verify yet. End your turn with the PR
  link; the coordinator will tell you when the shared ports are free.
- With parallel verification: then verify the way the project does.
- When you verify, end with a one-line verdict and the PR link.

Keep every returned `threadId`. If a launch fails or its response is lost,
check `t3_thread_list` before you launch again.

## Wait

Wait with `t3_thread_wait`, one thread after another, with a long
`timeoutMs`. Read the result with `t3_thread_read`. Do not message the user
while you wait.

A thread can ask a question in two ways. Answer from the user's request, and
ask the user only when the request does not answer it:

- With a question tool: the run stays open, so the wait times out. On
  `timedOut`, check `t3_pending_request_list` and answer with
  `t3_pending_request_respond`. With no pending question, wait again.
- As text that ends its turn: answer with `t3_thread_send`.

After either answer, wait for that thread again.

## Verify one at a time

Without parallel verification, once a thread has opened its PR, send it
exactly this with `t3_thread_send`, and nothing else:

```
Verify now: the shared ports are free. If one is taken, report it as a blocker.
```

Wait for it to finish before you send the next thread "verify now".

## Delegates

Only when the user asks for delegates. The steps above stay, with these changes:

- Start: one `delegate_task` per task with `task` (the first prompt), `title`,
  `isolation: "worktree"`, `target: {providerInstanceId, model, options}`,
  `mode: "async"`, and its own `clientRequestId`; retry with the same one. The
  worktree starts on a `t3/...` branch from your current local commit, so the
  prompt first says: `git fetch origin`, then
  `git switch -c <branch> origin/<main branch>`. Keep each `taskId` and
  `childThreadId`.
- Wait: `t3_thread_wait` on the `childThreadId`, as for threads, then read the
  result with `task_status` and the `taskId`. Do not poll `task_status`.
- Questions: on `timedOut`, `task_status` shows `hasPendingQuestion`. Pass the
  `childThreadId` as `threadId` to `t3_pending_request_list` and
  `t3_pending_request_respond`. Answer a question that ends the turn with
  `t3_thread_send` to the `childThreadId`.
- Verify now: `t3_thread_send` to the `childThreadId`, with its own
  `clientRequestId`. It returns a new `taskId`; wait for it the same way. Never
  send "verify now" as a new `delegate_task`: that child has neither the
  conversation nor the worktree.

## Report

When every thread has finished, send one report with one line per thread: its
verdict, its PR link, and anything its thread reported as unverified.
