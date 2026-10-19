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

Helper agents do the reading and recording, so your own context stays small. Read only what they return, the report files Update the map step 3 names and, at Ship, `traps.md`. Never open a feature file a helper wrote in this pass.

- A **reader** reads source for a small group of related features and proposes edits. It edits nothing. Readers work in map-only mode.
- A **recorder** takes one feature. It checks the feature against its contract and source and, when the recipe needs it, writes the whole feature file into a staged copy under `.cache/record/<feature>/` and runs it against the live app with `bin/rec.sh <feature> run`. It never writes a tracked file. Recorders work in the modes that drive.
- A **fixer** takes one feature that failed a drive, repairs its recipe in a staged copy and runs that copy with `bin/rec.sh <feature> run`.

Start recorders and fixers with the brief files and one-line prompts under Helper briefs. Without a subagent tool, do the same work yourself, one feature at a time, still through `bin/rec.sh`.

## Edit scope

In map-only mode, edit only the feature files and index. Report helper or lifecycle problems without trying a live repair. In modes that drive, recorders and fixers edit only the staged copies of their own feature files, and you move them into `features/` with `bin/rec.sh install`. You edit the index, `verify-<app>/SKILL.md`, its helpers other than `drive.sh`, `steps.sh` and `rec.sh`, and its Claude Code stub. Never edit product code.

## Update the map

Start with one command that prints `verify-<app>/SKILL.md`, `features/README.md` and the two Claude Code stubs' frontmatter, lists the feature files, and copies `features/README.md` to `.agents/skills/verify-<app>/.cache/starting-README.md`. That is your only read of those files in this pass. The copy is the starting record of the map and driving conventions, so selection includes every change in this pass, even ones already committed during it. When the global maintenance skill invokes you, it made that copy before conformance: leave the copy out of your command, and take its list of the features `bin/drive.sh --check` refused.

