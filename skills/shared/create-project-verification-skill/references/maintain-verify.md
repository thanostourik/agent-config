---
name: maintain-verify-<app>
description: "Maintain the verify-<app> feature map and drive new and changed recipes. Use /maintain-verify-<app>, map only for source-only updates, or full audit to drive every feature."
disable-model-invocation: true
---

The user explicitly requests <driver> for every step of this skill, including runs you start yourself. Do not use the host's integrated browser, preview or computer-use tools. If the driver breaks, repair it or report a blocker; do not switch drivers. The one exception is a step that needs the user watching, such as a manual login: ask first, then return to the driver.

# Maintain verify-<app>

A feature map rots the moment the app changes. Each change updates its own features' entries as part of `verify-<app>`. Maintenance catches what those updates missed.

## Choose the mode

- **Changed recipes (default):** `/maintain-verify-<app>` launches the app, checks every feature against source, re-records the recipes that drifted, then drives only the features with new or meaningfully changed steps. A step is one labeled bullet under `Driving it with <tool>`.
- **Map only:** `/maintain-verify-<app> map only` updates the map from source without launching or driving the app. Report the edits as source-reviewed, not live-verified.
- **Full audit:** `/maintain-verify-<app> full audit`, or an explicit request to drive all features, updates the map, converts every recipe whose steps lack `bash` blocks, and drives every feature, including unchanged ones.

Honor an explicit source-only or drive-all request. Do not escalate to a full audit because many files changed. In map-only mode, record any uncertainty for a later drive.

Messages you post anyway may carry progress lines such as `read 2/5: search, theme — 1 wrong step`. Never change how you split, delegate or order work to produce them, and never add a turn just to report.

## Helpers

Helper agents do the reading and recording, so your own context stays small. Read only what they return. Never open a feature file a helper wrote.

- A **reader** reads source for a small group of related features and proposes edits. It edits nothing. Readers work in map-only mode.
- A **recorder** takes 3 to 5 related features, such as one screen area or features that share a login or fixtures. It checks each against source and records the recipes that need it against the live app with `bin/rec.sh`. Recorders work in the modes that drive.
- A **fixer** takes one feature that failed a drive, repairs its recipe and drives it again.

Start recorders and fixers with the briefs under Helper briefs. Without a subagent tool, do the same work yourself, one group at a time, still through `bin/rec.sh`.

## Edit scope

In map-only mode, edit only the feature files and index. Report helper or lifecycle problems without trying a live repair. In modes that drive, recorders and fixers edit only their own feature files. You edit the index, `verify-<app>/SKILL.md`, its helpers other than `drive.sh`, `steps.sh` and `rec.sh`, and its Claude Code stub. Never edit product code.

## Update the map

Before editing, record the starting map and driving conventions so selection includes every change in this pass, even ones already committed during it. When the global maintenance skill invokes you, use its record from before conformance.

1. **Index.** Read `features/README.md` and list its sibling files. Fix missing, extra, duplicate or dead entries. Inspect routes, navigation, commands and endpoints for features the index lacks: a list, not a read of every component. Check that the two Claude Code stubs still match the real skills' `name` and `description`.
2. **Map only: read.** Readers cover every feature in small batches of related features. Return shape: feature summary / source entry points / likely drift or none / proposed recipe. Without subagents, read the groups yourself. Spot-check cited drift and update the files and index. Require concrete source evidence for additions and removals. Preserve expected behavior supported by a request, documented contract or established test. Current code alone does not prove a conflicting expectation is obsolete. Report possible product defects and unresolved expectations instead of writing them into the map as normal behavior. Each recipe keeps its exact setup and fixture cleanup so it runs from the baseline.
3. **Modes that drive: record.** Follow `verify-<app>`'s Isolation, Launch and Doctor sections. Then give every feature to a recorder, a few recorders at a time, all on that one environment. Each feature keeps its own `VERIFY_SESSION`, so recorders work side by side like `drive.sh --jobs`. Features that change state other features read, such as global settings, go to a recorder that starts after the others return. In a full audit, tell recorders to convert. Read only the reports:
   - Compare the Names lists. When two features create the same account, fixture or resource name, send one of them back to a recorder to rename it.
   - Make the helper changes that reports name as blockers yourself, then send the blocked features back to a recorder.
   - Add new features to the index.
   - Report each Difference as a possible product defect or unresolved expectation.

