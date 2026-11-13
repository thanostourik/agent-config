## Verification

Before calling work on <app> complete, verify it with
[verify-<app>](.agents/skills/verify-<app>/SKILL.md): run
`.agents/skills/verify-<app>/bin/verify up`, update the recipes for behavior the change adds,
alters or removes, run `verify affected`, fix failures, and run `verify down` at the end.
Drive only the features the change affects, and run `verify all` only when asked. A refactor
is verified too, even though it is meant to change no behavior.

Never attach to or change services and data the verification did not create. Report each
driven feature as pass, fail or blocked, with evidence links to absolute paths, and report
cleanup failures separately.

Run the focused checks relevant to the change as well:

- Tests: `<command>`, or "none" when the repo has no test suite
- Lint and type checks: `<command>`, or "none"

`/verify-<app> full` drives every feature, repairs the failing ones and records what no recipe
covers. `/maintain-project-verification-skill` brings this skill up to date with its generator.
