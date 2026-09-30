## Verification

Before calling <work-scope> complete, use
[verify-<app>](.agents/skills/verify-<app>/SKILL.md) to select and run the relevant
checks. Update the [feature map](.agents/skills/verify-<app>/features/README.md)
when behavior is added, changed or removed. The skill decides which features
need a live drive and when focused checks suffice. Unchanged intended behavior
does not automatically exempt a refactor from verification.

Use [maintain-verify-<app>](.agents/skills/maintain-verify-<app>/SKILL.md) to keep the
map current. `/maintain-verify-<app>` reviews source, updates the map and drives
new or meaningfully changed recipes. Wording, index edits and deletions alone
need no drives. `/maintain-verify-<app> map only` updates without launching or
driving the app; `/maintain-verify-<app> full audit` drives every feature, including
unchanged ones. Use `/maintain-project-verification-skill` to update these skills
to the current generator with the same three modes. Global maintenance also
runs focused live checks for changed helpers, even with `map only`.

Follow the verification skill's Isolation, Launch, Doctor and Cleanup sections
to create a fresh, disposable environment for each run. Never attach to existing
application services or use their data; report occupied required resources as a
blocker. After completion or failure, remove the run's resources and temporary
data, restore what it changed, and retain evidence. Leave pre-existing services
and data untouched.
Do not reset an environment at startup to compensate for incomplete cleanup.

Report actual coverage as pass, fail, partial or blocked, with omitted checks and
failures stated explicitly. Source-only maintenance is not live verification.
Link evidence using absolute Markdown targets resolved from the current checkout,
and check the linked files exist after cleanup. Report cleanup failures and any
remaining resources.

Run the focused tests, lint and type checks relevant to the change as well as any
required feature drives. Follow the repository's commands below.
