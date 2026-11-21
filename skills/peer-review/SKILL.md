---
name: peer-review
description: Use when the user asks for a peer review or an independent review by Codex, Claude, Grok, Cursor Grok, or Gemini (Antigravity), or when review-loop runs one.
---

# Peer review

Run an independent, read-only review with one or more external reviewers. Do
not post findings, edit the reviewed files, or let reviewers delegate again.

## Reviewers

Use the reviewer(s) the user named; otherwise default to `{{defaults.reviewer}}`.
Read only the reference file(s) for the reviewer(s) you will run:

- `codex`: [references/codex.md](references/codex.md)
- `claude`: [references/claude.md](references/claude.md)
- `grok`: [references/grok.md](references/grok.md)
- `cursor-grok`: [references/cursor-grok.md](references/cursor-grok.md)
- `gemini` (through Antigravity): [references/gemini.md](references/gemini.md)

Use the user's selected model and effort when given; otherwise use that
reviewer's defaults. If the user asks for multiple reviewers, start them in
parallel and combine their verified findings into one report.

Never silently switch reviewers, models, or effort, or weaken permissions or
sandboxes to make an invocation work.

## Prepare

Identify the repository (`REVIEW_REPO`, absolute path) and exact review target
from the request: uncommitted changes, a branch against its base, a commit, a
plan, or selected files. Record the current commit (`git rev-parse HEAD`) and
`git status --short`. Create a unique directory (`REVIEW_DIR`) under
`.plans/scratch/` for the prompt, report, and log; exclude it from review. Do
not include unrelated user changes unless they are part of the requested target.

## Custom prompts

When a reviewer runs a custom prompt (for a plan, selected files, a non-default
base, or a specific question such as `review-loop`'s evidence check), write a
self-contained `prompt.md` with:

- the absolute repository path and an instruction to run commands from there
- the exact target and the git command or paths that show it
- any explicit requirements from the request
- instructions to review without edits, tests, or further delegation,
  prioritizing concrete bugs, regressions, and requirements mismatches with
  severity, file and line, failure scenario, and suggested fix direction (for
  plans: feasibility and missing decisions), plus an explicit statement when no
  substantive issues are found

## Run and monitor

Follow the chosen reviewer's reference file to run it.

For CLI commands, start the command using the calling tool's background or
resumable execution mode, and retain its task or session ID so you can check
its status and exit code. Do not set a review runtime limit or a tool timeout
that kills the process.

Wait until every reviewer finishes. If the calling tool notifies you when a
background command or delegate completes, end your turn and wait for that
notice; never start a polling loop or a monitor to watch it. Without such a
notice, check status with short waits that return control while leaving it
running.

If a review appears stuck, inspect its process state and logs. A running
process alone does not prove progress, and silence or elapsed time alone does
not prove a hang and must not trigger cancellation. Report what you can
establish and keep waiting when the evidence is inconclusive.

When a reviewer exits, check its exit code (or delegate result) and any
completeness check in its reference file. Report failures promptly and identify
any partial output; never present an incomplete review as clean.

## Assess and report

Read the report (and any findings file it names) and verify substantive
findings against the source before presenting them. When multiple reviewers
ran, deduplicate overlapping findings and note disagreements.

Distinguish confirmed issues from unresolved concerns, name the reviewed
target, reviewer(s), model(s), and effort(s), and state verification gaps. A
clean review is not evidence that tests passed.

Check the final Git state (`git status --short` and `git rev-parse HEAD`).
Report any unexpected change; do not revert user work.
