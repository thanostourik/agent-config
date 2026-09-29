---
name: maintain-verify-<app>
description: "Full audit of the verify-<app> skill and its feature map: read every feature from source, drive every feature live, and ship one PR of proven corrections. Run it by hand now and then, with /maintain-verify-<app>."
disable-model-invocation: true
---

# Maintain verify-<app>

A feature map rots the moment the app changes. Each change updates its own features' entries as part of `verify-<app>`; this audit catches what those updates missed. The unit of rigor is the feature, not every sentence: cover each feature from source and exercise it live, without re-proving every bullet.

When you post a message anyway, you may add progress lines such as `read 2/5: search, theme — 1 wrong step` or `drive 7/16: projects — pass`. Never change how you split, delegate, or order work to produce them, and never add a turn just to report.

## Edit scope

Only edit `.agents/skills/verify-<app>/` (its SKILL.md, features/, and helper scripts) and the matching stub in `.claude/skills/`. Never edit product code: a behavior the map describes that the app no longer does is either map drift (fix the map) or a product regression (report it, don't paper over it in the map).

## Pass

1. **Index.** Read `features/README.md` and list its sibling files. Fix missing, extra, duplicate, or dead entries.
2. **Read the source.** One read-only subagent per feature file, launched concurrently where the agent supports subagents; otherwise read each feature in turn. Each explains how the user-facing feature works from source, flags likely map drift with citations, and returns one concise recipe to drive it. Readers never drive the app and never edit files. Return shape: feature summary / source entry points / likely drift or none / one recipe.
3. **Reconcile.** Every feature file has a returned summary. Spot-check cited drift; don't re-prove clean claims. Look for user-facing features missing from the map (routes, navigation, commands, recent changes); require a concrete source path before calling one missing, then write its feature file and index entry. Merge overlapping recipes into as few app states as practical.
4. **Drive everything.** Required even when the source looks clean. You own all driving and follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, Evidence, and Cleanup sections. Drive every feature file, whole. When a step fails, decide which of three it is:
   - **Map drift:** the file is wrong about the app (description, sub-features, entry points, steps, commands, expected results). Fix the file to match what the app does and re-drive the fixed steps.
   - **Harness gap:** the app works but the skill can't drive it. Fix the skill or its helpers and re-drive.
   - **Product gap:** the app is actually broken. Record it for the user and keep the expected result as it was; never write a bug into the map as expected behavior.

   A feature that can't be reached is unreachable only with the concrete prerequisite (auth, entitlement, OS, external state) and the route attempted; if the map omits that prerequisite, that's drift. A doctor failure caused by the skill itself is a harness gap: fix it and retry once before calling the pass blocked.

   Throughout, hold three invariants: doctor before the first drive and after any failed drive, and reset or relaunch when the app looks wedged even though doctor passes; evidence captured so far survives every cleanup, checked where it lives; nothing a drive started outlives its use. Tear down after the last drive, then check the evidence is still there.

## Ship

Pick one outcome and say which:

- **clean:** every feature got source and live coverage; nothing to change. No branch, no PR.
- **changed:** one branch and one PR of proven corrections, following the repo's conventions. Re-read every changed file first.
- **blocked:** coverage could not finish, or a proven fix could not ship safely. Say exactly what blocked it.

Report per `verify-<app>`'s Report section, one line per feature, plus the product gaps found. Keep working notes in `.agents/skills/verify-<app>/.cache/`, never in the repo's tracked files.
