## Verification

Before calling <work-scope> complete, use
[verify-<app>](.agents/skills/verify-<app>/SKILL.md) to select and run the relevant
checks. Update the [feature map](.agents/skills/verify-<app>/features/README.md)
when behavior is added, changed or removed. The skill decides which features
need a live drive and when focused checks suffice. Unchanged intended behavior
does not exempt a refactor from verification.

Follow the skill's Isolation, Launch, Doctor and Cleanup sections. Never attach
to or change services and data the verification did not create. Report an
occupied required resource as a blocker. Remove what the run created and keep
the evidence. Do not reset an environment at startup to cover for incomplete
cleanup.

Report actual coverage as pass, fail, partial or blocked, with omitted checks
and failures stated. Source-only maintenance is not live verification. Link
evidence with absolute Markdown targets resolved from the current checkout, and
check that the files exist after cleanup. Report cleanup failures and any
remaining resources.

Keep the map current with
[maintain-verify-<app>](.agents/skills/maintain-verify-<app>/SKILL.md):
`/maintain-verify-<app>` (new, changed and `draft` steps),
`/maintain-verify-<app> map only` (no drives) or
`/maintain-verify-<app> full audit` (every step). Use
`/maintain-project-verification-skill` to update these skills to the current
generator.

Run the focused tests, lint and type checks relevant to the change as well as any
required feature drives. Follow the repository's commands below.

- Tests: `<command>`
- Lint and type checks: `<command>`
