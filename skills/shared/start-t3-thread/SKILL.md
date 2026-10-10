---
name: start-t3-thread
description: Use only when the user asks to start, spawn, queue, or fan out T3 Code threads.
---

# Start T3 thread

Run `~/.local/bin/t3-start-thread` once per thread. It creates the thread in the
running T3 Code app and sends the first prompt, so the agent starts working
at once, in full-access mode. The thread appears in the T3 app.

When you need me to make a choice before you can continue, use your question
tool if you have one, or ask in your reply if you don't. If the question gets no
answer, ask again in your reply and wait. Do not answer it yourself.

```bash
t3-start-thread --project <name or path> [--prompt <text> | prompt on stdin] [--title <text>] \
  [--provider <instance id> --model <model>] [--worktree-from <base> [--branch <name>]]
```

Turn the user's plain-language request into these options:

- `--project`: the T3 project's name or folder path. If it matches several, the
  script lists them; pick the one the user means or ask.
- `--worktree-from main --branch fix/KEY-123-short-name`: the thread works in a new
  git worktree on a new branch cut from the latest `origin/main`. Use it whenever
  the user wants separate or isolated threads. Name the branch as the user's git
  rules say (`fix/KEY-123-short-name`). Without `--worktree-from` the thread works
  in the project folder.
- `--provider` and `--model`: only when the user names them. `--provider` is the T3
  provider instance id (`claudeAgent`, `cursor`, `grok`, `opencode`); `--model` alone keeps
  the project's default provider. Without both, the project's default model is used.
- `--title`: only when the user gives one. Otherwise T3 titles the thread itself.

The first prompt must stand alone, because the thread has none of this
conversation. Include the task and every detail the thread needs (for a Jira ticket:
its key, summary, description, and link). Pass long prompts on stdin.

For many threads (one per ticket, for example), start them one after another and
give each its own branch. The script refuses a branch that already has a thread,
so a re-run does not duplicate work.

If the script exits with an error, report its message and stop. Do not retry or
work around it. When done, tell the user how many threads started, with their
projects and branches.
