# Configurable skill defaults

The committed `config.defaults.json` holds every shipped setting.
The optional, gitignored `config.json` overrides single
settings: sync merges objects key by key, and any other value replaces the
shipped one. `mcp.jira.instances` ships empty; Jira URLs and `gate` go only in
`config.json`.

In skill Markdown, `{{defaults.<name>}}` marks a value. Sync fills it from the
merged `skills.<skill>.defaults.<name>`. A marker without a value, a value
without a marker, and malformed markers stop sync before any write, disabled
skills included. Explicit user choices still win.

Covered: the four CLI review skills (`model`, `effort`), `t3-fan-out`
(`provider`, `model`, `effort`), and `triple-review` (the same three per
reviewer, prefixed `general_`, `simplify_`, `over_engineering_`).

Steps: load and merge the two configs, render the six skills' markers, update
existing test fixtures, document briefly, push the PR, then verify with the
existing suite and temporary `--home` runs.
