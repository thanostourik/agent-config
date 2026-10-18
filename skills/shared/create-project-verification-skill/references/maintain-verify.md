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
- A **recorder** takes one feature. It checks the feature against source and, when the recipe needs it, records it against the live app with `bin/rec.sh`. A recorder's conversation grows with every feature it records, and every step re-reads that conversation, so features share a recorder only when they share setup that is expensive to learn, such as a multi-step login or a fixture set, and then at most three. Recorders work in the modes that drive.
- A **fixer** takes one feature that failed a drive, repairs its recipe and drives it again.

Start recorders and fixers with the briefs under Helper briefs. Without a subagent tool, do the same work yourself, one feature at a time, still through `bin/rec.sh`.

## Edit scope

In map-only mode, edit only the feature files and index. Report helper or lifecycle problems without trying a live repair. In modes that drive, recorders and fixers edit only their own feature files. You edit the index, `verify-<app>/SKILL.md`, its helpers other than `drive.sh`, `steps.sh` and `rec.sh`, and its Claude Code stub. Never edit product code.

## Update the map

Before editing, record the starting map and driving conventions so selection includes every change in this pass, even ones already committed during it. When the global maintenance skill invokes you, use its record from before conformance and its list of the features `bin/drive.sh --check` refused.

1. **Index.** Read `features/README.md` and list its sibling files. Fix missing and duplicate entries. An entry is dead when the app no longer has its feature: remove it. An entry whose file a recorder has not written yet is not dead. Inspect routes, navigation, commands and endpoints for features the index lacks: a list, not a read of every component. Add an entry for each. Name a new feature after what the user does or sees, in kebab-case like the existing files. Its index line gives its name and a one-line scope, so every recorder starts from both. Scopes never overlap: when two index lines name the same behavior, narrow one of them. A feature's Driving section holds at most about 15 steps, `Clean up` included, because a recorder's cost and context grow with every step it records. A feature that needs more is several features: split it by groups of sub-features into separate files, each with its own index line and change triggers, and each recorded by its own recorder from a fresh context. Update `## Change triggers` from the source: add the triggers of new features, remove those of removed features, and correct those of features whose source moved. Check that the two Claude Code stubs still match the real skills' `name` and `description`.
2. **Map only: read.** Readers cover every feature in small batches of related features. Return shape: feature summary / source entry points / likely drift or none / proposed recipe. Without subagents, read the groups yourself. Spot-check cited drift and update the files and index. Require concrete source evidence for additions and removals. Preserve expected behavior supported by a request, documented contract or established test. Current code alone does not prove a conflicting expectation is obsolete. Report possible product defects and unresolved expectations instead of writing them into the map as normal behavior. Each recipe keeps its exact setup and fixture cleanup so it runs from the baseline.
3. **Modes that drive: record.** Follow `verify-<app>`'s Isolation, Launch and Doctor sections. Then give every feature to a recorder, all on that one environment. Run as many recorders at a time as the `--jobs` value in `verify-<app>`'s Drive section. Each feature keeps its own `VERIFY_SESSION`, so recorders work side by side like `drive.sh --jobs`. A project where editing a tracked file disturbs the running app, for example a dev server that reloads every open page when a file changes, records one feature at a time: one recorder's `rec.sh finish` would wipe another recorder's browser state. Features that change state other features read, such as global settings, go to a recorder that starts after the others return. Tell recorders to convert in a full audit and for the refused features on that list. In each brief, list the driving-convention changes since the starting record. Read only the reports:
   - Compare the Names lists. When two features create the same account, fixture or resource name, send one of them back to a recorder to rename it.
   - Make the helper changes that reports name as blockers yourself. A missing dependency or setup step that the project documents is yours to fix as well, inside the owned environment. Then send each blocked feature back to a recorder. A prerequisite the project does not document stays blocked: report it.
   - Correct the index entries and change triggers of the features that reports name as changed or blocked.
   - For each proposed feature on a report's Split line, add an index line and change triggers, narrow the split feature's own index line and triggers to the sub-features its file now holds, and give the proposed feature to a new recorder as a new feature.
   - Report each Difference as a possible product defect or unresolved expectation.

## Select what to drive

- **Map only:** go to Ship. No drives.
- **Changed recipes:** select each feature that the recorders' Files lists name as new, or as having a step that is new or whose action, command, expected result, proof or cleanup changed meaningfully. If the baseline or the driving conventions changed since the recorded starting point, select every feature that change affects. Select the refused features the global maintenance skill listed. Wording, formatting, index repairs, unchanged renames and deletions select nothing. If nothing qualifies, run Cleanup and go to Ship.
- **Full audit:** every feature.

`bin/drive.sh --check [feature...]` finds the recipes that need conversion. It launches nothing and names each step that has no `bash` block or calls `launch.sh`, `cleanup.sh` or `doctor.sh`. A selected feature it names goes to a recorder to be converted before the drive; `drive.sh` refuses to run it otherwise. Unselected recipes stay as they are.

Do not treat unselected features as verified.

## Drive the selected features

Follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, When a drive fails, Evidence and Cleanup sections. They set the driver, the isolation level, the deadlines and the failure rules.