1. **Index**, two commands. One grep over routes, navigation, commands and endpoints lists the candidate features: a list, not a read of every component. Then one edit of `features/README.md` makes every change below. Fix missing and duplicate entries. An entry is dead when the app no longer has its feature: remove it. An entry whose file a recorder has not written yet is not dead. Add an entry for each candidate feature the index lacks. Name a new feature after what the user does or sees, in kebab-case like the existing files. Its index line gives its name and a one-line scope, so every recorder starts from both. Scopes never overlap: when two index lines name the same behavior, narrow one of them. A feature's Driving section holds at most about 15 steps, `Clean up` included, because a recorder's cost and context grow with every step it writes and repairs. A feature that needs more is several features: split it by groups of sub-features into separate files, each with its own index line and change triggers, and each recorded by its own recorder from a fresh context. Update `## Change triggers` from the source: add the triggers of new features, remove those of removed features, and correct those of features whose source moved. Check that the two Claude Code stubs still match the real skills' `name` and `description`.
2. **Map only: read.** Readers cover every feature in small batches of related features. Return shape: feature summary / source entry points / likely drift or none / proposed recipe. Without subagents, read the groups yourself. Spot-check cited drift and update the files and index. Require concrete source evidence for additions and removals. Preserve expected behavior supported by a request, documented contract or established test. Current code alone does not prove a conflicting expectation is obsolete. Report possible product defects and unresolved expectations instead of writing them into the map as normal behavior. Each recipe keeps its exact setup and fixture cleanup so it runs from the baseline.
3. **Modes that drive: record.** Follow `verify-<app>`'s Isolation, Launch and Doctor sections. Then look at the app once, the way a recipe would, before any recorder starts: run the Baseline's sign-in or open command with `VERIFY_SESSION=main`, take one accessibility snapshot of the main screen into `.agents/skills/verify-<app>/.cache/record/main-screen.txt` and close that session, in one command. For Playwright CLI the snapshot is `pw.sh snapshot --filename=<that path>`; for an API, one `curl` of the index or the OpenAPI document; for a CLI, its `--help`. The same command without the path is the `REC_PEEK` value in the Recorder template, for Playwright CLI `pw.sh snapshot --filename=`. Right after it, write `.agents/skills/verify-<app>/.cache/record/brief-common.md`, the part of the brief that is the same for every recorder, in one command that copies it out of the project's files in the shape under Common brief file, so you type none of it out and never read it. In the same call, run the once-per-run command under Brief files: it copies the recorder and fixer templates out of this skill and writes `contract-map.tsv`, one line per contract section of each feature, an empty `traps.md`, and `convert.txt`, the features whose recipes a recorder converts: every feature in a full audit, the refused features on that list otherwise. Then give every feature to a recorder, all on that one environment. The queue holds the features no recorder has taken yet and those going back to one. Recorders at once: <n>. That many recorders run at a time, and fixers the same. The `--jobs` value in `verify-<app>`'s Drive section is `drive.sh`'s and does not set this number. A project whose app has shown it takes more recorders at once may raise it; one whose app struggles, for example browsers fail to start or memory runs out, lowers it. Start that many in one turn: the recorder brief command under Brief files writes each one's `brief.md`, and each recorder gets the one-line prompt there. Each time a recorder returns, read its one-line result, act on it only when it shows a split, a difference or a blocker, and in the same turn start the next feature from the queue, with the brief command for that one feature and its one-line prompt. Between returns, do nothing: no turn spent waiting, no `date`, no narration. You never type a brief out, and you never paste brief text, report text or feature content into your own messages or into prompts. Run the common brief command again before the next recorder starts whenever a helper changed. A progress line, if you post one, comes each time that many more recorders have returned, for example `recorded 12/88`. Each feature keeps its own `VERIFY_SESSION`, so recorders work side by side like `drive.sh --jobs`. Recorders never write tracked files, so they run in parallel in every project. Features that change state other features read, such as global settings, wait until the queue is otherwise empty and the other recorders have returned, then record one at a time. A project whose Drive section uses `--jobs 1` because features cannot be kept apart records one feature at a time as well. Each recorder writes its full report to `.agents/skills/verify-<app>/.cache/record/<feature>/report.md` and returns one line. When a line shows a split, a difference or a blocker, read that feature's report file in one `cat`; never read the others. Act on it:
   - Make the helper changes that reports name as blockers yourself. A missing dependency or setup step that the project documents is yours to fix as well, inside the owned environment. Then send each blocked feature back to a recorder. A prerequisite the project does not document stays blocked: report it.
   - Correct the index entries and change triggers of the features that those reports name as changed or blocked.
   - A feature that goes back to a recorder gets its brief from the recorder brief command again, with one line on why appended in the same call: `echo 'Sent back: <reason>' >> .agents/skills/verify-<app>/.cache/record/<feature>/brief.md`. Its staged file stays, so the new recorder starts from it.
   - For each proposed feature on a report's Split line, add an index line and change triggers, append its contract sections to `contract-map.tsv` with `printf '%s\t%s\n' <name> '<file>:<section>' >>`, narrow the split feature's own index line and triggers to the sub-features its file now holds, and put the proposed feature in the queue as a new feature.
   - Report each Difference as a possible product defect or unresolved expectation.

   When the queue is empty and every recorder has returned, check for fixture clashes. Two features' fixtures clash only when they share a namespace. When the Baseline gives each recipe its own account or data namespace, there are no clashes to check. Otherwise compare the Names lines, read with one `grep -H '^- Names' .agents/skills/verify-<app>/.cache/record/*/report.md`: when two features create the same account, fixture or resource name, send one of them back to a recorder to rename it. When none goes back, run `bin/rec.sh install`. It moves the staged feature files that passed `rec.sh run` into `features/`, names any it skipped, and runs `drive.sh --check` on the ones it moved. In changed-recipes mode, read the Files lines of the features that changed first, in the same call, with `grep -h '^- Files' .agents/skills/verify-<app>/.cache/record/*/report.md | grep -v 'no drift'`, because install removes the record folders of the features it moves.

## Select what to drive

