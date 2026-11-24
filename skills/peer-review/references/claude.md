# Claude reviewer

Runs Claude Code's built-in `/code-review` locally.
Defaults: model `{{defaults.claude_model}}`, effort `{{defaults.claude_effort}}`.

## Target

Set `REVIEW_TARGET` for `/code-review`:

- Uncommitted changes, or the current branch when the tree is clean: empty.
- Another branch: its name.
- A commit: its SHA.
- A plan or selected files: their paths.

`/code-review` reviews every uncommitted change. If the tree holds user changes
outside the requested target, say so when presenting the findings.

`/code-review` takes no base. When the base is the default branch, set
`REVIEW_TARGET` to the branch. For any other base, write `$REVIEW_DIR/prompt.md`
holding only the target and `git diff <base>...<branch>`, and run it as a
custom prompt below.

## Run

Set `REVIEW_REPO`, `REVIEW_MODEL`, `REVIEW_EFFORT`, and `REVIEW_DIR` to the
absolute repository path, selected model, selected effort, and artifact
directory:

```bash
cd "$REVIEW_REPO" &&
REVIEW_GIT_DIR=$(git rev-parse --path-format=absolute --git-common-dir) &&
REVIEW_SANDBOX=$(jq -nc --arg repo "$REVIEW_REPO" --arg git "$REVIEW_GIT_DIR" \
  '{sandbox: {enabled: true, failIfUnavailable: true,
    autoAllowBashIfSandboxed: true, allowUnsandboxedCommands: false,
    filesystem: {denyWrite: [$repo, $git]}}}') &&
claude -p --model "$REVIEW_MODEL" --effort "$REVIEW_EFFORT" \
  --allowedTools "Read,Glob,Grep" --settings "$REVIEW_SANDBOX" \
  --permission-mode dontAsk --strict-mcp-config --no-session-persistence \
  --output-format json "/code-review $REVIEW_EFFORT $REVIEW_TARGET" \
  </dev/null >"$REVIEW_DIR/result.json" 2>"$REVIEW_DIR/run.log"
```

For a custom prompt (such as a non-default base or an evidence check), write `$REVIEW_DIR/prompt.md` and replace the last argument,
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

## Read result

Read the report with `jq -r .result "$REVIEW_DIR/result.json"` and the denials
with `jq .permission_denials "$REVIEW_DIR/result.json"`. The denials list every
action Claude refused. Any entry there means the review is incomplete: report
it as failed, with the denied actions, and never as clean. A report that does
not show the reviewer read the target is incomplete too.
