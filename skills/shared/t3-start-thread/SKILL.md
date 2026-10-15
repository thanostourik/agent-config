---
name: t3-start-thread
description: Use only when the user asks to start, spawn, queue, or fan out T3 Code threads, or to message or check on T3 threads.
---

# Start T3 thread

Three scripts in `~/.local/bin/` work with threads in the running T3 Code app:

- `t3-start-thread` creates a thread and sends its first prompt, so the agent
  starts working at once, in full-access mode. The thread appears in the T3 app.
- `t3-message-thread` sends a follow-up message to an existing thread. The
  message starts the thread's next turn.
- `t3-check-thread` reports a thread's state and its latest reply.

When you need me to make a choice before you can continue, use your question
tool if you have one, or ask in your reply if you don't. If the question gets no
answer, ask again in your reply and wait. Do not answer it yourself.

## Start a thread

```bash
t3-start-thread --project <name or path> [--prompt <text> | prompt on stdin] [--title <text>] \
  [--provider <instance id> --model <model>] [--effort <level>] \
  [--worktree-from <base> [--branch <name>]]
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
  provider instance id (`claudeAgent`, `codex`, `cursor`, `grok`, `opencode`);
  `--model` alone keeps the project's default provider. Without both, the
  project's default model is used. Use the model id, for example
  `--provider claudeAgent --model claude-opus-5-5` for "Claude Opus 5.5".
- `--effort`: only when the user names an effort or reasoning level. Pass the
  level in lowercase: `low`, `medium`, `high`, `xhigh` ("extra high"), or `max`.
  The script picks the option name each provider needs. For Claude models it
  checks the level and, if the model does not have it, exits with the levels
  the model does have; pick the one the user means or ask.
- `--title`: only when the user gives one. Otherwise T3 titles the thread itself.

Example: "start a thread in agent-config with Claude Opus 5.5 at high effort":

```bash
t3-start-thread --project agent-config --provider claudeAgent --model claude-opus-5-5 \
  --effort high --prompt "<the full task>"
```

The first prompt must stand alone, because the thread has none of this
conversation. Include the task and every detail the thread needs (for a Jira ticket:
its key, summary, description, and link). Pass long prompts on stdin.

The script prints `started thread <thread id> ...`. Keep that id: the other two
scripts need it.

For many threads (one per ticket, for example), start them one after another and
give each its own branch. The script refuses a branch that already has a thread,
so a re-run does not duplicate work.

## Check a thread

```bash
t3-check-thread --thread <thread id>
```

It prints the thread's title, a `state:` line, and the last assistant message of
its latest turn under `latest reply:`. The state is one of:

- `working`: a turn is running. Check again later.
- `waiting`: the thread asked a question or wants an approval. The user answers
  it in the T3 app; tell the user.
- `failed`: the turn or the session failed. An `error:` line follows.
- `interrupted`: the turn was stopped before it finished.
- `idle`: the last turn finished. The reply is its final message.

## Send a follow-up message

```bash
t3-message-thread --thread <thread id> [--message <text> | message on stdin]
```

The thread keeps its model, effort, and folder. The script refuses while the
thread is `working`; check it first and send when it is in another state. Like
the first prompt, write the message so the thread can act on it without this
conversation, but you do not need to repeat what the thread already knows.

## When a script fails

If a script exits with an error, report its message and stop. Do not retry it,
and do not work around it, for example by calling T3's API or editing its
database yourself. This rule is only about failures: when the scripts work, use
all three as the user's request needs.

When done, tell the user what you did: for started threads, how many, with their
ids, projects, and branches; for checks, each thread's state and reply.
