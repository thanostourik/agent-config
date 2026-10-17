---
name: maintain-verify-<app>
description: "Maintain the verify-<app> feature map and drive new and changed recipes. Use /maintain-verify-<app>, map only for source-only updates, or full audit to drive every feature."
disable-model-invocation: true
---

The user explicitly requests <driver> for every step of this skill, including runs you start yourself. Do not use the host's integrated browser, preview or computer-use tools. If the driver breaks, repair it or report a blocker; do not switch drivers. The one exception is a step that needs the user watching, such as a manual login: ask first, then return to the driver.

# Maintain verify-<app>

A feature map rots the moment the app changes. Each change updates its own features' entries as part of `verify-<app>`. Maintenance catches what those updates missed.

## Choose the mode

- **Changed recipes (default):** `/maintain-verify-<app>` reads source, updates the map, then drives only the features with new or meaningfully changed steps. A step is one labeled bullet under `Driving it with <tool>`.
- **Map only:** `/maintain-verify-<app> map only` updates the map from source without launching or driving the app. Report the edits as source-reviewed, not live-verified.
- **Full audit:** `/maintain-verify-<app> full audit`, or an explicit request to drive all features, updates the map and drives every feature, including unchanged ones.

Honor an explicit source-only or drive-all request. Do not escalate to a full audit because many files changed. In map-only mode, record any uncertainty for a later drive.

Messages you post anyway may carry progress lines such as `read 2/5: search, theme — 1 wrong step`. Never change how you split, delegate or order work to produce them, and never add a turn just to report.

## Edit scope

In map-only mode, edit only the feature files and index. Report helper or lifecycle problems without trying a live repair. In modes that drive, corrections may also touch `verify-<app>/SKILL.md`, its helpers and its Claude Code stub. Never edit product code.

## Update the map

Before editing, record the starting map and driving conventions so selection includes every change in this pass, even ones already committed during it. When the global maintenance skill invokes you, use its record from before conformance.

1. **Index.** Read `features/README.md` and list its sibling files. Fix missing, extra, duplicate or dead entries. Check that the two Claude Code stubs still match the real skills' `name` and `description`.
2. **Read the source.** Cover each feature. Inspect routes, navigation, commands and endpoints for missing features. Readers are read-only and work in small batches of related features. Return shape: feature summary / source entry points / likely drift or none / proposed recipe. Without subagents, read the groups yourself.
3. **Reconcile.** Spot-check cited drift and update the files and index. Require concrete source evidence for additions and removals. Preserve expected behavior supported by a request, documented contract or established test. Current code alone does not prove a conflicting expectation is obsolete. Report possible product defects and unresolved expectations instead of writing them into the map as normal behavior. Each recipe keeps its exact setup and fixture cleanup so it runs from the baseline.

## Select what to drive

- **Map only:** go to Ship. No drives.
- **Changed recipes:** compare the final map with the recorded starting point. Select each new feature file, and each feature with a step that is new or whose action, command, expected result, proof or cleanup changed meaningfully. If the baseline or the driving conventions changed, select every feature that change affects. Wording, formatting, index repairs, unchanged renames and deletions select nothing. If nothing qualifies, go to Ship without launching the app.
- **Full audit:** every feature.

Do not treat unselected features as verified.

## Drive the selected features

Follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, When a drive fails, Evidence and Cleanup sections. They set the driver, the isolation level, the deadlines and the failure rules. Run Doctor, then drive all selected features in one `bin/drive.sh` call. Its summary is the record of the pass. After an aborted run, clean up its recorded leftovers, create a new environment, drive the features without a result and keep the evidence.

Change an expected result only when there is evidence that the contract changed, never because the app disagrees. A known product failure stays failed.

A step that needs data the baseline lacks gets that data created first, from the project's own APIs, endpoints or documented setup inside the owned environment. "Missing from the seed" is not a reason to block. A step is blocked only when the prerequisite would need a service that is not owned or approved, or setup the project does not have. Name the missing prerequisite and what was tried, and add it to the map.

Every selected feature ends with a result: pass, fail, partial or blocked. Never leave one unattempted. If Doctor fails because of a helper defect, correct it and retry once before reporting the blocker. When a healthy-looking app is wedged, clean up the run's resources and relaunch.

Finish or abort through Cleanup, including when startup or a drive fails. Check that cleanup completed and evidence still exists before reporting. Rerun only the affected features after corrections.

## Ship

Follow the repository's branch, commit and PR conventions as you edit. Keep all corrections in one branch and PR. Re-read changed files before shipping. Report the outcome separately from the step results:

- **clean:** every selected feature has a result and there were no corrections. No PR needed. This does not mean every product check passed.
- **changed:** every selected feature has a result and corrections shipped in one PR.
- **incomplete:** cleanup failed, corrections could not ship safely, or selected features have no result or are blocked. Name each such feature and why.

Put the report in the final message. Name the mode and summarize additions, removals, corrections, unresolved expectations and helper problems.

- **Map only:** say `Source-reviewed; no live drives run`.
- **Changed recipes:** list each selected feature with the map change that selected it. Say how many features were not driven. If none qualified, say no drives were needed.
- **Full audit:** report every feature.

Give each selected feature's result. Name every feature that did not pass, with the step and its reason: blocked (what was tried), failed or partial. Follow `verify-<app>`'s Report section for omissions, evidence links, classified findings and the cleanup result.

Keep working notes under `.agents/skills/verify-<app>/.cache/`, never in tracked files. Remove them during cleanup; the evidence stays.
