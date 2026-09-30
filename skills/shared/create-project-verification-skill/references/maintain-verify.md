---
name: maintain-verify-<app>
description: "Maintain the verify-<app> feature map from source without driving the app. Use /maintain-verify-<app> for map updates, or explicitly request full audit to also drive every feature live."
disable-model-invocation: true
---

# Maintain verify-<app>

A feature map rots the moment the app changes. Each change updates its own features' entries as part of `verify-<app>`; maintenance catches what those updates missed.

## Choose the mode

- **Update map (default):** `/maintain-verify-<app>` reads source and updates the feature files and index. Do not launch or drive the app. Report these edits as source-reviewed, not live-verified.
- **Full audit (explicit):** `/maintain-verify-<app> full audit`, or an explicit request to drive all features, updates the map and then drives every feature, including unchanged ones. Initial skill generation also requires this mode.

Do not escalate map maintenance to a full audit because many files changed or a recipe needs live confirmation. Record that uncertainty for a later drive. Ordinary `verify-<app>` still drives the features affected by a product change.

When you post a message anyway, you may add progress lines such as `read 2/5: search, theme — 1 wrong step` or `drive 7/16: projects — pass`. Never change how you split, delegate, or order work to produce them, and never add a turn just to report.

## Edit scope

In update-map mode, edit only the feature files and index; report helper or lifecycle problems without attempting a live repair. In full-audit mode, corrections may also touch `verify-<app>/SKILL.md`, its helpers and its matching Claude Code stub. Never edit product code during maintenance.

## Update the map

1. **Index.** Read `features/README.md` and list its sibling files. Fix missing, extra, duplicate, or dead entries.
2. **Read the source.** Cover each feature and inspect routes, navigation, commands or endpoints for missing features. When delegating, use small batches of read-only readers grouped by related features; do not require one agent per file. Readers never edit or drive. Return shape: feature summary / source entry points / likely drift or none / proposed recipe. Without subagents, read the groups yourself.
3. **Reconcile.** Spot-check cited drift and update the files and index. Require concrete source evidence for additions and removals. Preserve expected behavior supported by a request, documented contract or established test; current code alone does not prove that a conflicting expectation is obsolete. Report possible product defects and unresolved expectations instead of writing them into the map as normal behavior. Include exact prerequisite setup and fixture cleanup so each recipe can run from the baseline without another feature's leftovers.

For update-map mode, continue directly to Ship. No browser, app startup or feature drive is needed to complete this mode.

## Full audit only

You own all driving. Follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, Evidence and Cleanup sections. One driver uses the shared environment at a time; readers remain read-only. Merge overlapping setup where practical, but exercise every feature's mapped checks and entry points. Keep a small progress table under `.cache/` with features reviewed, checks driven, results, omissions and evidence so an interrupted pass can resume without losing what was proved. Re-establish prerequisites when resuming; old runtime state is not a baseline.

Run doctor before the first drive and after a failed drive. Classify failures using `verify-<app>`'s When a drive fails section. Correct driving instructions or helpers and retry affected steps. Report development-environment defects separately from product defects. Change an expected result only when there is evidence that the contract changed, never simply because the app disagrees. Record uncertain expectations for a decision. A known product failure stays failed; a disabled dependency's failure path does not verify its success path.

A blocked path needs its concrete missing prerequisite and the route or command attempted; add omitted prerequisites to the map. If doctor fails because of a helper defect, correct it and retry once before reporting the remaining blocker. When a healthy-looking app is wedged, clean up the run's resources and relaunch without resetting pre-existing resources.

Always finish or abort through Cleanup, including when startup or a drive fails. Remove run-created data and resources, restore the original environment, and retain evidence. Do not add a destructive reset before the pass. Check cleanup completed and evidence still exists before reporting; retain ownership records and report leftovers if cleanup failed. Re-run only affected checks after corrections.

## Ship

Follow the repository's branch, commit and PR conventions as edits are made. Keep all corrections in one branch and PR. Re-read changed files before shipping. Report the maintenance outcome separately from feature results:

- **clean:** the selected mode finished and there were no corrections. No new PR is needed. This does not mean all product checks passed.
- **changed:** the selected mode finished and corrections shipped in one PR.
- **blocked:** the selected mode could not finish, cleanup failed, or corrections could not ship safely. Say what remains incomplete, including any partial changes already shipped.

For **update map**, name the mode, summarize additions, removals and corrections, and state `Source-reviewed; no live drives run`. Include unresolved expectations and helper problems. For **full audit**, also report per `verify-<app>`'s Report section: one line per feature with pass, fail, partial or blocked, omissions and verified evidence links, plus the classified findings and cleanup result. Incomplete live coverage makes the full audit blocked even if its map corrections shipped.

Keep temporary working notes under `.agents/skills/verify-<app>/.cache/`, never in tracked files. Preserve the final progress/results table with the evidence and remove disposable working notes during cleanup.