- **Map only:** go to Ship. No drives.
- **Changed recipes:** select each feature that the recorders' Files lines name as new, or as having a step that is new or whose action, command, expected result, proof or cleanup changed meaningfully. If the baseline or the driving conventions changed since the recorded starting point, select every feature that change affects. Select the refused features the global maintenance skill listed. Wording, formatting, index repairs, unchanged renames and deletions select nothing. If nothing qualifies, run Cleanup and go to Ship.
- **Full audit:** every feature.

`bin/drive.sh --check [feature...]` finds the recipes that need conversion. It launches nothing and names each step that has no `bash` block or calls `launch.sh`, `cleanup.sh` or `doctor.sh`. A selected feature it names goes to a recorder to be converted before the drive, added to `convert.txt` first; `drive.sh` refuses to run it otherwise. Unselected recipes stay as they are. At `checks-only`, recipes have no `bash` blocks by design, so this check converts nothing.

Do not treat unselected features as verified.

## Drive the selected features

Follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, When a drive fails, Evidence and Cleanup sections. They set the driver, the isolation level, the deadlines and the failure rules.

Drive from a fresh environment, not from the state the recorders left. Commit the map changes after `bin/rec.sh install` and before this fresh launch, because some Doctors compare the launched revision with `HEAD`; `verify-<app>`'s Doctor section says when this one does. Then run `bin/cleanup.sh`, launch again with `bin/launch.sh` and run `bin/doctor.sh`. Then drive all selected features in one `bin/drive.sh` call, started in the background with its output in `.agents/skills/verify-<app>/.cache/drive.txt`, and do nothing until it finishes: no tailing, no counting lines. Read its summary once, with `sed -n '/^Summary$/,$p'` of that file. Send each failing feature to a fresh fixer: the fixer brief command under Brief files writes its `fix-brief.md` from that summary, and its prompt is the one line there. Read only the line it returns. A feature that fails only at a known product failure, a step that a recorder's Differences or a fixer's line names, needs no fixer. Run fixers the way Update the map step 3 runs recorders, the `Recorders at once` number at a time: each time one returns, start the next failing feature in the same turn. Never run them beside your own drive. Fixers of features that change state other features read wait until the other fixers have returned, then run one at a time, and a project that records one feature at a time fixes one at a time as well. When the fixers are done, run `bin/rec.sh install` for the features they repaired, then drive only those features once, the same way. That summary, the first one and the fixers' lines are the record of the pass. The report's evidence links come from the last summary of each feature and one `ls -R .agents/skills/verify-<app>/.cache/evidence/`, which lists the saved proof and the step logs.

After an aborted run, clean up its recorded leftovers, create a new environment, drive the features without a result and keep the evidence.

Change an expected result only when there is evidence that the contract changed, never because the app disagrees. A known product failure stays failed.

A step that needs data the baseline lacks gets that data created first, from the project's own APIs, endpoints or documented setup inside the owned environment. "Missing from the seed" is not a reason to block. A step is blocked only when the prerequisite would need a service that is not owned or approved, or setup the project does not have. Name the missing prerequisite and what was tried, and add it to the map.

Every selected feature ends with a result: pass, fail, partial or blocked. Never leave one unattempted. If Doctor fails because of a helper defect, correct it and retry once before reporting the blocker. When a healthy-looking app is wedged, clean up the run's resources and relaunch.

Finish or abort through Cleanup, including when startup or a drive fails. Check that cleanup completed and evidence still exists before reporting.

## Helper briefs

Recorders and fixers get their briefs as files. The Recorder and Fixer templates below hold `{{...}}` placeholders; the commands under Brief files copy them out of this skill and fill one brief file per feature, so you never type a brief out. Paths are relative to the repository root. Both briefs send the helper to the common brief file first.

### Common brief file

The command in Update the map step 3 writes this file from the project's files. Each `[...]` is the content it names, copied as it is.

```
# Common brief for verify-<app> recorders and fixers

## From .agents/skills/verify-<app>/features/README.md

[its Baseline, Driving conventions and Feature file shape sections]

## Helpers, from .agents/skills/verify-<app>/SKILL.md; call them by name, they are on PATH inside a run

[the Helpers section of verify-<app>/SKILL.md, each helper with one call as it appears in a recipe]

## Example recipe, from this project

[the shortest feature file in .agents/skills/verify-<app>/features/ that bin/drive.sh --check accepts]

## The app's main screen, as an accessibility snapshot taken after the baseline sign-in

[.agents/skills/verify-<app>/.cache/record/main-screen.txt]

## Gotchas, from .agents/skills/verify-<app>/features/README.md

[its Gotchas section, when it has one]
```