Drive from a fresh environment, not from the state the recorders left. Commit the map changes after the recorders return and before this fresh launch, because some Doctors compare the launched revision with `HEAD`; `verify-<app>`'s Doctor section says when this one does. Then run `bin/cleanup.sh`, launch again with `bin/launch.sh` and run `bin/doctor.sh`. Then drive all selected features in one `bin/drive.sh` call. Send each failing feature to a fresh fixer with the feature name, the failing step and its log path, and read only the line it returns. A feature that fails only at a known product failure, a step that a recorder's Differences or a fixer's line names, needs no fixer. Run one fixer at a time and never beside your own drive: two `drive.sh` runs share `.cache/drive/`, and the fixer drives its feature twice after a repair. When the fixers are done, drive all selected features once more without relaunching. That proves each `Clean up` step leaves the app ready for the next run. This second summary and the fixers' lines are the record of the pass. A feature that fails the second drive at any other step goes back to a fixer, and then the second drive is repeated.

After an aborted run, clean up its recorded leftovers, create a new environment, drive the features without a result and keep the evidence.

Change an expected result only when there is evidence that the contract changed, never because the app disagrees. A known product failure stays failed.

A step that needs data the baseline lacks gets that data created first, from the project's own APIs, endpoints or documented setup inside the owned environment. "Missing from the seed" is not a reason to block. A step is blocked only when the prerequisite would need a service that is not owned or approved, or setup the project does not have. Name the missing prerequisite and what was tried, and add it to the map.

Every selected feature ends with a result: pass, fail, partial or blocked. Never leave one unattempted. If Doctor fails because of a helper defect, correct it and retry once before reporting the blocker. When a healthy-looking app is wedged, clean up the run's resources and relaunch.

Finish or abort through Cleanup, including when startup or a drive fails. Check that cleanup completed and evidence still exists before reporting.

## Helper briefs

Paste a brief as the helper's whole task. Replace each `[...]` with this run's values. Paths are relative to the repository root.

### Recorder

```
You are a recorder for verify-<app>. You check feature recipes against source and record them against the live app with rec.sh. The app is already running. Another agent owns its lifecycle.

Repository root: [absolute path]; run everything from there.

Features: [one feature name, or up to three that share expensive setup]. New ones: [names, or none]. Convert recipes whose steps lack bash blocks: [yes or no].
Conventions changed in this pass: [list, or none].

Read .agents/skills/verify-<app>/features/README.md for the baseline, the driving conventions and the feature file shape, and the Drive section of .agents/skills/verify-<app>/SKILL.md. Drive only with <driver>. You may call .agents/skills/verify-<app>/bin/rec.sh and [the driver helpers, such as bin/pw.sh]. Before you finish, you may run .agents/skills/verify-<app>/bin/drive.sh --check <feature> on your own features: it only reads their recipes and launches nothing. Never run drive.sh without --check. Never call launch.sh, cleanup.sh or doctor.sh. Never edit helpers, SKILL.md, features/README.md or product code. Do not commit or push; the main agent ships. Write no tracked file other than your features' files.

rec.sh: rec.sh <feature> start | pre '<command>' | step '<Label>' '<command>' | step --keep '<Label>' '<command>' | say '<Label>' '<sentence>' | undo | show | finish | finish --tool '<tool>'. It runs each command the way drive.sh does, with VERIFY_SESSION=<feature>, and keeps it only when it exits 0; step --keep keeps it even when it fails. finish refuses a failing command kept with --keep anywhere but as the last command of the last step before Clean up; show marks that step (known failure). Steps are recorded in order; say also takes Preconditions.

For each feature:
1. Learn its contract: what it should do, from [contract sources: README, docs, specs, tests, and the request text when this pass has one]. List every behavior those sources name for the feature: each test case, README sentence, plan acceptance line and entry point. Read source only for that and for drift, and only for your features.
2. When a feature is not new, matches its contract and source, has a step for every behavior on that list, breaks none of the changed conventions, and needs no conversion, change nothing. A recipe that misses a listed behavior or breaks a changed convention has drifted: re-record it.
3. Otherwise record its recipe. Explore freely with a throwaway account or session. The recording starts from a fresh account or session with rec.sh <feature> start, and from then on every state-changing command of the recipe goes through rec.sh. rec.sh undo drops a command from the recording but cannot roll back what it did to the app: after an undo, start again when the undone command changed the app. Look at the app after your Preconditions commands have run, with VERIFY_SESSION=<feature> set, for example with an accessibility snapshot through <driver>. Replay unchanged steps' commands and sentences as they are, and record new commands only for new or drifted steps. To convert, record each step's commands without changing what the step checks: add a check where a step only printed a value, and where a step relied on the pause between agent turns, wait for the observable state it needs. Data the baseline lacks is created in Preconditions with the project's own APIs or documented setup. Use names no other feature uses. End with rec.sh <feature> finish, adding --tool '[the driver for this feature's surface; both when a recipe uses two, for example 'curl and Playwright CLI']' when the file does not exist yet.
4. Write or update the file's other sections yourself: the H1, the paragraph, Sub-features, How to get to it (user POV) and Gotchas.

Every recipe follows these rules:
- Every behavior on the contract list gets a step. So does every sub-feature line and every entry point you write in the file, or it goes under Blocked with the reason.
- The feature's index line in features/README.md bounds it: a step belongs to the feature whose index line names the behavior. A behavior another feature's index line names stays off your contract list and is not tested again here. When the recipe needs it, it is setup, done in the fewest commands and with no check beyond what the recipe's own steps need. Report a behavior that fits no index line under Split or Blocked instead of testing it in passing.
- A step is one user action and its observable result, in one or two short sentences. Split a step that proves several results.
- The Driving section holds at most about 15 steps, Clean up included. When a feature needs more, record the first coherent group of sub-features in this file, list only those under Sub-features, name the remaining groups under Split in your report, and stop there: the main agent adds their index lines and sends each to a new recorder. Behaviors you leave to those groups go under Split, not Blocked.
- Wait for the observable state with the project's wait helpers or the driver's own waits. Never put sleep or a fixed timeout in place of a condition. A contract that states a time, such as "expires after 2.5 s" or "autosaves about 400 ms after the last keystroke", is checked with a wait bounded to that time plus a small margin, never with a helper's default deadline.
- The step that proves the feature's main result saves evidence under .agents/skills/verify-<app>/.cache/evidence/<feature>/, as features/README.md says: a screenshot or accessibility snapshot for a UI, the response body or command output otherwise.
- The last step is Clean up. It removes what the recipe created and ends with a check that the recipe's fixtures and sessions are gone. Put || true only on a command whose failure cannot matter, such as a delete that the final check covers.
- Change an expected result only when the contract changed. When the app does not do what the contract says, record the check anyway with rec.sh <feature> step --keep, as the last step before Clean up, so a drive still proves the rest. Any setup it needs happens inside that step, so it sits directly after the proof step and before Clean up, with nothing in between. drive.sh stops at the first failing step, so that one step carries all of the feature's known failures, in one command that runs every check and fails at the end. Write the contract in that step's sentence and report the difference. Never weaken the check, drop it or move it to Gotchas.

Stop when your features are done. If you cannot finish one, remove what your commands created in the app and report the steps you did record and the blocker.

Return only this report:
- Files: each feature file you wrote or changed, with one line on what changed, or "no drift".
- Differences: each expected result the app does not meet, with its contract source, what the app did (output or evidence path) and the step that carries it.
- Names: every account, fixture and resource name your recipes create.
- Split: [proposed feature name: sub-features it would hold], one line per remaining group of each feature you split, or none.
- Blocked: each feature you could not finish and each sub-feature or entry point you could not drive, the steps you recorded, what blocks it (for example a helper that needs a change) and what you tried.
```

