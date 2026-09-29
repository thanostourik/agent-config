---
name: maintain-verify-<app>
description: "Full audit of the verify-<app> skill and its feature map: read every feature from source, drive every feature live, and ship one PR of proven corrections. Run it by hand now and then, with /maintain-verify-<app>."
disable-model-invocation: true
---

# Maintain verify-<app>

A feature map rots the moment the app changes. Each change updates its own features' entries as part of `verify-<app>`; this audit catches what those updates missed. The unit of rigor is the feature, not every sentence: cover each feature from source and exercise it live, without terminalising every bullet.

## Edit scope

Only edit `.agents/skills/verify-<app>/` (its SKILL.md, features/, and helper scripts) and the matching stub in `.claude/skills/`. Never edit product code during a pass: a behavior the map describes that the app no longer does is either doc drift (fix the map) or a product regression (report it, don't paper over it in docs).

## Outcomes

Pick one, and say which:

- **clean**: every feature got source and live coverage; nothing worth shipping. No branch, no PR.
- **changed**: one PR ships proven doc, harness, or map corrections.
- **blocked**: coverage could not finish or a proven fix could not ship safely. Say exactly what blocked it.

## Pass

When you post a message anyway, you may add progress lines such as `read 2/5: search, theme — 1 wrong step` or `drive 7/16: projects — pass`. Never change how you split, delegate, or order work to produce them, and never add a turn just to report.

1. **Index hygiene.** Read the feature map README and glob its sibling files. Fix missing, extra, duplicate, or dead entries. Lightweight; no generated inventory.
2. **Source wave.** One read-only subagent per feature file, launched concurrently where the agent supports subagents; otherwise read each feature in turn. Each explains "how does this user-facing feature work?" from source, flags likely doc drift with citations, and returns one concise live-verification recipe. Readers never drive the app and never edit files. Return shape: feature summary / source entry points / likely drift or none / one recipe.
3. **Reconcile.** Every feature file has a returned summary. Merge overlapping recipes into as few app states as practical. Spot-check cited drift; don't re-prove clean claims. Look for user-facing features missing from the map (routes, navigation, commands, recent changes); require a concrete source path before calling one missing. Write a feature file and index entry for each missing feature; the live pass drives it like the rest.
4. **Live pass.** Required even when source looks clean. The coordinator owns all driving and follows `verify-<app>`'s launch model. Exercise every feature at least once, and hold three invariants the whole pass, whatever the failure: (1) never drive an instance you haven't health-checked since it last did something surprising: doctor before the first drive, doctor again after any failed drive, and where doctor can't see the failure (a wedged UI on a healthy process), reset to a known state or relaunch rather than hoping; (2) evidence captured so far survives every cleanup, checked at its location, not assumed; (3) nothing a drive started outlives that drive's usefulness. A doctor failure caused by skill drift is drift: fix it under edit scope and retry once before calling the pass `blocked`. A feature that can't be reached is `verified-unreachable` only with the concrete prerequisite (auth, entitlement, OS, external state) and the route attempted; if the map omits that prerequisite, that's drift. Any harness or map fix gets re-driven live before it ships. Final teardown happens after the last drive.
5. **Triage.** Anything in a feature file that the source or the drive shows is wrong (description, sub-features, entry points, steps, commands, expected results), or a missing feature: map drift. Fix the file to match what the app does, and re-drive the fixed steps. Working behavior the harness can't drive: harness gap, fix it (scripts executable, invocation documented in the skill body). App behavior that's actually broken: product gap; record it for the user, keep it out of the PR, and never write it into the map as expected behavior.
6. **Ship or stop.** For changed: one branch and one PR of proven corrections, following the repo's conventions; re-read every changed file first. For clean or blocked: no PR; report the outcome and the coverage honestly. Either way, the report gives one line per feature: the result and the path of the file that shows it, relative to the repo root.

Keep concise run notes (features covered, unreachable prerequisites, confirmed drift, outcome) outside the repo or in a gitignored location; don't commit them.
