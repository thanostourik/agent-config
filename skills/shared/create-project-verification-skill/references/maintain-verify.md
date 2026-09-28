---
name: maintain-verify-<app>
description: "Keep the verify-<app> skill and its feature map honest. Use with one feature after a change adds or alters it, or with no argument for a full audit of every feature."
---

# Maintain verify-<app>

A feature map rots the moment the app changes. This skill keeps `.agents/skills/verify-<app>/` true to the app. The unit of rigor is the feature, not every sentence: cover each feature from source and exercise it live, without terminalising every bullet.

When the request names one or more features (or describes a new one), run the **feature pass**. When it names none, run the **full audit**.

## Edit scope

Only edit `.agents/skills/verify-<app>/` (its SKILL.md, features/, and helper scripts) and the matching stub in `.claude/skills/`. Never edit product code during a pass: a behavior the map describes that the app no longer does is either doc drift (fix the map) or a product regression (report it, don't paper over it in docs).

## Feature pass

Run this in the branch that changed the feature, as part of that work.

1. **Read the change.** Diff the branch against its base and read the source behind the named feature: its routes, commands, or endpoints, as a user reaches them.
2. **Update the map.** Edit the feature file so it matches the source: sub-features, entry points, commands, gotchas. For a new feature, create its file in the shape `features/README.md` describes and add it to the index. If the change removed a feature, delete its file and index entry.
3. **Drive it.** Follow `verify-<app>`: doctor, launch if needed, drive the feature file, capture evidence, clean up. A step that fails because the map is wrong is fixed and re-driven; a step that fails because the app is wrong is a finding for the user.
4. **Report** the feature, what changed in the map, and the evidence location. The map edits are committed with the branch's other work.

## Full audit

### Outcomes

Pick one, and say which:

- **clean**: every feature got source and live coverage; nothing worth shipping. No branch, no PR.
- **changed**: one PR ships proven doc, harness, or map corrections.
- **blocked**: coverage could not finish or a proven fix could not ship safely. Say exactly what blocked it.

### Pass

1. **Index hygiene.** Read the feature map README and glob its sibling files. Fix missing, extra, duplicate, or dead entries. Lightweight; no generated inventory.
2. **Source wave.** One read-only subagent per feature file, launched concurrently where the agent supports subagents; otherwise read each feature in turn. Each explains "how does this user-facing feature work?" from source, flags likely doc drift with citations, and returns one concise live-verification recipe. Readers never drive the app and never edit files. Return shape: feature summary / source entry points / likely drift or none / one recipe.
3. **Reconcile.** Every feature file has a returned summary. Merge overlapping recipes into as few app states as practical. Spot-check cited drift; don't re-prove clean claims. Sweep recent churn for user-facing surfaces missing from the map; require a concrete source path before calling one missing.
4. **Live pass.** Required even when source looks clean. The coordinator owns all driving and follows `verify-<app>`'s launch model. Exercise every feature at least once, and hold three invariants the whole pass, whatever the failure: (1) never drive an instance you haven't health-checked since it last did something surprising: doctor before the first drive, doctor again after any failed drive, and where doctor can't see the failure (a wedged UI on a healthy process), reset to a known state or relaunch rather than hoping; (2) evidence captured so far survives every cleanup, checked at its location, not assumed; (3) nothing a drive started outlives that drive's usefulness. A doctor failure caused by skill drift is drift: fix it under edit scope and retry once before calling the pass `blocked`. A feature that can't be reached is `verified-unreachable` only with the concrete prerequisite (auth, entitlement, OS, external state) and the route attempted; if the map omits that prerequisite, that's drift. Any harness fix gets re-driven live before it ships. Final teardown happens after the last drive.
5. **Triage.** Wrong or missing user-POV description: doc drift, fix it. Working behavior the harness can't drive: harness gap, fix it (scripts executable, invocation documented in the skill body). App behavior that's actually broken: product gap; record it for the user, keep it out of the PR.
6. **Ship or stop.** For changed: one branch and one PR of proven corrections, following the repo's conventions; re-read every changed file first. For clean or blocked: no PR; report the outcome and the coverage honestly.

Keep concise run notes (features covered, unreachable prerequisites, confirmed drift, outcome) outside the repo or in a gitignored location; don't commit them.
