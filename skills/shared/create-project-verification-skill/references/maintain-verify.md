---
name: maintain-verify-<app>
description: "Maintain the verify-<app> feature map and drive new and changed recipes. Use /maintain-verify-<app>, map only for source-only updates, or full audit to drive every feature."
disable-model-invocation: true
---

The user explicitly requests <driver> for every step of this skill, including runs you start yourself. Do not use the host's integrated browser, preview or computer-use tools. If the driver breaks, repair it or report a blocker; do not switch drivers. The one exception is a step that needs the user watching, such as a manual login: ask first, then return to the driver.

# Maintain verify-<app>

A feature map rots the moment the app changes. Each change updates its own features' entries as part of `verify-<app>`. Maintenance catches what those updates missed.

## Choose the mode

- **Changed recipes (default):** `/maintain-verify-<app>` launches the app, checks every feature against source, rewrites and reruns the recipes that drifted, then drives only the features with new or meaningfully changed steps. A step is one labeled bullet under `Driving it with <tool>`.
- **Map only:** `/maintain-verify-<app> map only` updates the map from source without launching or driving the app. Report the edits as source-reviewed, not live-verified.
- **Full audit:** `/maintain-verify-<app> full audit`, or an explicit request to drive all features, updates the map, converts every recipe whose steps lack `bash` blocks, and drives every feature, including unchanged ones.

When `verify-<app>`'s Isolation section says `checks-only`, every mode runs as map only: no recipe is converted, and every feature is reported `blocked: no isolation`.

Honor an explicit source-only or drive-all request. Do not escalate to a full audit because many files changed. In map-only mode, record any uncertainty for a later drive.

Messages you post anyway may carry progress lines such as `read 2/5: search, theme — 1 wrong step`. Never change how you split, delegate or order work to produce them, and never add a turn just to report.

## Helpers

Helper agents do the reading and recording, so your own context stays small. Read only what they return. Never open a feature file a helper wrote in this pass.

- A **reader** reads source for a small group of related features and proposes edits. It edits nothing. Readers work in map-only mode.
- A **recorder** takes one feature. It checks the feature against its contract and source and, when the recipe needs it, writes the whole feature file into a staged copy under `.cache/record/<feature>/` and runs it against the live app with `bin/rec.sh <feature> run`. It never writes a tracked file. Recorders work in the modes that drive.
- A **fixer** takes one feature that failed a drive, repairs its recipe in a staged copy and runs that copy with `bin/rec.sh <feature> run`.

Start recorders and fixers with the briefs under Helper briefs. Without a subagent tool, do the same work yourself, one feature at a time, still through `bin/rec.sh`.

## Edit scope

In map-only mode, edit only the feature files and index. Report helper or lifecycle problems without trying a live repair. In modes that drive, recorders and fixers edit only the staged copies of their own feature files, and you move them into `features/` with `bin/rec.sh install`. You edit the index, `verify-<app>/SKILL.md`, its helpers other than `drive.sh`, `steps.sh` and `rec.sh`, and its Claude Code stub. Never edit product code.

## Update the map

Start with one command that prints `verify-<app>/SKILL.md`, `features/README.md` and the two Claude Code stubs' frontmatter, lists the feature files, and copies `features/README.md` to `.agents/skills/verify-<app>/.cache/starting-README.md`. That is your only read of those files in this pass. The copy is the starting record of the map and driving conventions, so selection includes every change in this pass, even ones already committed during it. When the global maintenance skill invokes you, it made that copy before conformance: leave the copy out of your command, and take its list of the features `bin/drive.sh --check` refused.