When no feature file passes `bin/drive.sh --check` yet, leave out the Example recipe section, so the Feature file shape stands alone, until a staged feature file has passed `rec.sh run`. From then on the section holds the first such file, and you write the common file again before the next recorder starts. Traps found in this run stay out of it: helpers read `traps.md` directly, because the common file is not written again when a line is added.

### Recorder

```
You are a recorder for verify-<app>: you write one feature's recipe and run it against the live app with rec.sh. The app is running; another agent owns its lifecycle.

Repository root: {{root}}; run every command from there. rec.sh is .agents/skills/verify-<app>/bin/rec.sh.
Feature: {{feature}}. Index line: {{index_line}} New: {{new}}. Convert a recipe whose steps lack bash blocks: {{convert}}.
Other features: {{other_features}}.
Driving conventions changed in this pass, as diff lines (< removed, > added), a note that they were rewritten, or none:
{{conventions_changed}}

The common file .agents/skills/verify-<app>/.cache/record/brief-common.md holds the Baseline, Driving conventions, Feature file shape, the helpers, an example recipe once the project has one, a snapshot of the main screen and the project's gotchas. Follow its Driving conventions, copy the example's idioms, and take element names from your peek, the main-screen snapshot and the example, not from source. Read no other skill file, recipe or helper script.

Drive only with <driver>. Call only rec.sh <feature> start, rec.sh <feature> run and the helpers in the common file; never drive.sh, rec.sh install, launch.sh, cleanup.sh or doctor.sh. Edit no helper, SKILL.md, features/README.md or product code, and write no tracked file. Do not commit or push.

Put commands that belong together in one call. Do not explore the app: the run is the attempt. Do not narrate.
1. Contract, one command: print the common file, .agents/skills/verify-<app>/.cache/record/traps.md, .agents/skills/verify-<app>/features/<feature>.md if it exists, and your contract sections with: awk -F '\t' -v f={{feature}} '$1 == f {print $2}' .agents/skills/verify-<app>/.cache/record/contract-map.tsv | while IFS= read -r s; do echo "== $s"; f=${s%%:*} p=${s#*:}; case $p in '#'*) awk -v h="$p" '$0 == h {n = index($0, " "); print; next} n && /^#+ / && index($0, " ") <= n {exit} n' "$f";; *) sed -n "${p%-*},${p#*-}p" "$f";; esac; done
   If the sections look thin for this feature, grep the contract files once for its names, with grep -n -i -E '<names>' $(cut -f2 .agents/skills/verify-<app>/.cache/record/contract-map.tsv | cut -d: -f1 | sort -u); that is your only extra contract read. List every behavior they name: test cases, README sentences, plan acceptance lines, entry points. Each gets a step, and so does every sub-feature and entry point the file lists, or it goes under Blocked. When your only section is the README overview, the list comes from the sub-features and entry points that the source grep and your peek show.
2. Source, one command: one grep for the routes and names the steps target, or for drift. Your only source read.
3. Write. When the feature is not new, matches contract and source, covers the list, breaks no changed convention and needs no conversion, change nothing. Otherwise run rec.sh <feature> start and write the Preconditions and Clean up first, into the path it prints. Then run REC_PEEK='<peek command>' rec.sh <feature> peek once: it runs Preconditions as run does, saves one snapshot of the screen they leave to .agents/skills/verify-<app>/.cache/record/<feature>/peek.txt and runs Clean up. Grep peek.txt for the element names you need in the same call. Then write the whole file in one write and go to step 4. Keep unchanged steps; converting gives each step a block without changing what it checks.
4. Run, one call per attempt: rec.sh <feature> run prints the failing step's commands, the end of its output and the path of its full log, then runs Clean up. Fix and rerun until it prints "passed". When the app or a missing prerequisite blocks the recipe, stop: leave the staged file as it is, put the failing step, the exact command that failed and the log path under Blocked, and return the line with blocked. One peek per feature: a second one is allowed only for a step that opens another screen, and only after that step's first failed run. REC_PEEK='<peek command>' rec.sh <feature> peek --after '<that step>' runs Preconditions through that step, stops at a failure, and snapshots the screen where it stopped; grep peek.txt in the same call. Never print a whole snapshot.
5. Report, then return its line.

Scope: a behavior one of the other features covers is at most setup here, with no checks of its own; one that fits no feature goes under Split or Blocked. Split: past about 15 steps, write the first coherent group of sub-features and name the other groups under Split. Known failure: a contract the app misses stays in the known-failure step the conventions describe, run with rec.sh <feature> run --known-failure '<Label>'.

Traps: when a rec.sh run attempt fails for a reason another recorder could hit (a helper's argument shape, a runtime limit, a project quirk), append one line to .agents/skills/verify-<app>/.cache/record/traps.md in the same call as the fix, with echo '<line>' >>: the trap and its fix, for example "new URL() is not available in run-code; read location.pathname". Never a step-specific locator.

If you cannot finish, remove what your commands created beyond Clean up, and report the passing steps and the blocker.

Report with one Bash call, cat > .agents/skills/verify-<app>/.cache/record/{{feature}}/report.md <<'EOF' … EOF, never the file-writing tool, because some hosts refuse a subagent writing report files with it:
- Files: what changed in the staged file and the last run result, or "no drift".
- Run attempts: the number of rec.sh run calls.
- Differences: each expected result the app misses, with its contract source, what the app did and the step that carries it.
- Names: every account, fixture and resource name the recipe creates.
- Split: [proposed name: its sub-features], one line per group, or none.
- Blocked: each part you could not drive, with the passing steps, the blocker and what you tried.

Then return only this line:
{{feature}}: no drift|passed|passed with known failure|blocked; <n> steps; <k> attempts; split: <names or none>; differences: <count>; blocked: <count>
```