## Select what to drive

- **Map only:** go to Ship. No drives.
- **Changed recipes:** select each feature that the recorders' Files lists name as new, or as having a step that is new or whose action, command, expected result, proof or cleanup changed meaningfully. If the baseline or the driving conventions changed since the recorded starting point, select every feature that change affects. Wording, formatting, index repairs, unchanged renames and deletions select nothing. If nothing qualifies, run Cleanup and go to Ship.
- **Full audit:** every feature.

A selected feature whose steps lack `bash` blocks goes to a recorder to be converted before the drive. `drive.sh` refuses to run it otherwise, and its refusal names the step. Unselected recipes stay as they are.

Do not treat unselected features as verified.

## Drive the selected features

Follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, When a drive fails, Evidence and Cleanup sections. They set the driver, the isolation level, the deadlines and the failure rules. Run Doctor, then drive all selected features in one `bin/drive.sh` call. Then drive them once more without relaunching: that proves each `Clean up` step leaves the app ready for the next run. The two summaries are the record of the pass. After an aborted run, clean up its recorded leftovers, create a new environment, drive the features without a result and keep the evidence.

Send each failing feature to a fresh fixer with the feature name, the failing step and its log path. Read only the line it returns. Run one fixer at a time and never next to your own drive: two `drive.sh` runs share `.cache/drive/`.

Change an expected result only when there is evidence that the contract changed, never because the app disagrees. A known product failure stays failed.

A step that needs data the baseline lacks gets that data created first, from the project's own APIs, endpoints or documented setup inside the owned environment. "Missing from the seed" is not a reason to block. A step is blocked only when the prerequisite would need a service that is not owned or approved, or setup the project does not have. Name the missing prerequisite and what was tried, and add it to the map.

Every selected feature ends with a result: pass, fail, partial or blocked. Never leave one unattempted. If Doctor fails because of a helper defect, correct it and retry once before reporting the blocker. When a healthy-looking app is wedged, clean up the run's resources and relaunch.

Finish or abort through Cleanup, including when startup or a drive fails. Check that cleanup completed and evidence still exists before reporting.

## Helper briefs

Paste a brief as the helper's whole task. Replace each `[...]` with this run's values. Paths are relative to the repository root.

### Recorder

```
You are a recorder for verify-<app>. You check feature recipes against source and record them against the live app with rec.sh. The app is already running. Another agent owns its lifecycle.

Features: [3 to 5 related feature names]. New ones: [names, or none]. Convert recipes whose steps lack bash blocks: [yes or no].

Read .agents/skills/verify-<app>/features/README.md for the baseline, the driving conventions and the feature file shape, and the Drive section of .agents/skills/verify-<app>/SKILL.md. Drive only with <driver>. You may call .agents/skills/verify-<app>/bin/rec.sh and [the driver helpers, such as bin/pw.sh]. Never call launch.sh, cleanup.sh or doctor.sh. Never edit helpers, SKILL.md, features/README.md, product code, or tracked files other than your features' files.

rec.sh: rec.sh <feature> start | pre '<command>' | step '<Label>' '<command>' | say '<Label>' '<sentence>' | undo | show | finish | finish --tool '<tool>'. It runs each command the way drive.sh does, with VERIFY_SESSION=<feature>, and keeps it only when it exits 0. Steps are recorded in order; say also takes Preconditions.

For each feature:
1. Learn its contract: what it should do, from [contract sources: the project's tests, docs, specs, request text]. Read source only for that and for drift, and only for your features.
2. When a feature is not new, matches its contract and source, and needs no conversion, change nothing.
3. Otherwise record its recipe. Look at the app with VERIFY_SESSION=<feature> set, for example VERIFY_SESSION=<feature> .agents/skills/verify-<app>/bin/pw.sh snapshot for a web UI. Every command that changes the app goes through rec.sh. Start with rec.sh <feature> start. Replay unchanged steps' commands and sentences as they are, and record new commands only for new or drifted steps. To convert, record each step's commands without changing what the step checks: add a check where a step only printed a value, and where a step relied on the pause between agent turns, wait for the observable state it needs. Data the baseline lacks is created in Preconditions with the project's own APIs or documented setup. Use names no other feature uses. The last step is Clean up and removes what the recipe created. End with rec.sh <feature> finish, adding --tool '[the tool named in the Driving headings]' when the file does not exist yet.
4. Write or update the file's other sections yourself: the H1, the paragraph, Sub-features, How to get to it (user POV) and Gotchas.

Change an expected result only when the contract changed. When the app does not do what the contract says, never record a check that accepts it: record the other steps and report the difference. Stop when your features are done. If you cannot finish one, remove what your commands created in the app and report the steps you did record and the blocker.

Return only this report:
- Files: each feature file you wrote or changed, with one line on what changed, or "no drift".
- Differences: each expected result the app does not meet, with its contract source and what the app did (output or evidence path).
- Names: every account, fixture and resource name your recipes create.
- Blocked: each feature you could not finish, the steps you recorded, what blocks it (for example a helper that needs a change) and what you tried.
```

