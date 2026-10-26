---
name: maintain-verify-<app>
description: "Maintain the verify-<app> feature map and drive new and changed recipes. Use /maintain-verify-<app>, map only for source-only updates, or full audit to drive every feature."
disable-model-invocation: true
---

The user explicitly requests <driver> for every step of this skill, including runs you start yourself. Do not use the host's integrated browser, preview or computer-use tools. If the driver breaks, repair it or report a blocker; do not switch drivers. The one exception is a step that needs the user watching, such as a manual login: ask first, then return to the driver.

# Maintain verify-<app>

Each change updates its own features' entries through `verify-<app>`; maintenance catches what those updates missed.

## Choose the mode

- **Changed recipes (default):** `/maintain-verify-<app>` launches the app, reruns the recipes of the features changed since the last pass, rewrites those that fail, then drives only the features with new or meaningfully changed steps. A step is one labeled bullet under `Driving it with <tool>`.
- **Map only:** `/maintain-verify-<app> map only` updates the map from source without launching or driving the app. Report the edits as source-reviewed, not live-verified.
- **Full audit:** `/maintain-verify-<app> full audit`, or an explicit request to drive all features, updates the map, converts every recipe written as prose, which means adding `bash` blocks to it, and drives every feature, including unchanged ones.

When `verify-<app>`'s Isolation section says `checks-only`, every mode runs as map only: no recipe is converted, and every feature is reported `blocked: no isolation`.

Honor an explicit source-only or drive-all request. Do not escalate to a full audit because many files changed. In map-only mode, record any uncertainty for a later drive.

When you send a message anyway, you may add one progress line, such as `read 2/5: search, theme — 1 wrong step`. Never send a message or reorder work just to report.

## Helpers

Helpers do the reading and recording, so your context stays small. Read only what they return, the report files Update the map step 3 names and, at Ship, `traps.md`. Never open a feature file a helper wrote in this pass.

- A **reader** reads source for a small group of related features and proposes edits. It edits nothing. Readers work in map-only mode.
- A **recorder** takes one feature and those it splits off. It writes each recipe into a **staged copy**, `.cache/record/<feature>/<feature>.md`, written whole when needed, and runs it against the live app with `bin/rec.sh <feature> run`. Its only tracked edit is an index line. Recorders work in the modes that drive.
- A **fixer** takes one feature that failed a drive, repairs its recipe in a staged copy and runs that copy with `bin/rec.sh <feature> run`.

Start recorders and fixers with the brief files and one-line prompts under Helper briefs. Without a subagent tool, do the same work yourself, one feature at a time, still through `bin/rec.sh`.

## Edit scope

In map-only mode, edit only the feature files and index. Report helper or lifecycle problems without trying a live repair. In modes that drive, helpers edit only their staged copies, which `bin/rec.sh install` moves into `features/`. You edit the index, `verify-<app>/SKILL.md`, its helpers other than `drive.sh`, `steps.sh` and `rec.sh`, and its Claude Code stub. Never edit product code.

## Update the map

Start with one command that prints `verify-<app>/SKILL.md`, `features/README.md` and the two Claude Code stubs' frontmatter, lists the feature files, and copies `features/README.md` to `.agents/skills/verify-<app>/.cache/starting-README.md`. That is your only read of those files in this pass. The copy is the starting record of the map and driving conventions, so selection sees every change of this pass, committed or not. When the global maintenance skill invokes you, it made that copy before conformance: leave the copy out of your command, and take its list of the features `bin/drive.sh --check` refused.

1. **Index**, two commands. One grep over routes, navigation, commands and endpoints lists the candidate features: a list, not a read of every component. In a companion repo, whose `verify-<app>/apps` lists the app checkouts, grep those checkouts and prefix each path with its app's name. In changed-recipes mode with `features/last-reviewed`, run `bin/rec.sh affected` first and the grep over `.cache/changed.txt` only, none when it is empty. From then on, every feature means the affected ones it prints, the grep's new ones and the listed refused ones; with none, go to Ship. Then one edit of `features/README.md` makes every change below. Fix missing and duplicate entries. Remove an entry whose feature the app no longer has, not one whose file a recorder has not written yet. Add an entry for each candidate feature the index lacks. Name a new feature after what the user does or sees, in kebab-case, with a one-line scope on its index line. Scopes never overlap: when two index lines name the same behavior, narrow one of them. Update `## Change triggers` from the source for new, removed and moved features. Check that the two Claude Code stubs still match the real skills' `name` and `description`.

