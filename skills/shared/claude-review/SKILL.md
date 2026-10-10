---
name: claude-review
description: Use only when the user explicitly requests a Claude review or invokes this skill.
disable-model-invocation: true
metadata:
  harness: "codex, grok, opencode, cursor"
---

# Claude review

Run Claude Code's built-in `/code-review` locally. Use the user's selected
model, or `claude-sonnet-5-5` when none is specified, and the user's selected
effort, or `high` when none is specified. Do not post findings or edit the
reviewed files.

## Prepare

Identify the repository and exact review target from the request. Record the
current commit and `git status --short`. Create a unique directory under
`.plans/scratch/` for the report and log; exclude it from review.

Set `REVIEW_TARGET` to the `/code-review` target:

- Uncommitted changes, or the current branch when the tree is clean: empty.
- Another branch: its name.
- A commit: its SHA.
- A plan or selected files: their paths.

`/code-review` reviews every uncommitted change. If the tree holds user changes
outside the requested target, say so when presenting the findings.

## Run and monitor

Start the command below using the calling tool's background or resumable
execution mode, and retain its task or session ID so you can check its status
and exit code. Do not set a review runtime limit or a tool timeout that kills
the process. A short wait that returns control while leaving it running is fine.

Set `REVIEW_REPO`, `REVIEW_MODEL`, `REVIEW_EFFORT`, and `REVIEW_DIR` to the
absolute repository path, selected model, selected effort, and artifact
directory:

```bash
cd "$REVIEW_REPO"
claude -p --model "$REVIEW_MODEL" --effort "$REVIEW_EFFORT" \
  --allowedTools "Read,Glob,Grep,Bash(git diff*),Bash(git log*),Bash(git show*),Bash(git status*)" \
  --permission-mode dontAsk --strict-mcp-config --no-session-persistence \
  --output-format text "/code-review $REVIEW_EFFORT $REVIEW_TARGET" \
  </dev/null >"$REVIEW_DIR/report.md" 2>"$REVIEW_DIR/run.log"
```

The allowed tools let the reviewer read files and run read-only git commands;
`dontAsk` rejects everything else. Never add `--fix`, which edits files,
`--comment` or `--post`, which publish findings, or `ultra`, which starts a
billed cloud review. This is a static review: the caller remains responsible
for tests.

Check the running task and any new report or log output every 30–60 seconds.
Give the user a brief progress update at least once a minute, even when there
is no new output. Keep monitoring until it exits or the user cancels; do not
end your turn with the review pending or wait for the user to ask you to check.

If the review appears stuck, inspect its process state and logs. A running
process alone does not prove progress; silence or elapsed time alone does not
prove a hang and must not trigger cancellation. Report what you can establish
and keep monitoring when the evidence is inconclusive.

When the task exits, check its exit code and report. Report failures promptly
and identify any partial output; never present an incomplete review as clean.
Do not silently switch models or effort, or loosen the allowed tools to make
the invocation work.

## Assess the result

Read the report and verify substantive findings against the source before
presenting them. Distinguish confirmed issues from unresolved concerns, name
the reviewed target, model, and effort, and state verification gaps. A clean
review is not evidence that tests passed. Check the final Git state; do not
revert user work.