### Fixer

```
You are a fixer for verify-<app>. One recipe failed a drive. Feature: [feature]. Failing step: [label]. Log: [log path].

Read the log, the feature's file in .agents/skills/verify-<app>/features/, .agents/skills/verify-<app>/features/README.md, and the Drive and When a drive fails sections of .agents/skills/verify-<app>/SKILL.md. Classify the failure as one of the four kinds there. Read the contract ([contract sources]) only when the kind depends on it. Drive only with <driver>. You may call .agents/skills/verify-<app>/bin/rec.sh, .agents/skills/verify-<app>/bin/drive.sh and [the driver helpers]. Never call launch.sh, cleanup.sh or doctor.sh. Never edit helpers, SKILL.md, features/README.md, product code, or tracked files other than this feature's file.

rec.sh: rec.sh <feature> start | pre '<command>' | step '<Label>' '<command>' | say '<Label>' '<sentence>' | undo | show | finish. It runs each command the way drive.sh does and keeps it only when it exits 0.

When the recipe is wrong, re-record it: rec.sh <feature> start, replay the steps before the failing one as they are, record the corrected step without changing what it checks, replay the rest, then finish. Missing data goes into Preconditions, created with the project's own APIs or documented setup. A product defect or an uncertain expectation changes nothing. A helper defect or an unhealthy environment changes nothing: name it. After a repair, run .agents/skills/verify-<app>/bin/drive.sh <feature> twice in a row.

Return one line: <feature>: <kind>: <what you changed, or what is wrong and where>; drive: pass, fail at "<step>", or not run.
```

## Ship

Follow the repository's branch, commit and PR conventions as you edit. Keep all corrections in one branch and PR. Re-read the files you changed yourself before shipping. Report the outcome separately from the step results:

- **clean:** every selected feature has a result and there were no corrections. No PR needed. This does not mean every product check passed.
- **changed:** every selected feature has a result and corrections shipped in one PR.
- **incomplete:** cleanup failed, corrections could not ship safely, or selected features have no result or are blocked. Name each such feature and why.

Put the report in the final message. Name the mode and summarize additions, removals, corrections, unresolved expectations and helper problems.

- **Map only:** say `Source-reviewed; no live drives run`.
- **Changed recipes:** list each selected feature with the map change that selected it. Say how many features were not driven. If none qualified, say no drives were needed.
- **Full audit:** report every feature.

Give each selected feature's result. Name every feature that did not pass, with the step and its reason: blocked (what was tried), failed or partial. Follow `verify-<app>`'s Report section for omissions, evidence links, classified findings and the cleanup result. When `usage-report` is on `PATH`, end the report with the output of `usage-report --cwd <repository> --since <today>`, with the repository's absolute path and today's date as `YYYY-MM-DD`.

Keep working notes under `.agents/skills/verify-<app>/.cache/`, never in tracked files. Remove them during cleanup; the evidence stays.