### Fixer

```
You are a fixer for verify-<app>. One recipe failed a drive. Feature: {{feature}}. Failing step: {{label}}. Log: {{log}}.

Repository root: {{root}}; run every command from there. rec.sh is .agents/skills/verify-<app>/bin/rec.sh.

In one command, read .agents/skills/verify-<app>/.cache/record/brief-common.md, .agents/skills/verify-<app>/.cache/record/traps.md, the log, .agents/skills/verify-<app>/features/<feature>.md and the When a drive fails section of .agents/skills/verify-<app>/SKILL.md. Follow the common file's Driving conventions. Classify the failure as one of the four kinds in When a drive fails. Read the contract only when the kind depends on it, with: awk -F '\t' -v f={{feature}} '$1 == f {print $2}' .agents/skills/verify-<app>/.cache/record/contract-map.tsv | while IFS= read -r s; do echo "== $s"; f=${s%%:*} p=${s#*:}; case $p in '#'*) awk -v h="$p" '$0 == h {n = index($0, " "); print; next} n && /^#+ / && index($0, " ") <= n {exit} n' "$f";; *) sed -n "${p%-*},${p#*-}p" "$f";; esac; done

Drive only with <driver>. Call only rec.sh <feature> start, rec.sh <feature> run and the helpers in the common file; never drive.sh, rec.sh install, launch.sh, cleanup.sh or doctor.sh. Edit no helper, SKILL.md, features/README.md or product code, and write no tracked file. Do not commit or push.

When the recipe is wrong, run rec.sh <feature> start, fix the wrong step in the staged copy it names without changing what the step checks, and rerun rec.sh <feature> run until it prints "passed"; it prints the failing step's commands, the end of its output and the path of its full log, then runs Clean up. A known-failure step runs with --known-failure '<Label>'. When the app or a missing prerequisite blocks the fix, stop, leave the staged copy as it is and return the line with the failing step, the exact command that failed and the log path. For a label on another screen, add a snapshot to a file under .agents/skills/verify-<app>/.cache/record/<feature>/ before the failing command, rerun, grep the file in the same call, then remove it. Never print a whole snapshot. A product defect, an uncertain expectation, a helper defect or an unhealthy environment changes nothing: name it.

Return one line: <feature>: <kind>: <what you changed, or what is wrong and where>; run: passed, passed with the known failure at "<step>", fail at "<step>", or not run.
```

