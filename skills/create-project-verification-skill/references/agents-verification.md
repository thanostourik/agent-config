## Verification

Before calling work on <app> complete, verify it with
[verify-<app>](.agents/skills/verify-<app>/SKILL.md): `bin/verify up`, update the recipes
for behavior the change adds, alters or removes, `bin/verify affected`, fix failures, and
`bin/verify down` at the end. Drive only the features the change affects; `bin/verify all`
only when asked. Unchanged intended behavior does not exempt a refactor.

Never attach to or change services and data the verification did not create. Report each
driven feature as pass, fail or blocked, with evidence links to absolute paths, and report
cleanup failures separately.

Run the focused checks relevant to the change as well:

- Tests: `<command>`
- Lint and type checks: `<command>`

`/maintain-project-verification-skill` brings this skill up to date with its generator.
