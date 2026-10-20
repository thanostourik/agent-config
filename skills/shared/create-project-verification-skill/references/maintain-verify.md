---
name: maintain-verify-<app>
description: "Maintain the verify-<app> feature map and drive new and changed recipes. Use /maintain-verify-<app>, map only for source-only updates, or full audit to drive every feature."
disable-model-invocation: true
---

The user explicitly requests <driver> for every step of this skill, including runs you start yourself. Do not use the host's integrated browser, preview or computer-use tools. If the driver breaks, repair it or report a blocker; do not switch drivers. The one exception is a step that needs the user watching, such as a manual login: ask first, then return to the driver.

# Maintain verify-<app>

A feature map rots the moment the app changes. Each change updates its own features' entries as part of `verify-<app>`. Maintenance catches what those updates missed.

## Choose the mode

- **Changed recipes (default):** `/maintain-verify-<app>` launches the app, checks the features changed since the last pass against source, rewrites and reruns the recipes that drifted, then drives only the features with new or meaningfully changed steps. A step is one labeled bullet under `Driving it with <tool>`.
- **Map only:** `/maintain-verify-<app> map only` updates the map from source without launching or driving the app. Report the edits as source-reviewed, not live-verified.
- **Full audit:** `/maintain-verify-<app> full audit`, or an explicit request to drive all features, updates the map, converts every recipe whose steps lack `bash` blocks, and drives every feature, including unchanged ones.

When `verify-<app>`'s Isolation section says `checks-only`, every mode runs as map only: no recipe is converted, and every feature is reported `blocked: no isolation`.

Honor an explicit source-only or drive-all request. Do not escalate to a full audit because many files changed. In map-only mode, record any uncertainty for a later drive.

Messages you post anyway may carry progress lines such as `read 2/5: search, theme — 1 wrong step`. Never change how you split, delegate or order work to produce them, and never add a turn just to report.

## Helpers

Helper agents do the reading and recording, so your own context stays small. Read only what they return, the report files Update the map step 3 names and, at Ship, `traps.md`. Never open a feature file a helper wrote in this pass.

- A **reader** reads source for a small group of related features and proposes edits. It edits nothing. Readers work in map-only mode.
- A **recorder** takes one feature, checks it against its contract and source and, when the recipe needs it, writes the whole feature file into a staged copy and runs it against the live app with `bin/rec.sh <feature> run`, as it does for the features it splits off. Its only tracked edit is an index line. Recorders work in the modes that drive.
- A **fixer** takes one feature that failed a drive, repairs its recipe in a staged copy and runs that copy with `bin/rec.sh <feature> run`.

Start recorders and fixers with the brief files and one-line prompts under Helper briefs. Without a subagent tool, do the same work yourself, one feature at a time, still through `bin/rec.sh`.

## Edit scope

In map-only mode, edit only the feature files and index. Report helper or lifecycle problems without trying a live repair. In modes that drive, recorders and fixers edit only the staged copies of their own feature files, and you move them into `features/` with `bin/rec.sh install`. You edit the index, `verify-<app>/SKILL.md`, its helpers other than `drive.sh`, `steps.sh` and `rec.sh`, and its Claude Code stub. Never edit product code.

## Update the map

Start with one command that prints `verify-<app>/SKILL.md`, `features/README.md` and the two Claude Code stubs' frontmatter, lists the feature files, and copies `features/README.md` to `.agents/skills/verify-<app>/.cache/starting-README.md`. That is your only read of those files in this pass. The copy is the starting record of the map and driving conventions, so selection includes every change in this pass, even ones already committed during it. When the global maintenance skill invokes you, it made that copy before conformance: leave the copy out of your command, and take its list of the features `bin/drive.sh --check` refused.

