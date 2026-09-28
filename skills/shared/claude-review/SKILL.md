---
name: claude-review
description: Use only when the user explicitly requests a Claude review or invokes this skill.
disable-model-invocation: true
metadata:
  harness: "codex, grok, opencode, cursor"
---

# Claude review

Use the user's selected model, or `claude-fable-5-1` when none is specified. Use the
user's selected effort (`low`, `medium`, `high`, or `max`), or `low` when none is
specified. Start a fresh review session, without resuming the author's
conversation. Review locally; do not post findings or edit the reviewed files.

## Prepare

Identify the repository and exact review target from the request. Record the
current commit and `git status --short`. Create a unique directory under
`.plans/scratch/` for `prompt.md`, the report, and the log; exclude it from review.

The caller prepares the diff because the reviewer has no shell tool:

- Uncommitted changes: `git diff HEAD -- <paths>` covers tracked staged and
  unstaged changes. List relevant untracked files separately for Claude to read.
- Branch changes: `git diff <base>...HEAD -- <paths>`.
- A commit: `git show --format=fuller <sha> -- <paths>`.
- A plan or selected files: supply their paths and the requested review scope.

Write a self-contained prompt with the repository path, exact target, diff or
diff-file path, relevant project instructions, and requirements. Ask Claude to
read surrounding code and report concrete bugs, regressions, and requirements
mismatches with severity, file and line, failure scenario, and fix direction.
For plans, assess feasibility and missing decisions. Request an explicit
statement if no substantive issues are found. Instruct it to review directly,
without edits, commands, or further delegation.

## Run and monitor

Start the command below using the calling tool's background or resumable
execution mode, and retain its task or session ID so you can check its status
and exit code. Do not set a review runtime limit or a tool timeout that kills
the process. A short wait that returns control while leaving it running is fine.

Set `REVIEW_REPO`, `REVIEW_MODEL`, `REVIEW_EFFORT`, and `REVIEW_DIR` to the
absolute repository path, selected model, selected effort, and artifact
directory. Run from the repository:

```bash
cd "$REVIEW_REPO"
claude -p --model "$REVIEW_MODEL" --effort "$REVIEW_EFFORT" \
  --tools "Read,Glob,Grep" --allowedTools "Read,Glob,Grep" \
  --permission-mode dontAsk --disable-slash-commands --strict-mcp-config \
  --no-session-persistence --output-format text \
  <"$REVIEW_DIR/prompt.md" >"$REVIEW_DIR/report.md" 2>"$REVIEW_DIR/run.log"
```

The restricted tool list permits source inspection but excludes shell execution,
editing, and subagents; strict MCP configuration excludes configured external
tools. This is a static review: the caller remains responsible for tests.

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
Do not silently switch models or effort, or bypass permissions to make the
invocation work.

## Assess the result

Verify substantive findings against the source before presenting them.
Distinguish confirmed issues from unresolved concerns, name the reviewed target,
model, and effort, and state verification gaps. A clean review is not evidence
that tests passed. Check the final Git state; do not revert user work.