### Fixer

```
You are a fixer for verify-<app>. One recipe failed a drive. Feature: [feature]. Failing step: [label]. Log: [log path].

Repository root: [absolute path]; run everything from there.

Read the log, the feature's file in .agents/skills/verify-<app>/features/, .agents/skills/verify-<app>/features/README.md, and the Drive and When a drive fails sections of .agents/skills/verify-<app>/SKILL.md. Classify the failure as one of the four kinds there. Read the contract ([contract sources]) only when the kind depends on it. Drive only with <driver>. You may call .agents/skills/verify-<app>/bin/rec.sh, .agents/skills/verify-<app>/bin/drive.sh and [the driver helpers]. Never call launch.sh, cleanup.sh or doctor.sh. Never edit helpers, SKILL.md, features/README.md or product code. Do not commit or push; the main agent ships. Write no tracked file other than this feature's file.

rec.sh: rec.sh <feature> start | pre '<command>' | step '<Label>' '<command>' | step --keep '<Label>' '<command>' | say '<Label>' '<sentence>' | undo | show | finish. It runs each command the way drive.sh does and keeps it only when it exits 0; step --keep keeps it even when it fails. finish refuses a failing command kept with --keep anywhere but as the last command of the last step before Clean up.

When the recipe is wrong, re-record it: rec.sh <feature> start, replay the steps before the failing one as they are, record the corrected step without changing what it checks, replay the rest, then finish. Replay a step that carries a known product failure, one whose sentence states a contract the app does not meet, with step --keep. Missing data goes into Preconditions, created with the project's own APIs or documented setup. A product defect or an uncertain expectation changes nothing. A helper defect or an unhealthy environment changes nothing: name it. After a repair, run .agents/skills/verify-<app>/bin/drive.sh <feature> twice in a row.

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

Give each selected feature's result. Name every feature that did not pass, with the step and its reason: blocked (what was tried), failed or partial. List each known product failure with its feature, the step that carries it and the contract it misses. Follow `verify-<app>`'s Report section for omissions, evidence links, classified findings and the cleanup result. When `usage-report` is on `PATH`, end the report with the output of `usage-report --cwd <repository> --since <today>`, with the repository's absolute path and today's date as `YYYY-MM-DD`.

Keep working notes under `.agents/skills/verify-<app>/.cache/`, never in tracked files. Remove them during cleanup; the evidence stays.
