---
name: codex-review
description: Use only when the user explicitly requests a Codex review or invokes this skill.
disable-model-invocation: true
metadata:
  harness: "claude-code, grok, opencode, cursor, shared"
---

# Codex review

Use the user's selected model, or `gpt-5.6-sol` when none is specified. Review
locally; do not post findings, edit the reviewed files, or delegate again.

## Prepare

Identify the repository and exact review target from the request. Record the
current commit and `git status --short`. Use a unique directory under
`.plans/scratch/` for the prompt, report, and log, and exclude it from the review.
Do not include unrelated user changes unless they are part of the requested target.

For a standard diff review, choose exactly one target: `--uncommitted`,
`--base <branch>`, or `--commit <sha>`. Set `REVIEW_REPO`, `REVIEW_MODEL`, and
`REVIEW_DIR` to the absolute repository path, selected model, and artifact directory:

```bash
timeout 300 codex -C "$REVIEW_REPO" -s read-only -a never \
  exec -m "$REVIEW_MODEL" -c "review_model=\"$REVIEW_MODEL\"" \
  -o "$REVIEW_DIR/report.md" review --uncommitted \
  </dev/null >"$REVIEW_DIR/run.log" 2>&1
```

Replace `--uncommitted` with the selected target flag. Do not combine target
flags with a custom prompt. For a plan, selected files, or a review needing
specific requirements, write a self-contained `prompt.md` and use:

```bash
timeout 300 codex -C "$REVIEW_REPO" -s read-only -a never \
  exec -m "$REVIEW_MODEL" -o "$REVIEW_DIR/report.md" - \
  <"$REVIEW_DIR/prompt.md" >"$REVIEW_DIR/run.log" 2>&1
```

The prompt must name the exact target and requirements, ask for review without
edits or further delegation, and prioritize concrete bugs, regressions, and
requirements mismatches. Ask for severity, file and line, failure scenario, and
suggested fix direction for each finding. For plans, assess feasibility and
missing decisions. Request an explicit statement if no substantive issues are found.

## Assess the result

Run in the background with progress checks if the command may take several
minutes. On failure or timeout, report the error and whether output is partial;
do not silently switch models or broaden permissions.

Read the report and verify substantive findings against the source before
presenting them. Distinguish confirmed issues from unresolved concerns, name
the reviewed target and model, and state verification gaps. A clean review is
not evidence that tests passed. Check the final Git state; do not revert user work.
