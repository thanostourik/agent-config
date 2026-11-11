---
name: claude-review
description: Use when the user requests a Claude review, or when another skill such as review-loop runs one.
---

# Claude review

Run Claude Code's built-in `/code-review` locally. Use the user's selected
model and effort; otherwise model `{{defaults.model}}` and effort
`{{defaults.effort}}`. Do not post findings or edit the reviewed files.

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

## Review a branch against a base

`/code-review` takes no base. When the base is the default branch, set
`REVIEW_TARGET` to the branch. For any other base, write a `prompt.md` holding
only the target and `git diff <base>...<branch>`, and run it as a custom
question, described below.

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
REVIEW_SANDBOX=$(jq -nc --arg repo "$REVIEW_REPO" \
  --arg git "$(git rev-parse --path-format=absolute --git-common-dir)" \
  '{sandbox: {enabled: true, failIfUnavailable: true,
    autoAllowBashIfSandboxed: true, allowUnsandboxedCommands: false,
    filesystem: {denyWrite: [$repo, $git]}}}')
claude -p --model "$REVIEW_MODEL" --effort "$REVIEW_EFFORT" \
  --allowedTools "Read,Glob,Grep" --settings "$REVIEW_SANDBOX" \
  --permission-mode dontAsk --strict-mcp-config --no-session-persistence \
  --output-format json "/code-review $REVIEW_EFFORT $REVIEW_TARGET" \
  </dev/null >"$REVIEW_DIR/result.json" 2>"$REVIEW_DIR/run.log"
```

For a custom question, such as whether given proof files show criteria
working, write a self-contained `prompt.md` and replace the last argument,
`"/code-review $REVIEW_EFFORT $REVIEW_TARGET"`, with
`"$(cat "$REVIEW_DIR/prompt.md")"`. Keep every other flag.

The reviewer may run any shell command, but only inside Claude Code's sandbox,
where the repository and its git directory are read-only. A worktree's git
directory sits in the main checkout, so it is named separately.
`failIfUnavailable` makes Claude exit at startup when the sandbox cannot start,
instead of running commands unsandboxed. `dontAsk` rejects every other tool
that could write. Do not go back to an allow-list of shell commands: it denies
ordinary forms such as `git diff $(git merge-base …)` or `cd src && git diff`,
and the reviewer then reviews without the diff. Never add `--fix`, which edits
files, `--comment` or `--post`, which publish findings, or `ultra`, which
starts a billed cloud review. This is a static review: the caller remains
responsible for tests.

Wait until the review finishes, then report.

If the review appears stuck, inspect its process state and logs. A running
process alone does not prove progress; silence or elapsed time alone does not
prove a hang and must not trigger cancellation. Report what you can establish
and keep monitoring when the evidence is inconclusive.

When the task exits, check its exit code and report. Report failures promptly
and identify any partial output; never present an incomplete review as clean.
Do not silently switch models or effort, or loosen the allowed tools or the
sandbox to make the invocation work.

## Assess the result

The report is the `result` field of `result.json`. Its `permission_denials`
field lists every action Claude refused. Any entry there means the review is
incomplete: report it as failed, with the denied actions, and never as clean.

Read the report and verify substantive findings against the source before
presenting them. Distinguish confirmed issues from unresolved concerns, name
the reviewed target, model, and effort, and state verification gaps. A clean
review is not evidence that tests passed. Check the final Git state; do not
revert user work.
