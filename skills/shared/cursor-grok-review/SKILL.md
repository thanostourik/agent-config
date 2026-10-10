---
name: cursor-grok-review
description: Use only when the user explicitly requests a Grok review through Cursor or invokes this skill.
disable-model-invocation: true
metadata:
  harness: "claude-code, codex, grok, opencode"
---

# Cursor Grok review

Run a local review with the Cursor CLI (`cursor-agent`). Use the user's selected
model, or `grok-4.7` when none is specified, and the user's selected effort, or
`high` when none is specified. Cursor names a model and effort together as one
id, `<model>-<effort>`, for example `grok-4.7-high`; check `cursor-agent
--list-models` if the id is not listed. Review locally; do not post findings or
edit the reviewed files.

## Prepare

Identify the repository and exact review target from the request: uncommitted
changes, a branch against its base, a commit, a plan, or selected files. Record
the current commit and `git status --short`. Create a unique directory under
`.plans/scratch/` for the prompt, report, log, and Cursor config; exclude it from
review. Do not include unrelated user changes unless they are part of the
requested target.

Write a self-contained `prompt.md` with the exact target and the git command
that shows it (`git diff HEAD` plus untracked files, `git diff <base>...HEAD`,
or `git show <sha>`), relevant project instructions, and requirements. Ask for
concrete bugs, regressions, and requirements mismatches with severity, file and
line, failure scenario, and fix direction. For plans, ask about feasibility and
missing decisions. Request an explicit statement if no substantive issues are
found, and instruct it to review without edits, tests, or other commands.

Write `$REVIEW_DIR/cursor-config/cli-config.json`:

```json
{
  "version": 1,
  "editor": { "vimMode": false },
  "approvalMode": "allowlist",
  "permissions": {
    "allow": [
      "Read(**)",
      "Shell(git diff)",
      "Shell(git log)",
      "Shell(git show)",
      "Shell(git status)"
    ],
    "deny": ["Write(**)"]
  }
}
```

The user's own Cursor config may approve every tool, and print mode then
ignores `--mode ask`. This separate config is what keeps the reviewer read-only:
file writes and every shell command except read-only git are rejected. Cursor
also writes session files into this directory, so use a new one for every run.

## Run and monitor

Start the command below using the calling tool's background or resumable
execution mode, and retain its task or session ID so you can check its status
and exit code. Do not set a review runtime limit or a tool timeout that kills
the process. A short wait that returns control while leaving it running is fine.

Set `REVIEW_REPO`, `REVIEW_MODEL`, `REVIEW_EFFORT`, and `REVIEW_DIR` to the
absolute repository path, selected model, selected effort, and artifact
directory:

```bash
CURSOR_CONFIG_DIR="$REVIEW_DIR/cursor-config" cursor-agent -p --trust \
  --model "$REVIEW_MODEL-$REVIEW_EFFORT" --workspace "$REVIEW_REPO" \
  --output-format text "$(cat "$REVIEW_DIR/prompt.md")" \
  </dev/null >"$REVIEW_DIR/report.md" 2>"$REVIEW_DIR/run.log"
```

This is a static review: the caller remains responsible for tests.

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
Do not silently switch models or effort, or loosen the Cursor config to make
the invocation work.

## Assess the result

Read the report and verify substantive findings against the source before
presenting them. Distinguish confirmed issues from unresolved concerns, name
the reviewed target, model, and effort, and state verification gaps. A clean
review is not evidence that tests passed. Check the final Git state; do not
revert user work.
