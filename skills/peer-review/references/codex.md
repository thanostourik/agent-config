# Codex reviewer

Defaults: model `{{defaults.codex_model}}`, effort `{{defaults.codex_effort}}`.

## Target

For a branch against a base, use the standard diff review with `--base <base>`.
Codex always runs through the CLI below, in T3 Code too: its `/review` does not
work through a delegate.

## Run

For a standard diff review, choose exactly one target: `--uncommitted`,
`--base <branch>`, or `--commit <sha>`. Set `REVIEW_REPO`, `REVIEW_MODEL`,
`REVIEW_EFFORT`, and `REVIEW_DIR` to the absolute repository path, selected
model, selected effort, and artifact directory:

```bash
codex -C "$REVIEW_REPO" -s read-only -a never \
  exec -m "$REVIEW_MODEL" -c "review_model=\"$REVIEW_MODEL\"" \
  -c "model_reasoning_effort=\"$REVIEW_EFFORT\"" \
  -o "$REVIEW_DIR/report.md" review --uncommitted \
  </dev/null >"$REVIEW_DIR/run.log" 2>&1
```

Replace `--uncommitted` with the selected target flag. Do not combine target
flags with a custom prompt.

For a custom prompt (a plan, selected files, or a specific question), write
`$REVIEW_DIR/prompt.md` and run:

```bash
codex -C "$REVIEW_REPO" -s read-only -a never \
  exec -m "$REVIEW_MODEL" -c "model_reasoning_effort=\"$REVIEW_EFFORT\"" \
  -o "$REVIEW_DIR/report.md" - \
  <"$REVIEW_DIR/prompt.md" >"$REVIEW_DIR/run.log" 2>&1
```

## Read result

Read `$REVIEW_DIR/report.md`.
