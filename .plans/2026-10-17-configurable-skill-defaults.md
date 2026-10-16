# Configurable skill defaults

`config.json` `skills.<name>.defaults` sets model, provider, and effort values
for a skill. In skill Markdown, `{{defaults.<name>|<shipped value>}}` marks a
value; sync renders it with the override or the shipped value. Explicit user
choices still win. Sync rejects malformed markers, conflicting shipped values,
unknown names, and invalid values before writing, disabled skills included.

Covered: the four CLI review skills (`model`, `effort`), `t3-fan-out`
(`provider`, `model`, `effort`), and `triple-review` (the same three per
reviewer, prefixed `general_`, `simplify_`, `over_engineering_`).

Steps: add rendering and validation to sync, mark the six skills, list the
options in `config.example.json`, document briefly, open the PR, then verify
with the existing suite and temporary `--home` runs.
