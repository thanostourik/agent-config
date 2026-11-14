## Verification

Before calling work on <app> complete, verify it with
[verify-<app>](.agents/skills/verify-<app>/SKILL.md). Run
`.agents/skills/verify-<app>/bin/verify up`. For a bug, drive the feature that shows it
before the fix, and see it fail. Update the recipes for behavior the change adds, alters
or removes. Drive only that feature until it passes. Then run `verify affected` once,
drive by name the features it lists that your change alters, fix failures, and run
`verify down` at the end. `verify affected` drives the recipes the change edited and the
features that check the code it edited. Run `verify all` only when asked. A refactor is
verified too, even though it is meant to change no behavior.

Never attach to or change services and data the verification did not create. Report each
driven feature as pass, fail or blocked, with evidence links to absolute paths, and report
cleanup failures separately.

Run the focused checks relevant to the change as well:

- Tests: `<command>`, or "none" when the repo has no test suite
- Lint and type checks: `<command>`, or "none"

`/verify-<app> full` drives every feature, repairs the failing ones and records what no recipe
covers. `/maintain-project-verification-skill` brings this skill up to date with its generator.
