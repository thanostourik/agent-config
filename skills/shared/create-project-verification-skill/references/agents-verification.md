## Verification

Before calling a change to the app's user-facing behavior complete, use
[verify-<app>](.agents/skills/verify-<app>/SKILL.md). Read the
[feature map](.agents/skills/verify-<app>/features/README.md), update entries for
the behavior added, changed or removed, and drive the affected features. A change
with no user-facing effect needs the relevant focused checks, not an app drive.

Use [maintain-verify-<app>](.agents/skills/maintain-verify-<app>/SKILL.md) to keep the
map current. Its default mode reviews source and updates the map without
launching or driving the app. Request `full audit` explicitly to also drive every
feature, including unchanged ones. Use `/maintain-project-verification-skill` to
update these skills to the current generator; that also defaults to map-only
maintenance, with focused live checks for changed helpers.

Follow the verification skill's Isolation, Launch, Doctor and Cleanup sections
for environment management. Preserve pre-existing services and data; never stop
someone else's process to free a port. After completion or failure, remove the
run's resources and temporary data, restore what it changed, and retain evidence.
Do not reset an environment at startup to compensate for incomplete cleanup.

Report actual coverage as pass, fail, partial or blocked, with omitted checks and
failures stated explicitly. Source-only maintenance is not live verification.
Link evidence using absolute Markdown targets resolved from the current checkout,
and check the linked files exist after cleanup. Report cleanup failures and any
remaining resources.

Run the focused tests, lint and type checks relevant to the change as well as any
required feature drives. Follow the repository's commands below.