2. **Map only: read.** Readers cover every feature in small batches of related features. Return shape: feature summary / source entry points / likely drift or none / proposed recipe. Drift means the recipe no longer matches the app or its source. Without subagents, read the groups yourself. Spot-check cited drift and update the files and index. Require concrete source evidence for additions and removals. Preserve expected behavior supported by a request, documented contract or established test. Current code alone does not prove a conflicting expectation is obsolete. Report possible product defects and unresolved expectations instead of writing them into the map as normal behavior. Each recipe keeps its exact setup and fixture cleanup so it runs from the baseline.
3. **Modes that drive: record.** Follow `verify-<app>`'s Isolation, Launch and Doctor sections; when `launch.sh` already runs doctor, do not run it again. Before any recorder starts, look at the app once as a recipe would: run the Baseline's sign-in or open command with `VERIFY_SESSION=main`, take one accessibility snapshot of the main screen, keep only its lines that carry a role and a name in `.agents/skills/verify-<app>/.cache/record/main-screen.txt` and close that session, in one command. For Playwright CLI that is `pw.sh snapshot --filename=<that path>.yml` and `grep -E '^ *- (button|link|menuitem|textbox|heading|tab) "'` of it; for an API, the paths in one `curl` of the OpenAPI document; for a CLI, its `--help`. Right after it, in one command, run `bin/rec.sh common`, the once-per-run command under Brief files and one `bin/rec.sh brief $(cat .agents/skills/verify-<app>/.cache/record/queue.txt)` for every feature; never read the files they write. Then give every feature to a recorder, all on that one environment. Recorders at once: <n>, and fixers the same; `drive.sh`'s `--jobs` does not set it. Raise it for an app that takes more; lower it when browsers fail to start or memory runs out. Start what `bin/rec.sh next` prints in one turn, each with the one-line prompt under Brief files. When a recorder returns, run `bin/rec.sh next <features still running>` and start what it prints in that turn, with nothing else: no report read, index edit or brief command. Between returns, do nothing: no waiting turn, no `date`, no narration. Never paste brief, report or feature text into your messages or prompts. Post a progress line, if any, each time that many more recorders have returned. Each recorder writes its full report to `.agents/skills/verify-<app>/.cache/record/<feature>/report.md` and returns one line, naming the features it split off.

   When every recorder has returned, read the report files of the features whose line shows a split, a known failure or a blocker, in one `cat`; never read the others. Act on them:
   - Send back each feature `bin/rec.sh sendback` prints, as no drift needs a passing run.
   - Fix the helper defects that reports name as blockers yourself, and the documented dependencies or setup steps they lack, inside the owned environment, then send each blocked feature back. A prerequisite the project does not document stays blocked: report it.
   - Correct the index entries and change triggers of the features that those reports name as changed, split or blocked: each split-off feature gets its own triggers, and the feature it came from keeps those of the sub-features its file still holds.
   - Before a feature goes back, run `bin/rec.sh common` and `bin/rec.sh brief <feature>`, and append why in the same call: `echo 'Sent back: <reason>' >> .agents/skills/verify-<app>/.cache/record/<feature>/brief.md`. A split-off feature first gets the `contract-map.tsv` and `contract-words.tsv` lines of the feature it came from, under its own name. Its staged copy stays, so the new recorder starts from it.
   - Report each known failure as a possible product defect or unresolved expectation.

   Then, unless the Baseline gives each recipe its own account or data namespace, check for fixture clashes with one `grep -H '^names' .agents/skills/verify-<app>/.cache/record/*/facts.tsv`: when two features create the same account, fixture or resource name, send one back to rename it. When none goes back, run `bin/rec.sh install`, which moves the staged copies that passed into `features/`. In changed-recipes mode, read the Files and Split lines first, in the same call, with `grep -h -e '^- Files' -e '^- Split' .agents/skills/verify-<app>/.cache/record/*/report.md | grep -v -E -e 'no drift' -e 'none[.]?$'`, because install keeps only each moved feature's facts.tsv.

