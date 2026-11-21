# Cursor Grok reviewer

Runs a local review with the Cursor CLI (`cursor-agent`).
Defaults: model `{{defaults.cursor_grok_model}}`, effort
`{{defaults.cursor_grok_effort}}`. Cursor names a model and effort together as
one id, `<model>-<effort>`, for example
`{{defaults.cursor_grok_model}}-{{defaults.cursor_grok_effort}}`; check
`cursor-agent --list-models` if the id is not listed.

## Target

Cursor has no built-in review. Write `$REVIEW_DIR/prompt.md` using the custom
prompt format from [SKILL.md](../SKILL.md) (for a branch against a base, name
only the absolute repository path, the instruction to run commands from there,
the target, and `git diff <base>...<branch>`).

Write `$REVIEW_DIR/cursor-config/cli-config.json`:

```json
{
  "version": 1,
  "editor": { "vimMode": false },
  "approvalMode": "allowlist",
  "permissions": {
    "allow": ["Read(**)"],
    "deny": ["Write(**)"]
  }
}
```

The user's own Cursor config may approve every tool, so this separate config
replaces it: the file-write tool is rejected and the file-read tool may read
anywhere. Cursor also writes session files into this directory, so use a new
one for every run.

## Run

Set `REVIEW_REPO`, `REVIEW_MODEL`, `REVIEW_EFFORT`, and `REVIEW_DIR` to the
absolute repository path, selected model, selected effort, and artifact
directory:

```bash
REVIEW_WORKSPACE=$(mktemp -d) &&
CURSOR_CONFIG_DIR="$REVIEW_DIR/cursor-config" cursor-agent -p --trust \
  --sandbox enabled --workspace "$REVIEW_WORKSPACE" \
  --model "$REVIEW_MODEL-$REVIEW_EFFORT" \
  --output-format json "$(cat "$REVIEW_DIR/prompt.md")" \
  </dev/null >"$REVIEW_DIR/result.json" 2>"$REVIEW_DIR/run.log"
```

The reviewer may run any shell command, but only inside Cursor's sandbox, which
lets it write to its workspace and temp directories only and blocks network
access. The workspace is an empty temp directory outside the repository, so the
repository and its git directory stay read-only. Keep `json` output: `text`
output keeps only the reviewer's last message, and a short message after the
report replaces it. Do not go back to an allow-list of shell commands: Cursor
rejects ordinary forms such as `git diff $(git merge-base …)`,
`cd src && git diff`, or a pipe to `head`, and the reviewer then reviews
without the diff. Do not use `--mode ask` either: in print mode it removes the
shell tool. This is a static review: the caller remains responsible for tests.

## Read result

Read the report with `jq -r .result "$REVIEW_DIR/result.json"`; it holds every
message the reviewer wrote. A report that does not show the reviewer read the
target is incomplete: report it as failed, never as clean.