1. **Index**, two commands. One grep over routes, navigation, commands and endpoints lists the candidate features: a list, not a read of every component. Then one edit of `features/README.md` makes every change below. Fix missing and duplicate entries. An entry is dead when the app no longer has its feature: remove it. An entry whose file a recorder has not written yet is not dead. Add an entry for each candidate feature the index lacks. Name a new feature after what the user does or sees, in kebab-case like the existing files. Its index line gives its name and a one-line scope, so every recorder starts from both. Scopes never overlap: when two index lines name the same behavior, narrow one of them. A feature's Driving section holds at most about 15 steps, `Clean up` included, because a recorder's cost and context grow with every step it writes and repairs. A feature that needs more is several features: split it by groups of sub-features into separate files, each with its own index line and change triggers, and each recorded by its own recorder from a fresh context. Update `## Change triggers` from the source: add the triggers of new features, remove those of removed features, and correct those of features whose source moved. Check that the two Claude Code stubs still match the real skills' `name` and `description`.
2. **Map only: read.** Readers cover every feature in small batches of related features. Return shape: feature summary / source entry points / likely drift or none / proposed recipe. Without subagents, read the groups yourself. Spot-check cited drift and update the files and index. Require concrete source evidence for additions and removals. Preserve expected behavior supported by a request, documented contract or established test. Current code alone does not prove a conflicting expectation is obsolete. Report possible product defects and unresolved expectations instead of writing them into the map as normal behavior. Each recipe keeps its exact setup and fixture cleanup so it runs from the baseline.
3. **Modes that drive: record.** Follow `verify-<app>`'s Isolation, Launch and Doctor sections. Then look at the app once, the way a recipe would, before any recorder starts: run the Baseline's sign-in or open command with `VERIFY_SESSION=main`, take one accessibility snapshot of the main screen into `.agents/skills/verify-<app>/.cache/record/main-screen.txt` and close that session, in one command. For Playwright CLI the snapshot is `pw.sh snapshot --filename=<that path>`; for an API, one `curl` of the index or the OpenAPI document; for a CLI, its `--help`. Right after it, write `.agents/skills/verify-<app>/.cache/record/brief-common.md`, the part of the brief that is the same for every recorder, in one command that copies it out of the project's files in the shape under Common brief file, so you type none of it out and never read it. Before a later wave, run that command again when the index or a helper changed. Then give every feature to a recorder, all on that one environment, and start every recorder in one turn. The `--jobs` value in `verify-<app>`'s Drive section is `drive.sh`'s and does not limit recorders. When the app cannot take every recorder at once, this step states a recorder cap, and you start waves of that size instead. Then do nothing until every recorder of the wave has returned: no turn spent waiting, no `date`, no narration. Act on the reports, then start the next wave with the features going back to a recorder and, under a cap, the next features. A progress line, if you post one, is per wave, for example `recorded 16/16`. Each feature keeps its own `VERIFY_SESSION`, so recorders work side by side like `drive.sh --jobs`. Recorders never write tracked files, so they run in parallel in every project. Features that change state other features read, such as global settings, record one at a time after the others return. A project whose Drive section uses `--jobs 1` because features cannot be kept apart records one feature at a time as well. Tell recorders to convert in a full audit and for the refused features on that list. In each brief, give the feature's index line and contract files and list the driving-convention changes since the starting record. Read only the reports:
   - Two features' fixtures clash only when they share a namespace. When the Baseline gives each recipe its own account or data namespace, there are no clashes to check. Otherwise compare the Names lists: when two features create the same account, fixture or resource name, send one of them back to a recorder to rename it.
   - Make the helper changes that reports name as blockers yourself. A missing dependency or setup step that the project documents is yours to fix as well, inside the owned environment. Then send each blocked feature back to a recorder. A prerequisite the project does not document stays blocked: report it.
   - Correct the index entries and change triggers of the features that reports name as changed or blocked.
   - For each proposed feature on a report's Split line, add an index line and change triggers, narrow the split feature's own index line and triggers to the sub-features its file now holds, and give the proposed feature to a new recorder as a new feature.
   - Report each Difference as a possible product defect or unresolved expectation.

   When every recorder has returned and none goes back to one, run `bin/rec.sh install`. It moves the staged feature files that passed `rec.sh run` into `features/`, names any it skipped, and runs `drive.sh --check` on the ones it moved.

## Select what to drive

- **Map only:** go to Ship. No drives.
- **Changed recipes:** select each feature that the recorders' Files lists name as new, or as having a step that is new or whose action, command, expected result, proof or cleanup changed meaningfully. If the baseline or the driving conventions changed since the recorded starting point, select every feature that change affects. Select the refused features the global maintenance skill listed. Wording, formatting, index repairs, unchanged renames and deletions select nothing. If nothing qualifies, run Cleanup and go to Ship.
- **Full audit:** every feature.

