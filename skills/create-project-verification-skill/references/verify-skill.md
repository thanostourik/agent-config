---
name: verify-<app>
description: "Drive <app> end to end to prove a change works: drive the features a change affects, write or fix their recipes, or drive every feature. Use before calling any work on <app> done, and when asked to verify, test end to end or record a feature. /verify-<app> full drives every feature, repairs the failing ones and records what no recipe covers."
---

# Verify <app>

The user explicitly requests the drivers that `PROJECT.md` names for every step of this
skill, including runs you start yourself. Do not use the host's integrated browser, preview
or computer-use tools. If a driver breaks, repair it or report a blocker; do not switch
drivers. The one exception is a step that needs the user watching, such as a manual login:
ask first, then return to the driver.

This file is shipped by `create-project-verification-skill` and is replaced on upgrade. The
project's own facts are in `PROJECT.md`: read it once before your first command. Run every
command from the repository root. `verify` below is `.agents/skills/verify-<app>/bin/verify`,
and other paths are relative to `.agents/skills/verify-<app>/`.

## Modes

- `/verify-<app>` (default): [Check a change](#check-a-change).
- `/verify-<app> full`: [Full](#full): drive every feature, repair the failing ones, and
  record what no recipe covers.

Honor an equivalent request, such as "update the verification map" for `full`.

## Check a change

At isolation level `checks-only` there is no live drive: run the focused checks `PROJECT.md`
names, and report every feature `blocked: no isolation`. Otherwise:

1. When the code is ready, run `verify up`. It reuses the run's environment when it is
   already up and restarts only the app. Keep it up for the whole task, and run `verify up`
   again after every code change, before driving: the app runs the code it started with.
2. Bring the recipes in line with the change, as part of the change, like tests. For
   behavior the change adds, alters or removes, write or edit `features/<feature>.sh`
   ([Recipes](#recipes)). Before writing a step, open its screen once in a session of your
   own (`VERIFY_SESSION=<feature>-probe`) and save its snapshot (`bin/pw.sh snapshot`), and
   call the API once for each record a step checks: write locators from the snapshot and
   checks from the response, not from the source. A whole new feature can go to a recorder
   ([Recorders](#recorders)).
3. Run `verify affected`. It drives the features whose `# touches:` line names a changed
   file, or a file that names a changed code file by its file name (one level of callers),
   or whose recipe or helper changed, then prints one summary line per feature with the
   file that selected it. Each feature's line also prints the moment it finishes, as
   `[<done>/<total>] <line>`, so a long drive shows its progress.
4. It also lists the entry points and actions (`bin/actions.sh`) in changed files that no
   recipe covers: new screens, routes, buttons and handlers the change added, and fails
   while that list is not empty, even when every driven feature passed. Give each a
   step and an `# expects:` line, in the feature it belongs to or a new one (for a whole
   new screen, a recorder), or an `# expects:` line marked not driven with its reason, and
   drive those features. It also lists changed files no feature names. For each one that changes behavior a
   feature covers, drive that feature by name (`verify <feature>`) and add the file to
   its `# touches:` line. Skip files that change no behavior: tests, docs, build files.
   The caller search sees only code that names a changed file. If the change alters
   behavior reached another way, such as through an interface, an event, a framework that
   wires classes by type, or more than one call away, find the features that use it with
   `verify list` and drive them by name.
5. A failure: the summary line names the step and the failing command. Open the log only
   when that line is not enough. Classify it ([When a drive fails](#when-a-drive-fails)),
   fix it, and rerun only that feature.
6. At the end of the task, also after a failure, run `verify down`.

Do not drive features the change cannot affect. Run `verify all` only when the user asks,
after an upgrade of this skill, or when a change touches what every feature uses (launch,
sign-in, a shared helper) and you cannot name fewer features.

## Full

1. Run `bin/areas > .cache/areas.txt`, and rerun `bin/harvest` into `.cache/expect/` for
   each area whose tests or docs changed, so `verify lint` names the behaviors its recipes
   no longer cite.
2. Run `verify all`, which brings the run up on the production build, and
   `verify uncovered`, which lists every entry point, action and expectation line no recipe
   covers.
3. Start a recorder for each area that holds a failing feature or an uncovered item, all at
   once ([Recorders](#recorders)), and give it the summary lines of its failing features. A
   failing recipe is repaired, or its product defect marked `# known failure:`. An
   uncovered item gets a step, or an `# expects:` line marked not driven with its reason.
4. When every recorder has written its result file, run `verify uncovered` again: it lists
   nothing. Then `verify down`, commit, and report the features added, the features
   repaired, and each product defect.

A drive can outlast your command timeout. Run `verify` the way your harness runs background
commands. Wait until it finishes, then read its output once. Do not poll it or tail its logs.

## Commands

- `verify up` / `verify down`: start or reuse, and remove, the run's environment.
- `verify affected [--dry] [--base <ref>]`: select and drive; `--dry` only selects. It
  exits 1 while the change adds entry points or actions no recipe covers.
- `verify <feature>...`: drive those features on the run's environment.
- `verify all`: drive every feature on the production build. It brings the run up on that
  build first, and removes a run on the dev server before that.
- `--jobs N` (default: the skill's `jobs` file, else the machine's cores) and `--deadline SECONDS` per feature (default 180) go anywhere.
- Every `verify` on the machine, from every project and thread, shares one queue: a
  feature's run starts only while 20% of memory stays free, and one always runs. The user sets another share with `VERIFY_RESERVE=<percent>` or the
  file `~/.config/verify/reserve`. A summary line with `waiting for room` says how long
  feature runs waited; a pass's time is its own.
- `verify room`: wait until the machine has room for one more browser session or process.
- `verify list`: every feature with its one-line summary. This is the feature map.
- `verify lint [feature...]`: the recipe rules the runner enforces.
- Lanes are extra copies of the environment for `# alone` features, which take them from
  one queue, longest first. A drive starts lanes itself, up to the skill's `lanes` file,
  when its `# alone` features take at least twice as long as a copy takes to start and the
  copy fits beside the reserve. `verify up --lanes N` keeps exactly N.
- `verify uncovered [area]`: entry points (routes, screens, commands) no feature's `# covers:`
  names, with the count covered; actions `bin/actions.sh` prints that no `# expects:` line
  cites by file and name; and lines of an area's expectation list (`.cache/expect/<area>.txt`)
  no recipe of that area cites. With an area of `.cache/areas.txt`, only that area's.
- In a companion repo, `apps` lists the app checkouts. `APP_<NAME>=<path> verify ...`
  drives another checkout of that app, such as a worktree.

## Recipes

A feature is one user-facing capability: a screen, a route group, a command, an endpoint
group, a job. Its recipe is `features/<feature>.sh`, a bash script that `verify` runs
under `set -euo pipefail` from the repository root, with `bin/` on `PATH` and, when it
exists, `bin/env.sh` sourced first for the run's values (base URLs, ports, keys):

```bash
# Create a note from the browser, and confirm it is saved.
# touches: web/src/NoteEditor.tsx server/routes/notes.ts
# covers: /notes/new, POST /api/notes
# expects: a new note opens an empty editor (web/test/editor.test.ts: opens blank) -> Open editor
# expects: a saved note is stored with its title (README.md: ## Notes) -> Save note
# expects: a blank title is refused (web/test/editor.test.ts: rejects blank title) -> not driven: the form blocks the submit natively

cleanup() { notes delete --prefix verify-create-note- || true; }

step "Open editor" "Choose New note; an empty Note editor form opens."
pw.sh run-code "async page => { await page.getByRole('button', { name: 'New note' }).click(); await page.getByRole('form', { name: 'Note editor' }).waitFor(); }"

step "Save note" "Enter a title and choose Save note; the note is stored with that title."
pw.sh run-code "async page => { await page.getByRole('textbox', { name: 'Title' }).fill('verify-create-note-1'); await page.getByRole('button', { name: 'Save note' }).click(); }"
wait_for 10 api GET /notes?title=verify-create-note-1
```

- The header is `#` lines, ended by a blank line. Line 1: `# <what the feature lets a user
  do>`. Then `# touches:` and the source files the feature's behavior lives in (routes,
  handlers, components, services, queries, migrations of its tables), as repository paths,
  `<app>/<path>` in a companion repo. Files, never folders; several `# touches:` lines are
  fine. Leave out files every feature only passes through, such as bootstrap code or shared
  config; a file that holds this feature's routes or handlers belongs in, even when other
  features' are there too.
- `# covers:` the entry points the recipe drives, comma-separated, written exactly as
  `bin/entrypoints.sh` prints them (such as `POST /api/notes, /notes/[id]`).
- `# expects: <behavior> (<source>) -> <step label>` once for every behavior the docs, the
  tests or the request state for this feature: what it does, its errors, limits and side
  effects. `<source>` is the line from the feature's or its area's expectation list in
  `.cache/expect/` without its `- `, such as `web/test/editor.test.ts: opens blank` or
  `README.md: ## Notes`; a behavior taken from the source code cites its file and the
  function, as `<file name>: <function>` (`NoteEditor.tsx: handleSave`), because
  `verify uncovered` counts an action covered only when a line names both. Several labels are joined by `, `. A behavior the run cannot
  reach gets `-> not driven: <reason>`. `verify lint` refuses a line whose step does not
  exist, and, while `.cache/expect/<feature>.txt` exists, a recipe that leaves any of its
  listed tests or headings uncited. Read
  the feature's tests and docs for these lines before writing steps; they are the recipe's
  depth. Then take the rest from the source, always: each field and its validation message,
  each error response, each permission rule (who may, and who is refused), each empty,
  loading and limit state, and each side effect (row, mail, file, event) in the feature's
  files is a behavior with its own `# expects:` line.
- Optional header lines: `# shares: <group>: <the shared state it changes>` when the feature
  changes state that only some other features also change or read, such as the one active API key
  or one global setting: features of the same group take turns, while every other feature
  runs beside them; `# alone: <the shared state it changes>` when every other feature would
  break meanwhile, such as a clock change or a service restart, so it runs by itself; `# deadline: <seconds>` when the whole feature
  needs longer than 180 s; `# known failure: <step label>` for a product defect already
  reported, so its failure reads `known failure at "<step label>"`: report that line as it
  is, with no new diagnosis.
- The feature name is the file name. It is never a `verify` command: `up`, `down`, `list`,
  `lint`, `uncovered`, `affected`, `all`, `help`.
- `step "<label>" "<what it proves>"` before each user action: the second argument is one
  sentence with the action and its expected result. A failing step's summary line repeats
  it, so whoever repairs the recipe knows what the step was meant to prove. Every step ends with a check that exits non-zero
  when the result is wrong: `test`, `jq -e`, `grep -q` on a saved file, the driver's own
  assertion. A command that only prints proves nothing. Under `set -e`, `! command` never
  fails: use `test` or `if`.
- Wait for state with `wait_for <seconds> <command...>` or the driver's own waits, 10 s at
  most; `run-code` waits 10 s by default. A simple action, such as a save, that needs longer
  is a finding to report, not a longer wait. Only a step that waits for slow work by design,
  such as a background job, waits longer, with `# slow: <reason>` (`// slow: <reason>` inside
  JavaScript) on that line; `verify lint` refuses any other wait over 10 s, and a pass names
  its steps over 10 s. Never `sleep` or `waitForTimeout`.
- Save proof to `$EVIDENCE/`: a screenshot or snapshot for a UI, the response or output
  otherwise. On a failure, `bin/observe.sh` saves the app's state there.
- Every name the recipe creates starts with `verify-<feature>-`, dash included, or the
  closest the app's naming rules allow (such as `VERIFY-ITEMS-1`), so features running at
  once never collide. Cleanup matches that whole prefix, dash included. A feature name never
  starts another feature's name followed by a dash (`ingestion` and `ingestion-sources`):
  `verify-ingestion-` also matches `verify-ingestion-sources-1`, so one cleanup would
  delete the other's data. `verify lint` refuses such a pair.
  The recipe creates its own data; it never relies on another feature. When leftovers of an
  interrupted run would break a check, call `cleanup` once before creating data.
- `cleanup()` removes what the recipe created, found by its `verify-<feature>-` prefix or
  by ids the recipe saved, never "everything this account can list": an admin account lists
  every feature's data. It always runs, after a failure too. `|| true`
  goes only on a delete whose failure cannot matter.
- Other features run at the same time on the same environment. Never assume shared state,
  such as a global counter, a job queue or a list of every user's rows, is quiet: check only
  what this recipe created. Give the feature its own tenant, account, key or workspace
  before marking it `# shares` or `# alone`.
- Never wait for real time. A job interval, retry delay, rate-limit window or expiry that
  takes longer than a few seconds is shortened in the run's environment (`PROJECT.md` says
  how), never waited out. Never turn a behavior off to make a recipe faster or pass.
- Use a fresh identifier instead of waiting for a window to reset: a rate limit or quota
  counts per key, account or caller, so take a new one. Check whether a wait is needed
  before waiting.
- Do a multi-step UI action in one driver call (one Playwright `run-code` with several
  actions and their waits): every call costs about a second. Never use the Playwright CLI's
  `click` or `press`: each waits 6 to 10 s for the network to go quiet.
- Wait for an event, never a margin: to prove a job left something alone, add an old probe
  item and stop waiting when the job removes it.
- A check that something is gone first waits for the dialog or menu that removed it to
  close, then checks that a neighbor the action left alone is visible and the item is
  absent. While a dialog is open or closing, the page behind it is hidden from role
  queries, so a wait for `detached` or `hidden` passes at once, while the item is still on screen.
- Make a race impossible instead of racing it: when a job would remove state a step still
  needs, hold that state through a stub mode or the recipe's own data, not a slower job.
- A save step fills every field the form offers (each input, select, toggle and list
  entry), not only the required ones, with values unlike the defaults. Then reload the page
  or read the record back and check each field, not only the success message: a field the
  app forgets to save shows only after a reload, and only when the step set it.
- Exercise the real user path, not test-only endpoints or internal setters. Check side
  effects (rows, files, messages) next to what is visible. Administrative setup is fine,
  but never in place of the user action being proved.
- At most about 15 steps, and a pass in 45 s or less: the runner marks a slower pass
  `slow`. A bigger or slower feature is two features: the slowest feature sets the end of
  every full drive. A feature's run waits in the machine's queue before its clock starts,
  so the time a pass shows is its own.
- Use stable handles: roles and accessible names, data attributes, routes, prompt strings.
  Never coordinates or tab order. The helper calls and traps of this project are in
  `PROJECT.md`.

## Recorders

A recorder is a helper agent that writes the recipes of one area, a line of
`.cache/areas.txt`: a screen or a few that share setup, about 1,000 lines of source. Start one per area, all at once: their feature runs wait in the machine's queue. When the host
refuses one, start it again when another returns; with no helper agents at all, record the
features yourself. Give each this short prompt, with the paths and features filled in:

```
You are a recorder for verify-<app>. Follow the recorder prompt in the Recorders section of
<absolute path>/.agents/skills/verify-<app>/SKILL.md, with the repository root
<absolute path>, the example recipe features/<example>.sh, and the area <area> of
.agents/skills/verify-<app>/.cache/areas.txt.
```

The recorder prompt, which the short prompt points to:

```
You record end-to-end recipes for verify-<app>. The repository root is <absolute path>; run
every command from there, and read nothing outside it except the generator's files it
names: another checkout's recipes are not this project's. Read
.agents/skills/verify-<app>/SKILL.md (sections Recipes and When a drive fails),
.agents/skills/verify-<app>/PROJECT.md, the example recipe
.agents/skills/verify-<app>/features/<example>.sh, and your area's expectation list
.agents/skills/verify-<app>/.cache/expect/<area>.txt. Then read every file of your area
and first write its inventory, .agents/skills/verify-<app>/.cache/behaviors/<area>.txt: one
line per behavior the source states, never merged: each field and its validation message,
each button and what it does, each state (empty, loading, filtered, paging, editing,
error), each error response the screen handles, each permission rule, each side effect.
Split the inventory into features of 8 to 15 steps by user goal, one behavior per step
where it can be driven on its own, named <area>-<goal>; a recipe of your area that
already exists is one of them. Then look at the real app before writing: open each screen
of your area once in a browser session of your own (VERIFY_SESSION=<area>-probe), signed
in as the role that uses it, and save its accessibility snapshot (bin/pw.sh snapshot), with
each of its dialogs and menus open, under .agents/skills/verify-<app>/.cache/snapshots/<area>/;
and call the API once (bin/api.sh or the project's API helper) for each record a step will
check. Write every locator from those snapshots and every check against those responses:
names and response shapes read from the source alone are often wrong. The snapshots never shrink the inventory: a behavior they do not show, such as an
error, an empty state or a refused permission, keeps its line. Write all your recipes,
.agents/skills/verify-<app>/features/<feature>.sh, with one '# expects:' line per
inventory line, before driving any. A behavior whose data cannot be made through the app,
its API or a documented helper within a few minutes is marked not driven with that
reason. Then drive them together once,
.agents/skills/verify-<app>/bin/verify <feature> <feature> ..., and fix the failing ones
together, with small edits rather than rewriting a recipe; after that drive only the
recipes you edited, together, until each passes: every feature run waits in one queue
for the whole machine, and driving the whole area after each edit fills it. When the pass is marked slow, read the slowest calls in its pw-calls.log or step
times once and remove what is plainly avoidable; spend no further runs on speed. Before the last drive, run
.agents/skills/verify-<app>/bin/verify uncovered <area>: it lists your area's entry
points, actions and expectation lines no recipe covers; cover each with a step, or an
'# expects:' line marked not driven with its reason, until it lists none. Last, run your features once together with three others that already have a
result file in .agents/skills/verify-<app>/.cache/results/ (all of them when fewer exist)
(bin/verify <yours> <others>), because every drive runs features in parallel: check only
data your recipe created. A step label never contains a comma. The environment is
already up and shared: never run verify up, down or all, launch.sh, cleanup.sh or anything
that stops containers or closes browser sessions other than your own feature's. Never
restart or reconfigure a shared service by hand, even to explore: only a recipe marked
'# alone' does that, through bin/verify, which keeps other drives off the copy meanwhile. Stop a feature after 5 runs, and report it
blocked with its last summary line. A defect in a helper: fix it when the fix is small and
cannot break other features, by writing a copy and moving it over the helper with mv (other
drives are running it, and bash reads a script while it runs), and name it in your result
line; otherwise report
blocked: helper <name>: <defect>. Behavior another feature covers is setup here, with no
checks of its own. Return one line per feature: passed, product defect: <what>, or
blocked: <reason>. For a product defect, add '# known failure: <step label>' to the recipe's
header. Never weaken or drop a check to get past a product defect: checking only the
response when the stored result is wrong hides the defect; keep the check, last in its
step, and mark it. While iterating, drive only your own features. Edit only your own recipes: no git
branch, commit or stash, and no edit to PROJECT.md. Run each drive in the foreground and
read its summary; never end your turn while a drive runs. Data you make by hand while
exploring is named verify-<area>-probe-..., and you delete it by that prefix only; a
browser session you open by hand is VERIFY_SESSION=<area>-probe, because recorders that
all named theirs probe closed each other's browsers. Close
every browser session and stop every process you open by hand as soon as you are done
with it: an open one holds memory the other recorders' drives wait for. Stop every process your
attempts started. As your last action, write those lines, and one line per trap that cost
you a run for PROJECT.md's Gotchas, to
.agents/skills/verify-<app>/.cache/results/<area>.txt (through a temporary file
and mv), then return the same lines.
Area: <area>: <n> lines; entry points: <...>; files: <...>
(with the short prompt: the area's line in .agents/skills/verify-<app>/.cache/areas.txt)
```

When a result file appears, with or without the host's completion notice, read only its
lines. Add their traps to `PROJECT.md`'s Gotchas when they
hold for other features.

## When a drive fails

Record the action, the expected result and its basis (the request, a documented contract
or a test), and the actual result. Diagnose before fixing. The failure is one of:

- **Recipe or helper defect:** a command, locator or wait is wrong. Fix it without changing
  the expected behavior, and rerun the feature.
- **Environment defect or missing prerequisite:** create what is missing with the project's
  own APIs or setup, inside the run's environment. Missing seed data is not a blocker.
- **Product defect:** the app contradicts supported expected behavior. Fix the code when it
  is part of the task. Otherwise report it, leave the recipe failing, and add
  `# known failure: <step label>` to its header. Put that check last, so it hides no other.
- **Uncertain expectation:** report what you saw and the decision that is missing. Never
  rewrite an expectation just to pass.

When `doctor.sh` fails after a feature, the runner stops starting features. Fix the
environment, or run `verify down` and `verify up`, then rerun what did not run.

## Isolation

Follow `PROJECT.md`'s Isolation section. Verification never touches what the developer uses:
their running services, data, sessions and configuration. Never attach to, change, reset or
stop anything the run did not create. An occupied resource the run needs is a blocker.
At level `shared`, pass `--jobs 1` and write only to fixtures named `verify-<feature>`.

## Report

Start from the summary lines. One line per driven feature: **pass**, **fail** (with the step
and the failure kind), or **blocked** (with what was tried). Name the changed files you
skipped and why. Link evidence with Markdown links to absolute paths, and check that each
linked file exists after `verify down`. Report a failed `verify down` separately: a
passing feature does not mean cleanup succeeded. For isolation level `shared`, label the
report `lower confidence: shared <resources>`.