## Select what to drive

- **Map only:** go to Ship. No drives.
- **Changed recipes:** select each feature that the recorders' Files or Split lines name as new, or as having a step that is new or whose action, command, expected result, proof or cleanup changed meaningfully. If the baseline or the driving conventions changed since the starting record, select every feature that change affects. Select the refused features the global maintenance skill listed. Wording, formatting, index repairs, unchanged renames and deletions select nothing. If nothing qualifies, run Cleanup and go to Ship.
- **Full audit:** every feature.

`bin/drive.sh --check [feature...]` launches nothing and names each step and missing Contract line of a recipe that needs conversion. A selected feature it names goes to a recorder to be converted before the drive, added to `convert.txt` first; `drive.sh` refuses to run it otherwise. Unselected recipes stay as they are.

Do not treat unselected features as verified.

## Drive the selected features

Follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, When a drive fails, Evidence and Cleanup sections. They set the driver, the isolation level, the deadlines and the failure rules.

Commit the map changes after `bin/rec.sh install` and before this fresh launch, because some Doctors compare the launched revision with `HEAD`; `verify-<app>`'s Doctor section says when this one does. Then run `bin/cleanup.sh`, `bin/launch.sh` and, unless launch runs it, `bin/doctor.sh`. Then drive all selected features in one `bin/drive.sh` call, started in the background with its output in `.agents/skills/verify-<app>/.cache/drive.txt`, and do nothing until it finishes: no tailing, no counting lines. Read its summary once, with `sed -n '/^Summary$/,$p'` of that file; a `not run (<reason>)` line needs no log read. Send each failing feature to a fresh fixer: one `bin/rec.sh fix-brief <feature>...` writes every failing feature's `fix-brief.md` from that summary, and each prompt is the one line under Brief files. Read only the line each returns. A feature that fails only at its known-failure step, which a recorder's Known failures line or a fixer's line names, needs no fixer. Run fixers the way Update the map step 3 runs recorders, after writing the failing features to `queue.txt` and removing `started.txt`, never beside your own drive. When the fixers are done, run `bin/rec.sh install` for the features they repaired, then drive those and the features not run once, the same way, with the output in `.agents/skills/verify-<app>/.cache/drive-2.txt`. That summary, the first one and the fixers' lines are the record of the pass. The report's evidence links come from the last summary of each feature and one `ls -R .agents/skills/verify-<app>/.cache/evidence/`.

After an aborted run, clean up its recorded leftovers, create a new environment, drive the features without a result and keep the evidence.

Change an expected result only when there is evidence that the contract changed, never because the app disagrees. A known failure stays failed.

A step that needs data the baseline lacks gets that data created first, from the project's own APIs, endpoints or documented setup inside the owned environment. "Missing from the seed" is not a reason to block. A step is blocked only when the prerequisite would need a service that is not owned or approved, or setup the project does not have. Name the missing prerequisite and what was tried, and add it to the map.

Every selected feature ends with a result: pass, fail, partial or blocked. If Doctor fails because of a helper defect, correct it and retry once before reporting the blocker. When a healthy-looking app is wedged, clean up the run's resources and relaunch.

Finish or abort through Cleanup, including when startup or a drive fails. Check that cleanup completed and evidence still exists before reporting.

## Helper briefs

The Recorder and Fixer templates below hold `{{...}}` placeholders; `bin/rec.sh brief` and `fix-brief` copy them out of this skill and fill one brief file per feature. Paths are relative to the repository root.

### Common file

`bin/rec.sh common` writes the common file `.agents/skills/verify-<app>/.cache/record/brief-common.md` under 20,000 bytes, the inline tool-output limit: the Baseline, Driving conventions, Feature file shape and Gotchas of `features/README.md`, the Helpers section of `verify-<app>/SKILL.md`, `main-screen.txt` and an example: the Preconditions and two steps of the shortest accepted recipe of at least five steps, else of the shortest such staged copy that passed `rec.sh run`, else none.

### Recorder

