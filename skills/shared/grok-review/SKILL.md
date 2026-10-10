---
name: grok-review
description: Use only when the user explicitly requests a Grok review or invokes this skill.
disable-model-invocation: true
metadata:
  harness: "claude-code, codex, opencode, cursor"
---

# Grok review

Run Grok Build's built-in `/review` locally with an installed, authenticated
`grok` CLI. Use the user's selected model, or `grok-4.7` when none is specified,
and the user's selected effort, or `high` when none is specified. Do not post
findings or edit the reviewed files.

## Prepare

Identify the repository and exact review target from the request. Record the
current commit and `git status --short`. Create a unique directory under
`.plans/scratch/` for `prompt.md`, the report, and the log; exclude it from review.

Write `prompt.md` as one `/review` line for the targets it covers:

- Uncommitted changes: `/review --local`.
- The current branch with a clean tree: `/review --main`. It compares against
  `origin/main` or `origin/master`.
- Another branch: `/review --branch <name>`.

Never pass `--pr`, `--stack`, `--submit`, or `--approve`; they post to GitHub.
`/review --local` reviews every uncommitted change. If the tree holds user
changes outside the requested target, say so when presenting the findings.

For a commit, a plan, or selected files, write a self-contained prompt instead,
with the exact target and the command or paths that show it. Ask for concrete
bugs, regressions, and requirements mismatches with severity, file and line,
failure scenario, and fix direction; for plans, feasibility and missing
decisions. Request an explicit statement if no substantive issues are found,
and instruct it to review without edits or tests.

## Run and monitor

Start the command below using the calling tool's background or resumable
execution mode, and retain its task or session ID so you can check its status
and exit code. Do not set a review runtime limit or a tool timeout that kills
the process. A short wait that returns control while leaving it running is fine.

Set `REVIEW_REPO`, `REVIEW_MODEL`, `REVIEW_EFFORT`, and `REVIEW_DIR` to the
absolute repository path, selected model, selected effort, and artifact
directory:

```bash
grok --cwd "$REVIEW_REPO" --model "$REVIEW_MODEL" --effort "$REVIEW_EFFORT" \
  --sandbox read-only --always-approve --disable-web-search \
  --output-format plain -p "$(cat "$REVIEW_DIR/prompt.md")" \
  </dev/null >"$REVIEW_DIR/report.md" 2>"$REVIEW_DIR/run.log"
```

`/review` gives its reviewer a shell and a write tool, so `--always-approve`
is safe only inside the `read-only` sandbox: the kernel blocks writes outside
`~/.grok` and temp directories, and blocks network access for its commands.
`/review` writes its full findings to a file under the temp directory and names
that file in the report. This is a static review: the caller remains
responsible for tests.

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
Do not silently switch models or effort, or drop the sandbox to make the
invocation work.

## Assess the result

Read the report and the findings file it names, and verify substantive findings
against the source before presenting them. Distinguish confirmed issues from
unresolved concerns, name the reviewed target, model, and effort, and state
verification gaps. A clean review is not evidence that tests passed. Check the
final Git state; do not revert user work.
