---
name: maintain-verify-<app>
description: "Maintain the verify-<app> feature map and drive new and changed recipes. Use /maintain-verify-<app>, map only for source-only updates, or full audit to drive every feature."
disable-model-invocation: true
---

The user explicitly requests <driver> for every step of this skill, including runs you start yourself. Do not use the host's integrated browser, preview or computer-use tools. If the driver breaks, repair it or report a blocker; do not switch drivers. The one exception is a step that needs the user watching, such as a manual login: ask first, then return to the driver.

# Maintain verify-<app>

A feature map rots the moment the app changes. Each change updates its own features' entries as part of `verify-<app>`. Maintenance catches what those updates missed.

## Choose the mode

- **Changed recipes (default):** `/maintain-verify-<app>` reads source, updates the map, then drives only new and meaningfully changed steps. A step is one labeled bullet under `Driving it with <tool>`.
- **Map only:** `/maintain-verify-<app> map only` updates the map from source without launching or driving the app. Report the edits as source-reviewed, not live-verified.
- **Full audit:** `/maintain-verify-<app> full audit`, or an explicit request to drive all features, updates the map and drives every step of every feature, including unchanged ones.

Honor an explicit source-only or drive-all request. Do not escalate to a full audit because many files changed. In map-only mode, record any uncertainty for a later drive.

Messages you post anyway may carry progress lines such as `read 2/5: search, theme — 1 wrong step` or `drive 7/16: projects — pass`. Never change how you split, delegate or order work to produce them, and never add a turn just to report.

## Edit scope

In map-only mode, edit only the feature files and index. Report helper or lifecycle problems without trying a live repair. In modes that drive, corrections may also touch `verify-<app>/SKILL.md`, its helpers and its Claude Code stub. Never edit product code.

## Update the map

Before editing, record the starting map and driving conventions so selection includes every change in this pass, even ones already committed during it. When the global maintenance skill invokes you, use its record from before conformance.

1. **Index.** Read `features/README.md` and list its sibling files. Fix missing, extra, duplicate or dead entries. Check that the two Claude Code stubs still match the real skills' `name` and `description`.
2. **Read the source.** Cover each feature. Inspect routes, navigation, commands and endpoints for missing features. Readers are read-only and work in small batches of related features. Return shape: feature summary / source entry points / likely drift or none / proposed recipe. Without subagents, read the groups yourself.
3. **Reconcile.** Spot-check cited drift and update the files and index. Require concrete source evidence for additions and removals. Preserve expected behavior supported by a request, documented contract or established test. Current code alone does not prove a conflicting expectation is obsolete. Report possible product defects and unresolved expectations instead of writing them into the map as normal behavior. Each recipe keeps its exact setup and fixture cleanup so it runs from the baseline.

## Select what to drive

- **Map only:** go to Ship. No drives.
- **Changed recipes:** compare the final map with the recorded starting point, step by step. Select each step that is new or whose action, command, expected result, proof or fixture cleanup changed meaningfully, and every step of a new feature file. A new sub-feature selects the steps that exercise it. If a file's Preconditions, the baseline, the driving conventions or a cleanup step changed, select every step of the files that change affects. Wording, formatting, index repairs, unchanged renames and deletions select nothing. If nothing qualifies, go to Ship without launching the app.
- **Full audit:** every step of every feature.

Drive each selected step with the Preconditions it needs. Do not treat unselected steps or features as verified. A product change is different: `verify-<app>` drives the whole feature file.

## Drive the selected steps

You own all driving. Follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, When a drive fails, Evidence and Cleanup sections. They set the driver, the isolation level, the deadlines and the failure rules. Merge overlapping setup where practical, but exercise each selected feature's mapped checks and entry points.

Keep a small progress table under `.cache/` with the features reviewed, the checks driven, results, omissions and evidence, so an interrupted pass can resume. After an aborted run, clean up its recorded leftovers, create a new environment for the remaining checks and keep the evidence.

Run Doctor before the first drive and after a failed drive. Change an expected result only when there is evidence that the contract changed, never because the app disagrees. A known product failure stays failed.

A selected step that needs data the baseline lacks gets that data created first, from the project's own APIs, endpoints or documented setup inside the owned environment. "Missing from the seed" is not a reason to block. A step is blocked only when the prerequisite would need a service that is not owned or approved, or setup the project does not have. Name the missing prerequisite and what was tried, and add it to the map.

Every selected step ends with a result: pass, fail, partial or blocked. Never leave one unattempted. If Doctor fails because of a helper defect, correct it and retry once before reporting the blocker. When a healthy-looking app is wedged, clean up the run's resources and relaunch.

Finish or abort through Cleanup, including when startup or a drive fails. Check that cleanup completed and evidence still exists before reporting. Re-run only affected checks after corrections.

## Ship

Follow the repository's branch, commit and PR conventions as you edit. Keep all corrections in one branch and PR. Re-read changed files before shipping. Report the outcome separately from the step results:

- **clean:** every selected step has a result and there were no corrections. No PR needed. This does not mean every product check passed.
- **changed:** every selected step has a result and corrections shipped in one PR.
- **incomplete:** cleanup failed, corrections could not ship safely, or selected steps have no result or are blocked. Name each such step and why.

Put the report in the final message. Name the mode and summarize additions, removals, corrections, unresolved expectations and helper problems.

- **Map only:** say `Source-reviewed; no live drives run`.
- **Changed recipes:** list each selected feature with its selected steps and the map change that selected them. Say how many features were not driven. If none qualified, say no drives were needed.
- **Full audit:** report every feature.

Give each selected step's result. Name every step that did not pass with its reason: blocked (what was tried), failed or partial. Follow `verify-<app>`'s Report section for omissions, evidence links, classified findings and the cleanup result.

Keep working notes under `.agents/skills/verify-<app>/.cache/`, never in tracked files. Keep the final progress table with the evidence. Remove the other working notes during cleanup.