```
You are a recorder for verify-<app>: you write one feature's recipe and run it against the live app with rec.sh. The app is running; another agent owns its lifecycle.

Repository root: {{root}}; run every command from there. rec.sh is .agents/skills/verify-<app>/bin/rec.sh.
Feature: {{feature}}. Index line: {{index_line}} New: {{new}}. Convert a recipe drive.sh --check refuses, that is, add bash blocks to a recipe written as prose: {{convert}}.
Other features: {{other_features}}.
Driving conventions changed in this pass, as diff lines (< removed, > added), a note that they were rewritten, or none:
{{conventions_changed}}

The common file .agents/skills/verify-<app>/.cache/record/brief-common.md holds the project's conventions, helpers, gotchas, main screen and, once it has one, an example recipe. Follow its Driving conventions, copy the example's idioms, and take element names from your peeks, the main-screen snapshot and the example. Read no other skill file, recipe or helper script.

Drive only with <driver>. Call only rec.sh start, peek, run, result and index, for your feature and those you split off, and the helpers in the common file; never drive.sh, rec.sh install, launch.sh, cleanup.sh or doctor.sh. Write only the staged copies rec.sh start names, plus the README index through rec.sh index. Do not commit or push.

Put commands that belong together in one call. Look at the app only with rec.sh peek; never run <driver> outside rec.sh run and peek. Do not narrate.
1. Contract: run each command below in its own call, nothing else. failures.txt: other recorders' failed steps (feature, step, command, last output line); contract.md, your feature file, then contract sections, large ones as excerpts or not-read lines; changes.diff, when listed, is what changed since the last review.
{{read_commands}}
   List every behavior they name: test cases, README sentences, plan acceptance lines, entry points. Each gets a step, and so does every sub-feature and entry point the file lists, or it goes under Blocked. When your only section is the README overview, the list comes from the sub-features and entry points that the source grep and your peek show.
2. Source, one command: one grep for the routes and names the steps target, for drift (the recipe no longer matches the app or its source), or for what excerpts leave out. Your only source read.
3. Write. With changes.diff listed, first run rec.sh <feature> start and run on the unchanged copy. Report `no drift` only when that first run passes and its steps cover your list. When a step fails, fix it from changes.diff and its snapshot. Without it, when the feature is not new, matches contract and source, covers the list and every == line, breaks no changed convention and needs no conversion, change nothing. Otherwise run rec.sh <feature> start and write the Preconditions and Clean up first, into the path it prints. Before the first run, write the steps that reach every state the recipe will check, direct URLs, error pages, second tabs and Clean up's starting state included, and look at them in one peek: rec.sh <feature> peek --after '<Label>' --after '<Label>' --find '<expression>' saves the state after each named step to .agents/skills/verify-<app>/.cache/record/<feature>/peek.txt, peek-<n>.txt for the n-th of several. --find checks each step's expressions: pass each screen's in one peek, re-peek only for misses, fix every !! line: a name from a fixture, plan or source is a guess until find shows it; never print a whole snapshot. rec.sh run refuses a step no peek reached since its block changed, so the last peek reaches the last step. Then write the whole file at once, its ## Contract section filled from the == lines of contract.md except (mentions), one line each: '- <file>:<heading> → <step labels>' or '- <file>:<heading> → not driven: <reason>'; rec.sh run refuses a copy that skips one. Go to step 4. Keep unchanged steps and Gotchas lines still true; converting adds blocks and changes no check.
4. Run: rec.sh <feature> run prints the result when the run ends; if your tool returned first, rec.sh <feature> result waits and prints it; never poll or rerun a run still going. A failure prints the failing step's commands and output end, runs Clean up and ends with failing step:, snapshot: (the failing step's state, read it instead of rerunning) and full log:. Fix and rerun until it prints "passed", and after a failed value check assert the printed value when the contract allows, never a second guess; later edits to prose or Gotchas keep it passed. When the app or a missing prerequisite blocks the recipe, stop: leave the staged copy as is, put the failing step, failed command and log path under Blocked, and return the line with blocked.
5. Report, then return its line.

Scope: a behavior one of the other features covers is at most setup here, with no checks of its own; one that fits no feature goes under Split or Blocked. Split: past about 15 steps, write the first coherent group of sub-features here and record each other group yourself as its own feature: rec.sh <split> start, write its file, rec.sh <split> run until it passes, then rec.sh <split> index '- [<Title>](./<split>.md) covers <scope>.' Known failure: a contract the app misses stays in the known-failure step the conventions describe, run with rec.sh <feature> run --known-failure '<Label>'.

Traps: when a rec.sh run attempt fails for a reason another recorder could hit, append one line to .agents/skills/verify-<app>/.cache/record/traps.md in the same call as the fix, with echo '<line>' >>: the trap and its fix, for example "new URL() is not available in run-code; read location.pathname". Never a step-specific locator.

If you cannot finish, remove what your commands created beyond Clean up, and report the passing steps and the blocker.

Report with one Bash call, cat > .agents/skills/verify-<app>/.cache/record/{{feature}}/report.md <<'EOF' … EOF followed by rec.sh <name> facts for your feature and each split you ran, never the file-writing tool, because some hosts refuse a subagent writing report files with it:
- Files: what changed in the staged copy and the last run result, or "no drift" after a pass of the unchanged copy.
- Known failures: each expected result the app misses, with its contract source, what the app did and the step that carries it.
- Split: [name: its sub-features], one line per feature you split off and recorded, or none.
- Blocked: each part you could not drive, with the passing steps, the blocker and what you tried.

Then return only this line:
{{feature}}: no drift|passed|passed with known failure|blocked; <n> steps; <k> attempts (sum of the attempts lines facts printed); split: <names or none>; known failures: <count>; blocked: <count>
```

