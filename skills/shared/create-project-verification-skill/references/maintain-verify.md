---
name: maintain-verify-<app>
description: "Maintain the verify-<app> feature map and drive new or meaningfully changed recipes. Use /maintain-verify-<app>, map only for source-only updates, or full audit to drive every feature."
disable-model-invocation: true
---

# Maintain verify-<app>

A feature map rots the moment the app changes. Each change updates its own features' entries as part of `verify-<app>`; maintenance catches what those updates missed.

## Choose the mode

- **Changed recipes (default):** `/maintain-verify-<app>` reads source, updates the map, then drives only new or meaningfully changed recipes.
- **Map only (explicit):** `/maintain-verify-<app> map only` updates the map from source without launching or driving the app. Report these edits as source-reviewed, not live-verified.
- **Full audit (explicit):** `/maintain-verify-<app> full audit`, or an explicit request to drive all features, updates the map and then drives every feature, including unchanged ones. Initial skill generation also requires this mode.

Honor an explicit source-only or drive-all request. Do not escalate to a full audit because many files changed or a recipe needs live confirmation. In map-only mode, record that uncertainty for a later drive. Ordinary `verify-<app>` still drives the features affected by a product change.

When you post a message anyway, you may add progress lines such as `read 2/5: search, theme — 1 wrong step` or `drive 7/16: projects — pass`. Never change how you split, delegate, or order work to produce them, and never add a turn just to report.

## Edit scope

In map-only mode, edit only the feature files and index; report helper or lifecycle problems without attempting a live repair. In either mode that drives features, corrections may also touch `verify-<app>/SKILL.md`, its helpers and its matching Claude Code stub. Never edit product code during maintenance.

## Update the map

Before editing, record the starting map and shared driving conventions so selection includes every change in this maintenance pass, even changes already committed during it. When invoked by the global maintenance skill, use its record from before conformance.

1. **Index.** Read `features/README.md` and list its sibling files. Fix missing, extra, duplicate, or dead entries.
2. **Read the source.** Cover each feature and inspect routes, navigation, commands or endpoints for missing features. When delegating, use small batches of read-only readers grouped by related features; do not require one agent per file. Readers never edit or drive. Return shape: feature summary / source entry points / likely drift or none / proposed recipe. Without subagents, read the groups yourself.
3. **Reconcile.** Spot-check cited drift and update the files and index. Require concrete source evidence for additions and removals. Preserve expected behavior supported by a request, documented contract or established test; current code alone does not prove that a conflicting expectation is obsolete. Report possible product defects and unresolved expectations instead of writing them into the map as normal behavior. Include exact prerequisite setup and fixture cleanup so each recipe can run from the baseline without another feature's leftovers.

## Select what to drive

- **Map only:** go directly to Ship, with no feature drives.
- **Changed recipes:** compare the final map with the recorded starting point. Select each added feature and each existing feature whose behavior, entry points, prerequisites, commands, expected results, proof or fixture cleanup changed meaningfully. A shared baseline or driving-convention change selects the recipes whose execution it affects, even if their files did not change. Wording, formatting, index repairs, unchanged renames and deletions alone select nothing. List selected features and why; if none qualify, go to Ship without launching the app.
- **Full audit:** select every remaining feature, including unchanged ones.

Drive each selected feature's whole recipe, including all mapped checks and entry points. Setup needed by a selected recipe does not require auditing the setup feature too. Do not treat unselected features as verified by this pass.

## Drive the selected features

You own all driving. Follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, Evidence and Cleanup sections, including operation deadlines and progress reporting. Create a fresh environment for the run; never attach to existing application services. One driver uses the run's environment at a time; readers remain read-only. Merge overlapping setup where practical, but exercise each selected feature's mapped checks and entry points. Keep a small progress table under `.cache/` with features reviewed, checks driven, results, omissions and evidence so an interrupted pass can resume without losing what was proved. After an aborted run, clean up its recorded leftovers and create a new environment for the remaining checks; retain evidence, not runtime state.

Run doctor before the first drive and after a failed drive. Classify failures using `verify-<app>`'s When a drive fails section. Correct driving instructions or helpers and retry affected steps. Report development-environment defects separately from product defects. Change an expected result only when there is evidence that the contract changed, never simply because the app disagrees. Record uncertain expectations for a decision. A known product failure stays failed; a disabled dependency's failure path does not verify its success path.

A blocked path needs its concrete missing prerequisite and the route or command attempted; add omitted prerequisites to the map. If doctor fails because of a helper defect, correct it and retry once before reporting the remaining blocker. When a healthy-looking app is wedged, clean up the run's resources and relaunch without resetting pre-existing resources.

Always finish or abort through Cleanup, including when startup or a drive fails. Remove run-created data and resources, restore the original environment, and retain evidence. Do not add a destructive reset before the pass. Check cleanup completed and evidence still exists before reporting; retain ownership records and report leftovers if cleanup failed. Re-run only affected checks after corrections.

## Ship

Follow the repository's branch, commit and PR conventions as edits are made. Keep all corrections in one branch and PR. Re-read changed files before shipping. Report the maintenance outcome separately from feature results:

- **clean:** the selected mode finished and there were no corrections. No new PR is needed. This does not mean all product checks passed.
- **changed:** the selected mode finished and corrections shipped in one PR.
- **blocked:** the selected mode could not finish, cleanup failed, or corrections could not ship safely. Say what remains incomplete, including any partial changes already shipped.

Always name the mode and summarize additions, removals and corrections, unresolved expectations and helper problems. For **map only**, state `Source-reviewed; no live drives run`. For **changed recipes**, list the selection reasons and report each selected feature; if none qualify, say no feature drives were needed. For **full audit**, report every feature. Live results follow `verify-<app>`'s Report section: pass, fail, partial or blocked, omissions and verified evidence links, plus classified findings and cleanup result. Distinguish source-reviewed edits from live results. Incomplete required live coverage makes maintenance blocked even if its map corrections shipped; a fully exercised product failure remains failed without making the maintenance itself incomplete.

Keep temporary working notes under `.agents/skills/verify-<app>/.cache/`, never in tracked files. Preserve the final progress/results table with the evidence and remove disposable working notes during cleanup.
