---
name: grok-review
description: Use when the user requests a Grok review, or when another skill such as review-loop runs one.
---

# Grok review

Run Grok Build's built-in `/review` locally with an installed, authenticated
`grok` CLI. Use the user's selected model and effort; otherwise model
`{{defaults.model}}` and effort `{{defaults.effort}}`. Do not post findings
or edit the reviewed files.

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

## Run as a T3 delegate

In T3 Code, when `prompt.md` is a `/review` line, run it as a delegate instead
of the command below. Call `orchestrator_capabilities` and check that provider
`grok` offers the selected model and effort. Then call `delegate_task` with
`mode: "async"`, `target: {providerInstanceId: "grok", model: <model>,
options: {reasoningEffort: <effort>}}`, and the `/review` line as the whole
task. Set no `role`: `role: "review"` puts a sentence in front of the task, and
Grok then no longer reads it as a slash command.

Once every other task you need is started, end your turn and wait for the
completion notice. The result is the review's closing summary, which names its
findings file under `/tmp/grok-<user>/`. The delegate has no read-only
sandbox, so compare `git status --short` and `git rev-parse HEAD` with the ones
you recorded. Report any change it made, and never treat its files or commits
as part of the reviewed work.
If the delegate is unavailable or fails, run the command below.

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

Wait until the review finishes, then report. If the calling tool notifies you
when a background command exits, end your turn and wait for that notice. Never
start a polling loop or a monitor to watch the review. Without such a notice,
check its status with short waits.

Grok sometimes keeps running after it has finished. It has finished when
`report.md` holds its final answer; for `/review`, that is the summary naming
the findings file. If the process is still running a minute after that answer
appeared, stop it and assess the report: that review is complete, not failed.

In every other case, a running process alone does not prove progress, and
silence or elapsed time alone does not prove a hang and must not trigger
cancellation. If the review appears stuck, inspect its process state and logs.
Report what you can establish and keep monitoring when the evidence is
inconclusive.

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
