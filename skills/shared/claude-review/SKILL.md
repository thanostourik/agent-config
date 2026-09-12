---
name: claude-review
description: Use only when the user explicitly requests a Claude review or invokes this skill.
---

# Claude review

Use the user's selected model, or `opus` when none is specified. Start a fresh
review session, without resuming the author's conversation. Review locally;
do not post findings or edit the reviewed files.

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

## Run

Set `REVIEW_REPO`, `REVIEW_MODEL`, and `REVIEW_DIR` to the absolute repository
path, selected model, and artifact directory. Run from the repository:

```bash
cd "$REVIEW_REPO"
timeout 300 claude -p --model "$REVIEW_MODEL" \
  --tools "Read,Glob,Grep" --allowedTools "Read,Glob,Grep" \
  --permission-mode dontAsk --disable-slash-commands --strict-mcp-config \
  --no-session-persistence --output-format text \
  <"$REVIEW_DIR/prompt.md" >"$REVIEW_DIR/report.md" 2>"$REVIEW_DIR/run.log"
```

The restricted tool list permits source inspection but excludes shell execution,
editing, and subagents; strict MCP configuration excludes configured external
tools. This is a static review: the caller remains responsible for tests.

Run in the background with progress checks if it may take several minutes.
On failure or timeout, report the error and whether output is partial. Do not
silently switch models or bypass permissions to make the invocation work.

## Assess the result

Verify substantive findings against the source before presenting them.
Distinguish confirmed issues from unresolved concerns, name the reviewed target
and model, and state verification gaps. A clean review is not evidence that tests
passed. Check the final Git state; do not revert user work.