1. **Index**, two commands. One grep over routes, navigation, commands and endpoints lists the candidate features: a list, not a read of every component. In changed-recipes mode with `features/last-reviewed`, run the command below first and the grep over `.cache/changed.txt` only, none when it is empty. From then on, every feature means the affected ones it prints, the grep's new ones and the listed refused ones; with none, go to Ship. Then one edit of `features/README.md` makes every change below. Fix missing and duplicate entries. An entry is dead when the app no longer has its feature: remove it. An entry whose file a recorder has not written yet is not dead. Add an entry for each candidate feature the index lacks. Name a new feature after what the user does or sees, in kebab-case, with a one-line scope on its index line. Scopes never overlap: when two index lines name the same behavior, narrow one of them. Update `## Change triggers` from the source: add the triggers of new features, remove those of removed features, and correct those whose source moved. Check that the two Claude Code stubs still match the real skills' `name` and `description`.

   ```
   v=.agents/skills/verify-<app>; b=$(cat $v/features/last-reviewed)
   if git cat-file -e "$b^{commit}" 2>/dev/null; then { git diff --name-only $b; git ls-files -o --exclude-standard; } | sort -u > $v/.cache/changed.txt
   awk -v b=$b -v d=$v/features/ -v kept="$(ls -d $v/.cache/record/*/ 2>/dev/null)" 'FNR==1{n++} n==1&&/^## /{t=/^## Change triggers$/;x=/^## Features$/}
   n==1&&t&&match($0,/: [a-z0-9][a-z0-9, -]*$/){f[++nt]=substr($0,RSTART+2);r[nt]="^$";h=substr($0,1,RSTART-1);while(match(h,/`[^`]+`/)){g=substr(h,RSTART+1,RLENGTH-2);h=substr(h,RSTART+RLENGTH);gsub(/[.]/,"[.]",g);gsub(/[*]/,".*",g);r[nt]=r[nt]"|^"g"$"}}
   n==1&&x&&(i=index($0,"](./")){s=substr($0,i+4);all[substr(s,1,index(s,".md)")-1)];total++}
   n==2&&index($0,d)==1&&/[.]md$/&&!/README.md$/{hit[substr($0,length(d)+1,length($0)-length(d)-3)];next}
   n==2&&!/^[.](agents|claude)\//{m=0;for(i=1;i<=nt;i++)if($0~r[i]){m=split(f[i],a,/, */);for(j in a)hit[a[j]]};if(!m)u=u"unmapped change: "$0"\n"}
   END{split(kept,k,"\n");for(j in k)if(sub(/\/$/,"",k[j])&&sub(/.*\//,"",k[j]))hit[k[j]];for(s in all)if(s in hit)o=o" "s;printf "affected:%s\nskipped: %d of %d features, unchanged since %s\n%s",o,total-split(o,a," "),total,b,u}' $v/features/README.md $v/.cache/changed.txt | tee $v/.cache/affected.txt
   else echo "no commit $b: record every feature"; fi
   ```

2. **Map only: read.** Readers cover every feature in small batches of related features. Return shape: feature summary / source entry points / likely drift or none / proposed recipe. Without subagents, read the groups yourself. Spot-check cited drift and update the files and index. Require concrete source evidence for additions and removals. Preserve expected behavior supported by a request, documented contract or established test. Current code alone does not prove a conflicting expectation is obsolete. Report possible product defects and unresolved expectations instead of writing them into the map as normal behavior. Each recipe keeps its exact setup and fixture cleanup so it runs from the baseline.
3. **Modes that drive: record.** Follow `verify-<app>`'s Isolation, Launch and Doctor sections; when `launch.sh` already runs doctor, do not run it again. Before any recorder starts, look at the app once as a recipe would: run the Baseline's sign-in or open command with `VERIFY_SESSION=main`, take one accessibility snapshot of the main screen, keep only its lines that carry a role and a name in `.agents/skills/verify-<app>/.cache/record/main-screen.txt` and close that session, in one command. For Playwright CLI that is `pw.sh snapshot --filename=<that path>.yml` and `grep -E '^ *- (button|link|menuitem|textbox|heading|tab) "'` of it; for an API, the paths in one `curl` of the OpenAPI document; for a CLI, its `--help`. The snapshot command minus path and filter is the peek command, for Playwright CLI `pw.sh snapshot --filename=`. Right after it, in one command, write `.agents/skills/verify-<app>/.cache/record/brief-common.md` out of the project's files in the shape under Common brief file, so you type none of it out and never read it, run the once-per-run command under Brief files, and run the recorder brief command for every feature. Then give every feature to a recorder, all on that one environment. Recorders at once: <n>. That many recorders run at a time, and fixers the same. `drive.sh`'s `--jobs` does not set it. Raise it for an app that takes more; lower it when browsers fail to start or memory runs out. Start that many in one turn, each with the one-line prompt under Brief files. Each time a recorder returns, start the next feature in the same turn: that one Agent call is all you do per return, with no report read, no index edit and no brief command. Between returns, do nothing: no turn spent waiting, no `date`, no narration. Never paste brief text, report text or feature content into your messages or prompts. Post a progress line, if any, each time that many more recorders have returned. Features that change state other features read, such as global settings, record one at a time after the others have returned, and so does every feature when the Drive section uses `--jobs 1`. Each recorder writes its full report to `.agents/skills/verify-<app>/.cache/record/<feature>/report.md` and returns one line. A recorder that splits its feature records the split-off features itself and names them on that line.

   When every recorder has returned, read the report files of the features whose line shows a split, a difference or a blocker, in one `cat`; never read the others. Act on them:
   - Make the helper changes that reports name as blockers yourself. A missing dependency or setup step that the project documents is yours to fix as well, inside the owned environment. Then send each blocked feature back to a recorder. A prerequisite the project does not document stays blocked: report it.
   - Correct the index entries and change triggers of the features that those reports name as changed, split or blocked: each split-off feature gets its own triggers, and the feature it came from keeps those of the sub-features its file still holds.
   - Before a feature goes back, write the common brief file again, so it carries the changed helpers and an example recipe. Render its brief with the recorder brief command again and append one line on why in the same call: `echo 'Sent back: <reason>' >> .agents/skills/verify-<app>/.cache/record/<feature>/brief.md`. A split-off feature first gets the `contract-map.tsv` and `contract-words.tsv` lines of the feature it came from, under its own name. Its staged file stays, so the new recorder starts from it.
   - Report each Difference as a possible product defect or unresolved expectation.

   Then check for fixture clashes. When the Baseline gives each recipe its own account or data namespace, fixtures cannot clash. Otherwise compare the names lines, read with one `grep -H '^names' .agents/skills/verify-<app>/.cache/record/*/facts.tsv`: when two features create the same account, fixture or resource name, send one of them back to a recorder to rename it. When none goes back, run `bin/rec.sh install`, which moves the staged files that passed into `features/`. In changed-recipes mode, read the Files and Split lines first, in the same call, with `grep -h -e '^- Files' -e '^- Split' .agents/skills/verify-<app>/.cache/record/*/report.md | grep -v -e 'no drift' -e 'none$'`, because install removes the record folders of the features it moves.

## Select what to drive

- **Map only:** go to Ship. No drives.
- **Changed recipes:** select each feature that the recorders' Files or Split lines name as new, or as having a step that is new or whose action, command, expected result, proof or cleanup changed meaningfully. If the baseline or the driving conventions changed since the starting record, select every feature that change affects. Select the refused features the global maintenance skill listed. Wording, formatting, index repairs, unchanged renames and deletions select nothing. If nothing qualifies, run Cleanup and go to Ship.
- **Full audit:** every feature.

`bin/drive.sh --check [feature...]` launches nothing and names each step and missing Contract line of a recipe that needs conversion. A selected feature it names goes to a recorder to be converted before the drive, added to `convert.txt` first; `drive.sh` refuses to run it otherwise. Unselected recipes stay as they are.

Do not treat unselected features as verified.

## Drive the selected features

Follow `verify-<app>`'s Isolation, Launch, Doctor, Drive, When a drive fails, Evidence and Cleanup sections. They set the driver, the isolation level, the deadlines and the failure rules.

Drive from a fresh environment, not from the state the recorders left. Commit the map changes after `bin/rec.sh install` and before this fresh launch, because some Doctors compare the launched revision with `HEAD`; `verify-<app>`'s Doctor section says when this one does. Then run `bin/cleanup.sh`, launch again with `bin/launch.sh` and run `bin/doctor.sh`. Then drive all selected features in one `bin/drive.sh` call, started in the background with its output in `.agents/skills/verify-<app>/.cache/drive.txt`, and do nothing until it finishes: no tailing, no counting lines. Read its summary once, with `sed -n '/^Summary$/,$p'` of that file. Send each failing feature to a fresh fixer: in one call, the fixer brief command under Brief files writes every failing feature's `fix-brief.md` from that summary, and each prompt is the one line there. Read only the line each returns. A feature that fails only at a known product failure, a step that a recorder's Differences or a fixer's line names, needs no fixer. Run fixers the way Update the map step 3 runs recorders, the `Recorders at once` number at a time: each time one returns, start the next failing feature in the same turn, with that Agent call only. Never run them beside your own drive. Fixers of features that change state other features read wait until the other fixers have returned, then run one at a time, and a project that records one feature at a time fixes one at a time as well. When the fixers are done, run `bin/rec.sh install` for the features they repaired, then drive only those features once, the same way, with the output in `.agents/skills/verify-<app>/.cache/drive-2.txt`. That summary, the first one and the fixers' lines are the record of the pass. The report's evidence links come from the last summary of each feature and one `ls -R .agents/skills/verify-<app>/.cache/evidence/`, which lists the saved proof and the step logs.

After an aborted run, clean up its recorded leftovers, create a new environment, drive the features without a result and keep the evidence.

Change an expected result only when there is evidence that the contract changed, never because the app disagrees. A known product failure stays failed.

A step that needs data the baseline lacks gets that data created first, from the project's own APIs, endpoints or documented setup inside the owned environment. "Missing from the seed" is not a reason to block. A step is blocked only when the prerequisite would need a service that is not owned or approved, or setup the project does not have. Name the missing prerequisite and what was tried, and add it to the map.

Every selected feature ends with a result: pass, fail, partial or blocked. Never leave one unattempted. If Doctor fails because of a helper defect, correct it and retry once before reporting the blocker. When a healthy-looking app is wedged, clean up the run's resources and relaunch.

Finish or abort through Cleanup, including when startup or a drive fails. Check that cleanup completed and evidence still exists before reporting.

## Helper briefs

The Recorder and Fixer templates below hold `{{...}}` placeholders; the commands under Brief files copy them out of this skill and fill one brief file per feature. Paths are relative to the repository root.

### Common brief file

The command in Update the map step 3 writes this file from the project's files. Each `[...]` is the content it names, copied as it is.

```
# Common brief for verify-<app> recorders and fixers

## From .agents/skills/verify-<app>/features/README.md

[its Baseline, Driving conventions and Feature file shape sections]

## Helpers, from .agents/skills/verify-<app>/SKILL.md; call them by name, they are on PATH inside a run

[the Helpers section of verify-<app>/SKILL.md, each helper with one call as it appears in a recipe]

## Example recipe, from this project

[Preconditions and the first two steps of the shortest feature file in .agents/skills/verify-<app>/features/ that has at least five steps and that bin/drive.sh --check accepts]

## The app's main screen: the role-and-name lines of an accessibility snapshot taken after the baseline sign-in

[.agents/skills/verify-<app>/.cache/record/main-screen.txt]

## Gotchas, from .agents/skills/verify-<app>/features/README.md

[its Gotchas section, when it has one]
```

When no such feature file exists yet, leave out the Example recipe section, so the Feature file shape stands alone; the common file written before a recorder goes back takes the shortest staged file of at least five steps that passed `rec.sh run`. The file stays under 20,000 bytes, because a larger one overflows the inline tool-output limit. The command that writes it ends with `wc -c` of it; past the limit, cut the main-screen lines to headings, links and tabs first, then the example to Preconditions and one step. Traps found in this run stay out of it: helpers read `traps.md` and `failures.txt` directly.

### Recorder

```
You are a recorder for verify-<app>: you write one feature's recipe and run it against the live app with rec.sh. The app is running; another agent owns its lifecycle.

Repository root: {{root}}; run every command from there. rec.sh is .agents/skills/verify-<app>/bin/rec.sh.
Feature: {{feature}}. Index line: {{index_line}} New: {{new}}. Convert a recipe drive.sh --check refuses: {{convert}}.
Other features: {{other_features}}.
Driving conventions changed in this pass, as diff lines (< removed, > added), a note that they were rewritten, or none:
{{conventions_changed}}

The common file .agents/skills/verify-<app>/.cache/record/brief-common.md holds the project's conventions, helpers, gotchas, main screen and, once it has one, an example recipe. Follow its Driving conventions, copy the example's idioms, and take element names from your peeks, the main-screen snapshot and the example. Read no other skill file, recipe or helper script.

Drive only with <driver>. Call only rec.sh start, peek, run, result and index, for your feature and those you split off, and the helpers in the common file; never drive.sh, rec.sh install, launch.sh, cleanup.sh or doctor.sh. Write only the staged copies rec.sh start names, plus the README index through rec.sh index. Do not commit or push.

Put commands that belong together in one call. Look at screens only with rec.sh peek; never run pw.sh or curl outside rec.sh run and peek. Do not narrate.
1. Contract: run each command below in its own call, nothing else. failures.txt: other recorders' failed steps (feature, step, command, last output line); contract.md, your feature file, then contract sections, large ones as excerpts or not-read lines.
{{read_commands}}
   List every behavior they name: test cases, README sentences, plan acceptance lines, entry points. Each gets a step, and so does every sub-feature and entry point the file lists, or it goes under Blocked. When your only section is the README overview, the list comes from the sub-features and entry points that the source grep and your peek show.
2. Source, one command: one grep for the routes and names the steps target, for drift, or for what excerpts leave out. Your only source read.
3. Write. When the feature is not new, matches contract and source, covers the list and every == line, breaks no changed convention and needs no conversion, change nothing. Otherwise run rec.sh <feature> start and write the Preconditions and Clean up first, into the path it prints. Before the first run, write the steps that reach every screen the recipe will touch, direct URLs, error pages, second tabs and Clean up's first screen included, and look at them in one peek: rec.sh <feature> peek --after '<Label>' --after '<Label>' --find '<locator>' runs Preconditions, those steps and Clean up, snapshotting after each named step to .agents/skills/verify-<app>/.cache/record/<feature>/peek.txt, peek-<n>.txt for the n-th of several. Pass the last screen's locators as --find and fix every !! line: a name from a fixture, plan or source is a guess until a peek shows it, and grep hides repeats and case, so --find is the check; never print a whole snapshot. Then write the whole file at once, its ## Contract section filled from the == lines of contract.md except (mentions), one line each: '- <file>:<heading> → <step labels>' or '- <file>:<heading> → not driven: <reason>'; rec.sh run refuses a copy that skips one. Go to step 4. Keep unchanged steps and Gotchas lines still true; converting adds blocks and changes no check.
4. Run: rec.sh <feature> run is one call and prints the result, attempt <n> first, when the run ends; if your tool returned before that, run rec.sh <feature> result, which waits for the run and prints the same result; never poll, never rerun a run still going. A failure prints the failing step's commands and output end, runs Clean up and ends with: failing step: the step to fix; snapshot: the failing screen, read instead of rerunning; full log: the whole output. Fix and rerun until it prints "passed", and after a failed value check assert the printed value when the contract allows, never a second guess; later edits to prose or Gotchas keep it passed. When the app or a missing prerequisite blocks the recipe, stop: leave the staged file as is, put the failing step, failed command and log path under Blocked, and return the line with blocked.
5. Report, then return its line.

Scope: a behavior one of the other features covers is at most setup here, with no checks of its own; one that fits no feature goes under Split or Blocked. Split: past about 15 steps, write the first coherent group of sub-features here and record each other group yourself as its own feature: rec.sh <split> start, write its file, rec.sh <split> run until it passes, then rec.sh <split> index '- [<Title>](./<split>.md) covers <scope>.' Known failure: a contract the app misses stays in the known-failure step the conventions describe, run with rec.sh <feature> run --known-failure '<Label>'.

Traps: when a rec.sh run attempt fails for a reason another recorder could hit, append one line to .agents/skills/verify-<app>/.cache/record/traps.md in the same call as the fix, with echo '<line>' >>: the trap and its fix, for example "new URL() is not available in run-code; read location.pathname". Never a step-specific locator.

If you cannot finish, remove what your commands created beyond Clean up, and report the passing steps and the blocker.

Report with one Bash call, cat > .agents/skills/verify-<app>/.cache/record/{{feature}}/report.md <<'EOF' … EOF followed by rec.sh <name> facts for your feature and each split you ran, never the file-writing tool, because some hosts refuse a subagent writing report files with it:
- Files: what changed in the staged file and the last run result, or "no drift".
- Differences: each expected result the app misses, with its contract source, what the app did and the step that carries it.
- Split: [name: its sub-features], one line per feature you split off and recorded, or none.
- Blocked: each part you could not drive, with the passing steps, the blocker and what you tried.

Then return only this line:
{{feature}}: no drift|passed|passed with known failure|blocked; <n> steps; <k> attempts (sum of the attempts lines facts printed); split: <names or none>; differences: <count>; blocked: <count>
```

### Fixer

```
You are a fixer for verify-<app>. One recipe failed a drive. Feature: {{feature}}. Failing step: {{label}}. Log: {{log}}.

Repository root: {{root}}; run every command from there. rec.sh is .agents/skills/verify-<app>/bin/rec.sh.

In two calls, read .agents/skills/verify-<app>/.cache/record/brief-common.md and .agents/skills/verify-<app>/.cache/record/{{feature}}/fix-read.md: snapshot path, When a drive fails, traps, the log's end and your Driving section. Follow the common file's Driving conventions. Classify the failure as one of the four kinds in When a drive fails. Read the contract only when the kind depends on it, with: sed -n '/^== /,$p' .agents/skills/verify-<app>/.cache/record/{{feature}}/contract.md

Drive only with <driver>. Call only rec.sh <feature> start, run and result, and the helpers in the common file; never drive.sh, rec.sh install, launch.sh, cleanup.sh or doctor.sh. Edit no helper, SKILL.md, features/README.md or product code, and write no tracked file. Do not commit or push.

When the recipe is wrong, run rec.sh <feature> start, fix the wrong step in the staged copy it names without changing what the step checks or its label, and rerun rec.sh <feature> run (or result, if your tool returned first) until it prints "passed". On a failure it ends with the failing step, a snapshot of the failing screen and the full log; read real names there instead of rerunning, and never print it whole. A known-failure step runs with --known-failure '<Label>'. When the app or a missing prerequisite blocks the fix, stop, leave the staged copy as it is and return the line with the failing step, the exact command that failed and the log path. A product defect, an uncertain expectation, a helper defect or an unhealthy environment changes nothing: name it.

Return one line: <feature>: <kind>: <what you changed, or what is wrong and where>; run: passed, passed with the known failure at "<step>", fail at "<step>", or not run; <k> attempts.
```

### Brief files

Once per run, in the call that writes the common brief file, from the repository root. Replace only the `mode` value, the peek command, the contract sources after `contract_map` and the two `printf` lists: `mode` is `full` in a full audit and `changed` otherwise; the first list with pairs of a feature and its name and index words, as `<word>|<word>`; the second list with `$($v/bin/drive.sh --check <features> 2>&1 | sed -n 's|^drive.sh: features/\(.*\)\.md: .*|\1|p' | sort -u)`, `<features>` being the listed refused features, none in a full audit. A request text goes to `$r/request.md` in the same call, with `printf '%s\t%s\tsection\n' <feature> "$r/request.md:1-\$" >> $r/contract-map.tsv` for each feature it concerns.

A contract section says what one feature should do: `README.md:## Search` is that heading down to the next at its level or above; `test/search.test.ts:40-72` is a `describe`, `it` or `test` line down to the next. Contract sources are the README, docs, plans, tests and specs. `contract_map` maps each line holding a feature's word to the section above it: `section` when the word is in the heading line, else `mention`, whose matching lines alone reach `contract.md`. `contract_bundle` keeps `contract.md` under 20,000 bytes: sections whose heading holds a feature word, other sections, then mentions; a section over 6,000 bytes or the cap becomes an excerpt, and past the cap a `not read` line, still needing its Contract line. With no contract sources beyond a high-level README, replace `contract_map` with `section` rows mapping every feature to the README's overview, such as `README.md:1-40`; recorders then take their behavior list from the source and the screen, and Ship says so.

```
v=.agents/skills/verify-<app>; r=$v/.cache/record
template() { awk -v h="### $1" '$0 == h {s = 1; next} s && /^```/ {if (f) exit; f = 1; next} f' .agents/skills/maintain-verify-<app>/SKILL.md; }
mkdir -p $r && template Recorder > $r/brief-template.md && template Fixer > $r/fix-brief-template.md
printf '%s\t%s\n' <feature> '<word>|<word>' <feature> '<word>|<word>' > $r/contract-words.tsv
. $v/bin/steps.sh && contract_map $r/contract-words.tsv README.md docs/*.md .plans/*.md test/*.test.ts > $r/contract-map.tsv
: > $r/traps.md; : > $r/failures.txt
printf '%s\n' <feature> <feature> > $r/convert.txt
mode=<full or changed>; echo $mode > $r/mode.txt; echo '<peek command>' > $r/peek-command.txt
```

Recorder briefs, from the repository root: in the step 3 call for every feature, and again for each feature that goes back. Only the feature names after `for feature in` change. It prints a line for each feature without an index line or contract sections, and writes each feature's `contract.md`.

```
v=.agents/skills/verify-<app>; r=$v/.cache/record; . $v/bin/steps.sh
export root=$PWD feature index_line other_features new convert read_commands conventions_changed=none
section() { awk '/^## /{p = /^## Driving conventions$/} p' "$1"; }
test -f $v/.cache/starting-README.md && test "$(cat $r/mode.txt)" = changed && conventions_changed=$(diff <(section $v/.cache/starting-README.md) <(section $v/features/README.md) | grep '^[<>]' || echo none)
test $(printf '%s\n' "$conventions_changed" | wc -l) -gt 8 && conventions_changed='the Driving conventions were rewritten; follow the current ones in the common file'
for feature in <feature> <feature>; do
  index_line=$(awk -v f="$feature" '/^## /{p = /^## Features$/} p && index($0, "](./" f ".md)") {print; exit}' $v/features/README.md)
  other_features=$(awk -v f="$feature" '/^## /{p = /^## Features$/} p && (i = index($0, "](./")) {n = substr($0, i + 4); n = substr(n, 1, index(n, ".md)") - 1); if (n != f) o = o (o == "" ? "" : ", ") n} END {print o}' $v/features/README.md)
  new=$(test -f $v/features/$feature.md && echo no || echo yes)
  convert=$(grep -qsx "$feature" $r/convert.txt && echo yes || echo no)
  c=$r/$feature/contract.md h="   cat $r/brief-common.md $r/traps.md $r/failures.txt"
  mkdir -p $r/$feature && contract_bundle $r/contract-words.tsv $r/contract-map.tsv $feature $v/features/$feature.md > $c
  test -n "$index_line" && grep -q '^== ' $c || echo "$feature: no index line or no contract sections"
  read_commands=$(test $($h $c | wc -c) -le 20000 && echo "$h $c" || { echo "$h"; for o in $(seq 1 20000 $(wc -c < $c)); do echo "   tail -c +$o $c | head -c 20000"; done; })
  awk '{o = ""; while (match($0, /[{][{][a-z_]+[}][}]/)) {o = o substr($0, 1, RSTART - 1) ENVIRON[substr($0, RSTART + 2, RLENGTH - 4)]; $0 = substr($0, RSTART + RLENGTH)} print o $0}' $r/brief-template.md > $r/$feature/brief.md
done
```

The whole prompt of each recorder:

```
You are a recorder for verify-<app>. Read <repository root>/.agents/skills/verify-<app>/.cache/record/<feature>/brief.md and do what it says.
```

Fixer briefs, the same way, once for every failing feature. It takes each feature's failing step and log from the drive summary in `.cache/drive.txt` and prints a line for each feature the summary shows no failure for.

```
v=.agents/skills/verify-<app>; r=$v/.cache/record; . $v/bin/steps.sh
export root=$PWD feature label log
for feature in <feature> <feature>; do
  IFS=$'\t' read -r label log < <(awk -v p="$feature: fail at \"" 'index($0, p) == 1 {s = substr($0, length(p) + 1); i = index(s, "\" ("); print substr(s, 1, i - 1) "\t" substr(s, i + 3, length(s) - i - 3)}' $v/.cache/drive.txt)
  test -n "$log" || echo "$feature: no failure in the drive summary"
  mkdir -p $r/$feature && fix_read "$log" $v/features/$feature.md $r/traps.md $v/SKILL.md > $r/$feature/fix-read.md && awk '{o = ""; while (match($0, /[{][{][a-z_]+[}][}]/)) {o = o substr($0, 1, RSTART - 1) ENVIRON[substr($0, RSTART + 2, RLENGTH - 4)]; $0 = substr($0, RSTART + RLENGTH)} print o $0}' $r/fix-brief-template.md > $r/$feature/fix-brief.md
done
```

The whole prompt of each fixer:

```
You are a fixer for verify-<app>. Read <repository root>/.agents/skills/verify-<app>/.cache/record/<feature>/fix-brief.md and do what it says.
```

## Ship

Follow the repository's branch, commit and PR conventions as you edit. Keep all corrections in one branch and PR. In the modes that drive, commit the rest, then write `git rev-parse HEAD` to `features/last-reviewed` and commit it alone, so the next diff skips this pass's edits. When `.agents/skills/verify-<app>/.cache/record/traps.md` has lines, read it once and fold the lines that still hold into the `## Gotchas` list of `features/README.md` in one edit, creating that section after Driving conventions when it is missing. Re-read the files you changed before shipping. Report the outcome separately from the step results:

- **clean:** every selected feature has a result and there were no corrections; the PR, if any, holds only `last-reviewed`. This does not mean every product check passed.
- **changed:** every selected feature has a result and corrections shipped in one PR.
- **incomplete:** cleanup failed, corrections could not ship safely, or selected features have no result or are blocked. Name each such feature and why.

Put the report in the final message. Name the mode and summarize additions, removals, corrections, unresolved expectations and helper problems.

- **Map only:** say `Source-reviewed; no live drives run`.
- **Changed recipes:** list each selected feature with the map change that selected it. Say how many features were not driven, and give the `skipped` and `unmapped change` lines of `.cache/affected.txt`. If none qualified, say no drives were needed.
- **Full audit:** report every feature.

When the contract map listed only the README overview, say that every expectation in the map is the behavior observed on this date, to be questioned by whoever changes that area, because nothing in the run could tell a bug from an intention. Give each selected feature's result. List each feature's `not driven` contract lines, from one `grep -H ' → not driven: ' .agents/skills/verify-<app>/features/*.md`. Name every feature that did not pass, with the step and its reason: blocked (what was tried, and the kept `.cache/record/<feature>/` folder), failed or partial. List each known product failure with its feature, the step that carries it and the contract it misses. Follow `verify-<app>`'s Report section for omissions, evidence links, classified findings and the cleanup result. When `usage-report` is on `PATH`, end the report with the output of `usage-report --cwd <repository> --since <today>`, with the repository's absolute path and today's date as `YYYY-MM-DD`.

Keep working notes under `.agents/skills/verify-<app>/.cache/`, never in tracked files. Remove them during cleanup, except each blocked feature's `.cache/record/<feature>/`, whose staged file the next pass starts from; the evidence stays.