### Fixer

```
You are a fixer for verify-<app>. One recipe failed a drive. Feature: {{feature}}. Failing step: {{label}}. Log: {{log}}.

Repository root: {{root}}; run every command from there. rec.sh is .agents/skills/verify-<app>/bin/rec.sh.

In two calls, read .agents/skills/verify-<app>/.cache/record/brief-common.md and .agents/skills/verify-<app>/.cache/record/{{feature}}/fix-read.md: snapshot path, When a drive fails, traps, the log's end and your Driving section. Follow the common file's Driving conventions. Classify the failure as one of the four kinds in When a drive fails. When the kind depends on the contract, grep once the sources your Contract lines name.

Drive only with <driver>. Call only rec.sh <feature> start, peek, run and result, and the helpers in the common file; never drive.sh, rec.sh install, launch.sh, cleanup.sh or doctor.sh. Edit no helper, SKILL.md, features/README.md or product code, and write no tracked file. Do not commit or push.

When the recipe is wrong, fix the step in the staged copy rec.sh <feature> start names, keeping its check and label. After each edit, run rec.sh <feature> peek --after '<last step>' --find '<its expressions>', then rec.sh <feature> run (or result, if your tool returned first) until it passes, with --known-failure '<Label>' for a known-failure step. A failed run prints a snapshot and log path; read names there, never print the log whole. A peek that stops at the failing step because the app misses the contract is a product defect: do not run. When a missing prerequisite blocks the fix, stop, leave the staged copy and return the line with the failing step, failed command and log path. A product defect, an uncertain expectation, a helper defect or an unhealthy environment changes nothing: name it.

Return one line: <feature>: <kind>: <what you changed, or what is wrong and where>; run: passed, passed with the known failure at "<step>", fail at "<step>", or not run; <k> attempts.
```

### Brief files

Once per run, in the step 3 call, from the repository root. Replace only the mode, the contract sources, the first `printf` list and `refused`: the mode is `full` in a full audit and `changed` otherwise; the list with pairs of a feature and its name and index words, as `<word>|<word>`; `refused` with the features `drive.sh --check` refused, in every mode. A request text goes to `$r/request.md` in the same call, with `printf '%s\t%s\tsection\n' <feature> "$r/request.md:1-\$" >> $r/contract-map.tsv` after `rec.sh map` for each feature it concerns.

A contract section says what one feature should do: `README.md:## Search` is that heading down to the next at its level or above; `test/search.test.ts:40-72` is a `describe`, `it` or `test` line down to the next. Contract sources are the README, docs, plans, tests and specs. `rec.sh map` maps each line holding a feature's word to the section above it, once per run: `section` when the word is in the heading line, else `mention`. For example, if `search` appears in a heading, the whole section belongs to the feature; if only in body text, only those lines are copied into `contract.md`. `rec.sh brief` keeps `contract.md` under 20,000 bytes: sections whose heading holds a feature word, other sections, then mentions; a section over 6,000 bytes or the cap becomes an excerpt, and past the cap a `not read` line, still needing its Contract line. With no contract sources beyond a high-level README, replace the sources line and `rec.sh map` with `section` rows in `$r/contract-map.tsv` mapping every feature to the README's overview, such as `README.md:1-40`; recorders then take their behavior list from the source and their peeks, and Ship says so.