### Brief files

Once per run, in the call that writes the common brief file, from the repository root. Replace only the `mode` value and the two `printf` lists: `mode` is `full` in a full audit and `changed` otherwise; the first list with pairs of a feature and one of its contract sections; the second list with the features to convert, or in a full audit with `$(ls $v/features | sed -n 's/\.md$//p')`. When this pass has a request text, write it to `.agents/skills/verify-<app>/.cache/record/request.md` in the same call and map `.agents/skills/verify-<app>/.cache/record/request.md:1-$` to each feature it concerns.

A contract section is the part of a contract source that says what one feature should do. `<file>:<heading line>`, such as `README.md:## Search`, is a Markdown heading down to the next heading at its level or above. `<file>:<first>-<last>`, such as `test/search.test.ts:40-72`, is a line range. The contract sources are the README, docs, plans, tests and specs. Find the sections before this call with one grep over them for every feature's names and route words, together with the lines where a section starts, printing only line numbers and matches:

```
grep -n -o -i -E '^#{1,6} .*|^\s*(describe|it|test)\(.*|<word>|<word>' README.md docs/*.md .plans/*.md test/*.test.ts
```

Each hit belongs to the section that starts above it: a Markdown hit to its heading, a test hit to the lines of its `describe` or `it` block. Map a feature only to the sections that name it. When the project has no contract sources beyond a high-level README, with no plans, tests or specs that mention features, map every feature to the README's overview, such as `README.md:1-40`. Recorders then take their behavior list from the source and the screen, and Ship says so.

```
v=.agents/skills/verify-<app>; r=$v/.cache/record
template() { awk -v h="### $1" '$0 == h {s = 1; next} s && /^```/ {if (f) exit; f = 1; next} f' .agents/skills/maintain-verify-<app>/SKILL.md; }
mkdir -p $r && template Recorder > $r/brief-template.md && template Fixer > $r/fix-brief-template.md
printf '%s\t%s\n' <feature> '<file>:<section>' <feature> '<file>:<section>' > $r/contract-map.tsv
: > $r/traps.md
printf '%s\n' <feature> <feature> > $r/convert.txt
mode=<full or changed>; echo $mode > $r/mode.txt
```

Per recorder start, from the repository root, for one feature or several. Only the feature names after `for feature in` change. It takes the index line and the other features' names from `features/README.md`, New from whether `features/<feature>.md` exists, Convert from `convert.txt` and the convention changes from a diff against the starting record, which is `none` in a full audit, where every recipe is converted to the current conventions, and a single line saying they were rewritten when the diff is longer than 8 lines, and prints a line for each feature without an index line or contract sections in `contract-map.tsv`.

```
v=.agents/skills/verify-<app>; r=$v/.cache/record
export root=$PWD feature index_line other_features new convert conventions_changed=none
section() { awk '/^## /{p = /^## Driving conventions$/} p' "$1"; }
test -f $v/.cache/starting-README.md && test "$(cat $r/mode.txt)" = changed && conventions_changed=$(diff <(section $v/.cache/starting-README.md) <(section $v/features/README.md) | grep '^[<>]' || echo none)
test $(printf '%s\n' "$conventions_changed" | wc -l) -gt 8 && conventions_changed='the Driving conventions were rewritten; follow the current ones in the common file'
for feature in <feature> <feature>; do
  index_line=$(awk -v f="$feature" '/^## /{p = /^## Features$/} p && index($0, "](./" f ".md)") {print; exit}' $v/features/README.md)
  other_features=$(awk -v f="$feature" '/^## /{p = /^## Features$/} p && (i = index($0, "](./")) {n = substr($0, i + 4); n = substr(n, 1, index(n, ".md)") - 1); if (n != f) o = o (o == "" ? "" : ", ") n} END {print o}' $v/features/README.md)
  new=$(test -f $v/features/$feature.md && echo no || echo yes)
  convert=$(grep -qsx "$feature" $r/convert.txt && echo yes || echo no)
  test -n "$index_line" && awk -F '\t' -v f="$feature" '$1 == f {found = 1} END {exit !found}' $r/contract-map.tsv || echo "$feature: no index line or no contract sections"
  mkdir -p $r/$feature && awk '{o = ""; while (match($0, /[{][{][a-z_]+[}][}]/)) {o = o substr($0, 1, RSTART - 1) ENVIRON[substr($0, RSTART + 2, RLENGTH - 4)]; $0 = substr($0, RSTART + RLENGTH)} print o $0}' $r/brief-template.md > $r/$feature/brief.md