`bin/drive.sh --check [feature...]` finds the recipes that need conversion. It launches nothing and names each step that has no `bash` block or calls `launch.sh`, `cleanup.sh` or `doctor.sh`. A selected feature it names goes to a recorder to be converted before the drive; `drive.sh` refuses to run it otherwise. Unselected recipes stay as they are. At `checks-only`, recipes have no `bash` blocks by design, so this check converts nothing.

Do not treat unselected features as verified.

## Drive the selected features

Follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, When a drive fails, Evidence and Cleanup sections. They set the driver, the isolation level, the deadlines and the failure rules.

Drive from a fresh environment, not from the state the recorders left. Commit the map changes after `bin/rec.sh install` and before this fresh launch, because some Doctors compare the launched revision with `HEAD`; `verify-<app>`'s Doctor section says when this one does. Then run `bin/cleanup.sh`, launch again with `bin/launch.sh` and run `bin/doctor.sh`. Then drive all selected features in one `bin/drive.sh` call, started in the background, and do nothing until it finishes: no tailing, no counting lines. Read its summary once. Send each failing feature to a fresh fixer with the feature name, the failing step and its log path, and read only the line it returns. A feature that fails only at a known product failure, a step that a recorder's Differences or a fixer's line names, needs no fixer. Start every fixer in one turn, or in waves of the recorder cap when Update the map states one, and never beside your own drive. Fixers of features that change state other features read run one at a time after the other fixers return, and a project that records one feature at a time fixes one at a time as well. When the fixers are done, run `bin/rec.sh install` for the features they repaired, then drive only those features once, the same way. That summary, the first one and the fixers' lines are the record of the pass. The report's evidence links come from the last summary of each feature and one `ls -R .agents/skills/verify-<app>/.cache/evidence/`, which lists the saved proof and the step logs.

After an aborted run, clean up its recorded leftovers, create a new environment, drive the features without a result and keep the evidence.

Change an expected result only when there is evidence that the contract changed, never because the app disagrees. A known product failure stays failed.

A step that needs data the baseline lacks gets that data created first, from the project's own APIs, endpoints or documented setup inside the owned environment. "Missing from the seed" is not a reason to block. A step is blocked only when the prerequisite would need a service that is not owned or approved, or setup the project does not have. Name the missing prerequisite and what was tried, and add it to the map.

Every selected feature ends with a result: pass, fail, partial or blocked. Never leave one unattempted. If Doctor fails because of a helper defect, correct it and retry once before reporting the blocker. When a healthy-looking app is wedged, clean up the run's resources and relaunch.

Finish or abort through Cleanup, including when startup or a drive fails. Check that cleanup completed and evidence still exists before reporting.

## Helper briefs

Paste a recorder or fixer brief as the helper's whole task. Replace each `[...]` with this run's values. Paths are relative to the repository root. Both briefs send the helper to the common brief file first.

### Common brief file

The command in Update the map step 3 writes this file from the project's files. Each `[...]` is the content it names, copied as it is.

```
# Common brief for verify-<app> recorders and fixers

## From .agents/skills/verify-<app>/features/README.md

[its Baseline, Driving conventions and Feature file shape sections, then its whole feature index, every index line]

## Helpers, from .agents/skills/verify-<app>/SKILL.md; call them by name, they are on PATH inside a run

[the Helpers section of verify-<app>/SKILL.md, each helper with one call as it appears in a recipe]

## Example recipe, from this project

[the shortest feature file in .agents/skills/verify-<app>/features/ that bin/drive.sh --check accepts]

## The app's main screen, as an accessibility snapshot taken after the baseline sign-in

[.agents/skills/verify-<app>/.cache/record/main-screen.txt]
```

When no feature file passes `bin/drive.sh --check` yet, leave out the Example recipe section, so the Feature file shape stands alone, until a staged feature file has passed `rec.sh run`. From then on the section holds the first such file, and you write the common file again before the next wave.

### Recorder