```
v=.agents/skills/verify-<app>; r=$v/.cache/record; mkdir -p $r
printf '%s\t%s\n' <feature> '<word>|<word>' <feature> '<word>|<word>' > $r/contract-words.tsv
printf '%s\n' README.md docs/*.md .plans/*.md test/*.test.ts > $r/contract-sources.txt
cut -f1 $r/contract-words.tsv > $r/queue.txt
rm -f $r/contract-map.tsv $r/started.txt; $v/bin/rec.sh map
: > $r/traps.md; : > $r/failures.txt
refused='<feature> <feature>'; : > $r/convert.txt
[ -z "$refused" ] || $v/bin/drive.sh --check $refused 2>&1 | sed -n 's|^drive.sh: features/\(.*\)\.md: .*|\1|p' | sort -u > $r/convert.txt
echo <full or changed> > $r/mode.txt
```

Recorder briefs: `bin/rec.sh brief <feature>...`, from the repository root, in the step 3 call for every feature and again for each feature that goes back. It prints a line for each feature without an index line or contract sections, and writes each feature's `contract.md`, `changes.diff` and `brief.md`.

The whole prompt of each recorder:

```
You are a recorder for verify-<app>. Read <repository root>/.agents/skills/verify-<app>/.cache/record/<feature>/brief.md and do what it says.
```

Fixer briefs: `bin/rec.sh fix-brief <feature>...`, once for every failing feature. It takes each feature's failing step and log from the drive summary in `.cache/drive.txt` and prints a line for each feature the summary shows no failure for.

The whole prompt of each fixer:

```
You are a fixer for verify-<app>. Read <repository root>/.agents/skills/verify-<app>/.cache/record/<feature>/fix-brief.md and do what it says.
```

## Ship

Follow the repository's branch, commit and PR conventions as you edit. Keep all corrections in one branch and PR. In the modes that drive, commit the rest, then `bin/rec.sh reviewed '<message>'` commits `last-reviewed` alone when it changes, so the next diff skips this pass's edits. When `.agents/skills/verify-<app>/.cache/record/traps.md` has lines, read it once and fold the lines that still hold into the `## Gotchas` list of `features/README.md` in one edit, creating that section after Driving conventions when it is missing. Re-read the files you changed before shipping. Report the outcome separately from the step results:

- **clean:** every selected feature has a result and there were no corrections; the PR, if any, holds only `last-reviewed`. This does not mean every product check passed.
- **changed:** every selected feature has a result and corrections shipped in one PR.
- **incomplete:** cleanup failed, corrections could not ship safely, or selected features have no result or are blocked. Name each such feature and why.

Put the report in the final message. Name the mode and summarize additions, removals, corrections, unresolved expectations and helper problems.

- **Map only:** say `Source-reviewed; no live drives run`.
- **Changed recipes:** list each selected feature with the map change that selected it. Say how many features were not driven, and give the `skipped` and `unmapped change` lines of `.cache/affected.txt`. If none qualified, say no drives were needed.
- **Full audit:** report every feature.

When the contract map listed only the README overview, say that every expectation in the map is the behavior observed on this date, to be questioned by whoever changes that area, because nothing in the run could tell a bug from an intention. Give each selected feature's result. List each feature's `not driven` contract lines, from one `grep -H ' → not driven: ' .agents/skills/verify-<app>/features/*.md --exclude=README.md`. Name every feature that did not pass, with the step and its reason: blocked (what was tried, and the kept `.cache/record/<feature>/` folder), failed or partial. List each known failure with its feature, the step that carries it and the contract it misses. Follow `verify-<app>`'s Report section for omissions, evidence links, classified findings and the cleanup result.

Keep working notes under `.agents/skills/verify-<app>/.cache/`, never in tracked files. Remove them during cleanup, except each blocked feature's `.cache/record/<feature>/`, whose staged copy the next pass starts from; the evidence stays.
