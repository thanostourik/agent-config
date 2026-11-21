# Grok reviewer

Runs Grok Build's built-in `/review` locally with an installed, authenticated
`grok` CLI, or as a T3 delegate.
Defaults: model `{{defaults.grok_model}}`, effort `{{defaults.grok_effort}}`.

## Target

Write `$REVIEW_DIR/prompt.md` as one `/review` line for the targets it covers:

- Uncommitted changes: `/review --local`.
- The current branch with a clean tree: `/review --main`. It compares against
  `origin/main` or `origin/master`.
- Another branch: `/review --branch <name>`.

Never pass `--pr`, `--stack`, `--submit`, or `--approve`; they post to GitHub.
`/review --local` reviews every uncommitted change. If the tree holds user
changes outside the requested target, say so when presenting the findings.

For a branch against a base: when the base is `origin/main` or `origin/master`,
`prompt.md` is `/review --branch <branch>` (it ignores uncommitted files in the
tree). For any other base, `prompt.md` holds only the target and
`git diff <base>...<branch>`. That prompt, like every custom prompt (commits,
plans, selected files, or `review-loop`'s evidence check), runs through the CLI
command below, never as a T3 delegate.

## Run as a T3 delegate

In T3 Code, when `prompt.md` is a `/review` line, run it as a delegate instead
of the CLI command below. Call `orchestrator_capabilities` and check that
provider `grok` offers the selected model and effort. Then call `delegate_task`
with `mode: "async"`, `target: {providerInstanceId: "grok", model: <model>,
options: {reasoningEffort: <effort>}}`, and the `/review` line as the whole
task. Set no `role`: `role: "review"` puts a sentence in front of the task, and
Grok then no longer reads it as a slash command.

The result is the review's closing summary, which names its findings file under
`/tmp/grok-<user>/`. The delegate has no read-only sandbox, so compare
`git status --short` and `git rev-parse HEAD` with the recorded values; report
any change it made and never treat its files or commits as part of the reviewed
work. If the delegate is unavailable or fails, run the CLI command below.

## Run through the CLI

Run `grok --version` first. If it is 1.0.66 or older, stop and ask the user to
update Grok; do not update it yourself. Those versions can keep running after
the review has finished.

Set `REVIEW_REPO`, `REVIEW_MODEL`, `REVIEW_EFFORT`, and `REVIEW_DIR` to the
absolute repository path, selected model, selected effort, and artifact
directory:

```bash
grok --cwd "$REVIEW_REPO" --model "$REVIEW_MODEL" --effort "$REVIEW_EFFORT" \
  --sandbox read-only --always-approve --disable-web-search \
  --output-format plain -p "$(cat "$REVIEW_DIR/prompt.md")" \
  </dev/null >"$REVIEW_DIR/report.md" 2>"$REVIEW_DIR/run.log"
```

`/review` gives its reviewer a shell and a write tool, so `--always-approve` is
safe only inside the `read-only` sandbox: the kernel blocks writes outside
`~/.grok` and temp directories, and blocks network access for its commands.
`/review` writes its full findings to a file under the temp directory and names
that file in the report. This is a static review: the caller remains
responsible for tests.

## Read result

Read `$REVIEW_DIR/report.md` (or the delegate summary) and the findings file it
names.