```
You are a recorder for verify-<app>. You check one feature's recipe against its contract and source, write the whole feature file, and run it against the live app with rec.sh. The app is already running. Another agent owns its lifecycle.

Repository root: [absolute path]; run every command from there. rec.sh is .agents/skills/verify-<app>/bin/rec.sh.
Feature: [name]. Index line: [the feature's line from the index in features/README.md]. New: [yes or no]. Convert a recipe whose steps lack bash blocks: [yes or no].
Contract files: [paths of the README, docs, specs, tests and plans that say what this feature should do, and the request text when this pass has one].
Conventions changed in this pass: [list, or none].

Read .agents/skills/verify-<app>/.cache/record/brief-common.md first, in the same command as the contract files. It holds the Baseline, Driving conventions, Feature file shape and whole feature index from features/README.md, the helpers with one call each, an example recipe once the project has one and an accessibility snapshot of the app's main screen.

This brief and that file are all you need: read no skill file, no other recipe and no helper script. Use the helpers the way the example recipe and the helper list show, and copy the example's Preconditions, evidence and Clean up idioms. Take element names and texts from the main-screen snapshot and the example recipe, not from guesses out of source. Drive only with <driver>. You may call rec.sh <feature> start, rec.sh <feature> run and the helpers in that file. Never run drive.sh or rec.sh install. Never call launch.sh, cleanup.sh or doctor.sh. Never edit helpers, SKILL.md, features/README.md or product code. Write no tracked file: write only the staged copy that rec.sh <feature> start names, never under features/. Do not commit or push; the main agent installs your file and ships.

Work in these steps. Each takes the tool calls it names; put commands that belong together in one call. Do not click around the app to learn it: the run is the attempt. Do not narrate: the report is your only text.
1. Contract, one command: print the common brief file, every contract file and, when there is one, the existing feature file .agents/skills/verify-<app>/features/<feature>.md. List every behavior the contract names for the feature: each test case, README sentence, plan acceptance line and entry point.
2. Source, one command: one grep over the feature's source files for the routes and names the steps target, such as route paths, test ids, command names and the labels of screens the main-screen snapshot does not show, or for drift. This is your only source read; after it, the runs tell you what to fix.
3. Write, one or two calls. When the feature is not new, matches its contract and source, has a step for every behavior on the list, breaks none of the changed conventions and needs no conversion, change nothing and go to the report. Otherwise run rec.sh <feature> start and write the complete feature file, every section, in one write at the path it prints, which is always .agents/skills/verify-<app>/.cache/record/<feature>/<feature>.md, so one call can do both. Name the driver in the Driving heading, both when the recipe uses two, for example "## Driving it with curl and Playwright CLI". Keep unchanged steps as they are. To convert, give each step one block without changing what it checks: add a check where a step only printed a value, and where a step relied on the pause between agent turns, wait for the observable state it needs. Data the baseline lacks is created in Preconditions with the project's own APIs or documented setup. Use names no other feature uses, unless the Baseline gives each recipe its own account or data namespace, which keeps names apart already.
4. Run, one call per attempt: rec.sh <feature> run. It empties .agents/skills/verify-<app>/.cache/evidence/<feature>/, then runs Preconditions and every step in order the way drive.sh does, with VERIFY_SESSION=<feature> and the shell variables and functions of the steps before, and prints one pass line per step. At the first failing step it prints that step's commands, each before its output, and its exit code, then runs Clean up. Fix that step in the staged file and run again. Take your own snapshot only of a screen that is not the main one, when a failure leaves you unsure of a label there. Clean up has closed the session by then, so put the snapshot command into the failing step, before the command that failed, saving to a file under .agents/skills/verify-<app>/.cache/record/<feature>/; run again and grep that file in the same call, then remove the snapshot command. Never print a whole snapshot. The recipe is done when rec.sh prints "passed".
5. Report.

Every recipe follows these rules:
- Every behavior on the contract list gets a step. So does every sub-feature line and every entry point you write in the file, or it goes under Blocked with the reason. A test case names a behavior to drive through the app; a recipe never runs the project's own tests or build.
- The feature's index line bounds it: a step belongs to the feature whose index line names the behavior. The other features' index lines are in the common brief file. A behavior another feature's index line names stays off your contract list and is not tested again here. When the recipe needs it, it is setup, done in the fewest commands and with no check beyond what the recipe's own steps need. Report a behavior that fits no index line under Split or Blocked instead of testing it in passing.
- A step is one user action and its observable result, in one or two short sentences. Split a step that proves several results.
- The Driving section holds at most about 15 steps, Clean up included. When a feature needs more, write the first coherent group of sub-features in this file, list only those under Sub-features, name the remaining groups under Split in your report, and stop there: the main agent adds their index lines and sends each to a new recorder. Behaviors you leave to those groups go under Split, not Blocked.
- Wait for the observable state with the project's wait helpers or the driver's own waits. Never put sleep or a fixed timeout in place of a condition. A contract that states a time, such as "expires after 2.5 s" or "autosaves about 400 ms after the last keystroke", is checked with a wait bounded to that time plus a small margin, never with a helper's default deadline.
- The step that proves the feature's main result saves evidence under .agents/skills/verify-<app>/.cache/evidence/<feature>/: a screenshot or accessibility snapshot for a UI, the response body or command output otherwise.
- The last step is Clean up. It removes what the recipe created and closes its sessions. When the project has a way to check that, it ends with that check. The example recipe shows the project's Clean up idiom and is the pattern to copy. Put || true only on a command whose failure cannot matter, such as a delete that the check after it covers.
- Change an expected result only when the contract changed. When the app does not do what the contract says, keep the check as the last step before Clean up and run rec.sh <feature> run --known-failure '<Label>', so a drive still proves the rest. rec.sh refuses the flag on any other step and fails when that step passes. Any setup the step needs happens inside it, so it sits directly after the proof step and before Clean up, with nothing in between. drive.sh stops at the first failing step, so that one step carries all of the feature's known failures, in one block that runs every check and fails at the end. Write the contract in that step's sentence and report the difference. Never weaken the check, drop it or move it to Gotchas.

If you cannot finish, rec.sh run has already run Clean up after the failing step; remove anything else your commands created in the app, and report the steps that pass and the blocker.

Return only this report:
- Files: the staged file with one line on what changed and the last rec.sh run result (passed, or passed with the known failure at "<Label>"), or "no drift".
- Run attempts: <n>, the number of rec.sh <feature> run calls.
- Differences: each expected result the app does not meet, with its contract source, what the app did (output or evidence path) and the step that carries it.
- Names: every account, fixture and resource name your recipe creates.
- Split: [proposed feature name: sub-features it would hold], one line per remaining group, or none.
- Blocked: the feature when you could not finish it, and each sub-feature or entry point you could not drive, with the steps that pass, what blocks it (for example a helper that needs a change) and what you tried.
```

