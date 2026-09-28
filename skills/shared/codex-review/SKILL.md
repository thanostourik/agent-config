---
name: codex-review
description: Use only when the user explicitly requests a Codex review or invokes this skill.
disable-model-invocation: true
metadata:
  harness: "claude-code, grok, opencode, cursor"
---

# Codex review

Use the user's selected model, or `gpt-6-astra` when none is specified. Use the
user's selected effort (`low`, `medium`, `high`, or `xhigh`), or `low` when none
is specified. Review locally; do not post findings, edit the reviewed files, or
delegate again.

## Prepare

Identify the repository and exact review target from the request. Record the
current commit and `git status --short`. Use a unique directory under
`.plans/scratch/` for the prompt, report, and log, and exclude it from the review.
Do not include unrelated user changes unless they are part of the requested target.

## Run and monitor

Start the command below using the calling tool's background or resumable
execution mode, and retain its task or session ID so you can check its status
and exit code. Do not set a review runtime limit or a tool timeout that kills
the process. A short wait that returns control while leaving it running is fine.

For a standard diff review, choose exactly one target: `--uncommitted`,
`--base <branch>`, or `--commit <sha>`. Set `REVIEW_REPO`, `REVIEW_MODEL`,
`REVIEW_EFFORT`, and `REVIEW_DIR` to the absolute repository path, selected model,
selected effort, and artifact directory:

```bash
codex -C "$REVIEW_REPO" -s read-only -a never \
  exec -m "$REVIEW_MODEL" -c "review_model=\"$REVIEW_MODEL\"" \
  -c "model_reasoning_effort=\"$REVIEW_EFFORT\"" \
  -o "$REVIEW_DIR/report.md" review --uncommitted \
  </dev/null >"$REVIEW_DIR/run.log" 2>&1
```

Replace `--uncommitted` with the selected target flag. Do not combine target
flags with a custom prompt. For a plan, selected files, or a review needing
specific requirements, write a self-contained `prompt.md` and use:

```bash
codex -C "$REVIEW_REPO" -s read-only -a never \
  exec -m "$REVIEW_MODEL" -c "model_reasoning_effort=\"$REVIEW_EFFORT\"" \
  -o "$REVIEW_DIR/report.md" - \
  <"$REVIEW_DIR/prompt.md" >"$REVIEW_DIR/run.log" 2>&1
```

The prompt must name the exact target and requirements, ask for review without
edits or further delegation, and prioritize concrete bugs, regressions, and
requirements mismatches. Ask for severity, file and line, failure scenario, and
suggested fix direction for each finding. For plans, assess feasibility and
missing decisions. Request an explicit statement if no substantive issues are found.

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
Do not silently switch models or effort, or broaden permissions.

## Assess the result

Read the report and verify substantive findings against the source before
presenting them. Distinguish confirmed issues from unresolved concerns, name
the reviewed target, model, and effort, and state verification gaps. A clean
review is not evidence that tests passed. Check the final Git state; do not
revert user work.
