---
name: grok-review
description: Use only when the user explicitly requests a Grok review or invokes this skill.
disable-model-invocation: true
metadata:
  harness: "claude-code, codex, opencode, cursor"
---

# Grok review

Use the user's selected model, or `grok-4.7` when none is specified. Use the
user's selected effort (`low`, `medium`, `high`, or `xhigh`), or `high` when none
is specified. Start a fresh review session, without resuming the author's
conversation. Review locally; do not post findings or edit the reviewed files.

## Prepare

Identify the repository and exact review target from the request. Record the
current commit and `git status --short`. Create a unique directory under
`.plans/scratch/` for `prompt.md`, the report, and the log; exclude it from review.
Do not include unrelated user changes unless they are part of the requested target.

The caller prepares the diff because the reviewer has no shell tool:

- Uncommitted changes: `git diff HEAD -- <paths>` covers tracked staged and
  unstaged changes. List relevant untracked files separately for Grok to read.
- Branch changes: `git diff <base>...HEAD -- <paths>`.
- A commit: `git show --format=fuller <sha> -- <paths>`.
- A plan or selected files: supply their paths and the requested review scope.

Write a self-contained prompt with the repository path, exact target, diff or
diff-file path, relevant project instructions, and requirements. Ask Grok to
read surrounding code and report concrete bugs, regressions, and requirements
mismatches with severity, file and line, failure scenario, and fix direction.
For plans, assess feasibility and missing decisions. Request an explicit
statement if no substantive issues are found. Instruct it to review directly,
without edits, commands, or further delegation.

## Run

Use an installed, authenticated Grok Build CLI (`grok`). Set `REVIEW_REPO`,
`REVIEW_MODEL`, `REVIEW_EFFORT`, and `REVIEW_DIR` to the absolute repository
path, selected model, selected effort, and artifact directory:

```bash
timeout 300 grok --cwd "$REVIEW_REPO" --model "$REVIEW_MODEL" \
  --reasoning-effort "$REVIEW_EFFORT" --prompt-file "$REVIEW_DIR/prompt.md" \
  --tools "read_file,grep,list_dir" --allow Read --allow Grep \
  --deny MCPTool --permission-mode dontAsk --no-subagents \
  --disable-web-search --output-format plain \
  </dev/null >"$REVIEW_DIR/report.md" 2>"$REVIEW_DIR/run.log"
```

The tool list permits source inspection but excludes shell execution and
editing. MCP tool calls, web access, and subagents are disabled. This is a
static review: the caller remains responsible for tests.

Run in the background with progress checks if it may take several minutes.
On failure or timeout, report the error and whether output is partial. Do not
silently switch models or effort, or bypass permissions to make the invocation
work.

## Assess the result

Verify substantive findings against the source before presenting them.
Distinguish confirmed issues from unresolved concerns, name the reviewed target,
model, and effort, and state verification gaps. A clean review is not evidence
that tests passed. Check the final Git state; do not revert user work.