### Fixer

```
You are a fixer for verify-<app>. One recipe failed a drive. Feature: [feature]. Failing step: [label]. Log: [log path].

Repository root: [absolute path]; run every command from there. rec.sh is .agents/skills/verify-<app>/bin/rec.sh.

Read .agents/skills/verify-<app>/.cache/record/brief-common.md first, in the same command as the log, the feature's file in .agents/skills/verify-<app>/features/ and the When a drive fails section of .agents/skills/verify-<app>/SKILL.md. The common file holds the map's conventions, the helpers with one call each and a snapshot of the app's main screen. Classify the failure as one of the four kinds in When a drive fails. Read the contract ([contract sources]) only when the kind depends on it. Drive only with <driver>. You may call rec.sh <feature> start, rec.sh <feature> run and the helpers in the common file. Never run drive.sh or rec.sh install. Never call launch.sh, cleanup.sh or doctor.sh. Never edit helpers, SKILL.md, features/README.md or product code. Write no tracked file: edit only the staged copy of the feature file that rec.sh <feature> start makes. Do not commit or push; the main agent installs your file and ships.

When the recipe is wrong, run rec.sh <feature> start, fix the wrong step in the staged copy it names without changing what the step checks, and run rec.sh <feature> run. It runs the whole recipe the way drive.sh does; at the first failing step it prints that step's commands, each before its output, then runs Clean up. Fix and run again until it prints "passed". A step that carries a known product failure, one whose sentence states a contract the app does not meet, runs with --known-failure '<Label>'. Missing data goes into Preconditions, created with the project's own APIs or documented setup. To snapshot, put the snapshot command into the failing step, before the command that failed, saving to a file under .agents/skills/verify-<app>/.cache/record/<feature>/; run again, grep that file in the same call, then remove the snapshot command. Never print a whole snapshot. A product defect or an uncertain expectation changes nothing. A helper defect or an unhealthy environment changes nothing: name it.

Return one line: <feature>: <kind>: <what you changed, or what is wrong and where>; run: passed, passed with the known failure at "<step>", fail at "<step>", or not run.
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