done
```

The whole prompt of each recorder:

```
You are a recorder for verify-<app>. Read <repository root>/.agents/skills/verify-<app>/.cache/record/<feature>/brief.md and do what it says.
```

Per fixer start, the same way. It takes each feature's failing step and log from the drive summary in `.cache/drive.txt` and prints a line for each feature the summary shows no failure for.

```
v=.agents/skills/verify-<app>; r=$v/.cache/record
export root=$PWD feature label log
for feature in <feature> <feature>; do
  IFS=$'\t' read -r label log < <(awk -v p="$feature: fail at \"" 'index($0, p) == 1 {s = substr($0, length(p) + 1); i = index(s, "\" ("); print substr(s, 1, i - 1) "\t" substr(s, i + 3, length(s) - i - 3)}' $v/.cache/drive.txt)
  test -n "$log" || echo "$feature: no failure in the drive summary"
  mkdir -p $r/$feature && awk '{o = ""; while (match($0, /[{][{][a-z_]+[}][}]/)) {o = o substr($0, 1, RSTART - 1) ENVIRON[substr($0, RSTART + 2, RLENGTH - 4)]; $0 = substr($0, RSTART + RLENGTH)} print o $0}' $r/fix-brief-template.md > $r/$feature/fix-brief.md
done
```

The whole prompt of each fixer:

```
You are a fixer for verify-<app>. Read <repository root>/.agents/skills/verify-<app>/.cache/record/<feature>/fix-brief.md and do what it says.
```

## Ship

Follow the repository's branch, commit and PR conventions as you edit. Keep all corrections in one branch and PR. When `.agents/skills/verify-<app>/.cache/record/traps.md` has lines, read it once and fold the lines that still hold into the `## Gotchas` list of `features/README.md` in one edit, creating that section after Driving conventions when it is missing. Re-read the files you changed yourself before shipping. Report the outcome separately from the step results:

- **clean:** every selected feature has a result and there were no corrections. No PR needed. This does not mean every product check passed.
- **changed:** every selected feature has a result and corrections shipped in one PR.
- **incomplete:** cleanup failed, corrections could not ship safely, or selected features have no result or are blocked. Name each such feature and why.

Put the report in the final message. Name the mode and summarize additions, removals, corrections, unresolved expectations and helper problems.

- **Map only:** say `Source-reviewed; no live drives run`.
- **Changed recipes:** list each selected feature with the map change that selected it. Say how many features were not driven. If none qualified, say no drives were needed.
- **Full audit:** report every feature.

When the contract map listed only the README overview, say that every expectation in the map is the behavior observed on this date, to be questioned by whoever changes that area, because nothing in the run could tell a bug from an intention. Give each selected feature's result. Name every feature that did not pass, with the step and its reason: blocked (what was tried), failed or partial. List each known product failure with its feature, the step that carries it and the contract it misses. Follow `verify-<app>`'s Report section for omissions, evidence links, classified findings and the cleanup result. When `usage-report` is on `PATH`, end the report with the output of `usage-report --cwd <repository> --since <today>`, with the repository's absolute path and today's date as `YYYY-MM-DD`.

Keep working notes under `.agents/skills/verify-<app>/.cache/`, never in tracked files. Remove them during cleanup; the evidence stays.
