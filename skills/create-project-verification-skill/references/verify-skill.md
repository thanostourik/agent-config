---
name: verify-<app>
description: "Use before calling any work on <app> done, and when asked to verify <app>, test it end to end, record its features, or run /verify-<app> full."
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

## Words used here

- **Feature:** one thing a user can do: a screen, a route group, a command, a job.
  **Recipe:** the bash script `features/<feature>.sh` that drives one feature.
- **Drive:** run recipes against the live app. `verify all` drives every feature at once.
- **Run's environment:** the app and services this skill starts for itself, from `verify up`
  to `verify down`. **Lanes** are extra copies of it for features marked `# alone`.
- **Summary line:** the one line `verify` prints per feature: a pass with its time, or the
  step, command and error where it failed.
- **Recorder:** a subagent that writes the recipes of one area of the app.

## Modes

- `/verify-<app>` (default): [Check a change](#check-a-change).
- `/verify-<app> full`: [Full](#full): drive every feature, repair the failing ones, and
  record what no recipe covers.

A request with the same meaning, such as "update the verification map" for `full`, picks the
same mode.

## Check a change

At isolation level `checks-only` there is no live drive: run the focused checks `PROJECT.md`
names, and report every feature `blocked: no isolation`. Otherwise:

1. When the code is ready, run `verify up`. It reuses the run's environment when it is
   already up and restarts only the app. Keep it up for the whole task, and run `verify up`
   again after every code change, before driving: the app runs the code it started with.
2. Bring the recipes in line with the change, as part of the change, like tests. For
   behavior the change adds, alters or removes, write or edit `features/<feature>.sh` as
   [Recipes](#recipes) says. A whole new feature can go to a recorder
   ([Recorders](#recorders)).
3. Run `verify affected`. It drives the features whose `# touches:` line names a changed
   file, or a file that names a changed code file by its file name (one level of callers),
   or whose recipe or helper changed. Each feature's summary line prints as soon as it
   finishes, as `[<done>/<total>] <line>`, with the file that selected it.
4. `verify affected` also prints two lists:
   - Entry points and actions (`bin/actions.sh`) in changed files that no recipe covers:
     the screens, routes, buttons and handlers the change added. It fails while this list is
     not empty, even when every driven feature passed. Give each a step and an `# expects:`
     line, in the feature it belongs to or a new one (a whole new screen can go to a
     recorder), or an `# expects:` line marked not driven with its reason. Then drive those
     features.
   - Changed files no feature names. For each one that changes behavior a feature covers,
     drive that feature by name (`verify <feature>`) and add the file to its `# touches:`
     line. Skip files that change no behavior: tests, docs, build files.

   The selection sees only code that names a changed file. When the change reaches behavior
   another way, such as through an interface, an event, a framework that wires classes by
   type, or a call more than one step away, find the features that use it with
   `verify list` and drive them by name.
5. On a failure, open the log only when the summary line is not enough. Classify it
   ([When a drive fails](#when-a-drive-fails)), fix it, and rerun only that feature.
6. When the change wrote or edited a recipe or a helper it calls, run `verify all` once
   after it passes, with no `--jobs` (see [Done](#done)).
7. At the end of the task, also after a failure, run `verify down`.

Do not drive features the change cannot affect. Run `verify all` only when the user asks,
after an upgrade of this skill, when the change wrote or edited a recipe or a helper, or
when a change touches what every feature uses (launch, sign-in, a shared helper) and you
cannot name fewer features.

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
4. When every recorder has written its result file, run `verify all` again, with no
   `--jobs`. Send each new or repaired feature that neither passes nor fails at its known
   failure back to its recorder with its summary line, and repeat. Then run
   `verify uncovered`: it lists nothing. Then `verify down`, commit, and report the
   features added, the features repaired, and each product defect.

A drive can outlast your command timeout. Run `verify` the way your harness runs background
commands. Wait until it finishes, then read its output once. Do not poll it or tail its logs.

## Commands

- `verify up` / `verify down`: start or reuse, and remove, the run's environment. The run's
  environment runs the app on its dev server unless the first `verify up` set
  `VERIFY_APP=build`.
- `verify affected [--dry] [--base <ref>]`: select and drive; `--dry` only selects. It
  exits 1 while the change adds entry points or actions no recipe covers.
- `verify <feature>...`: drive those features on the run's environment.
- `verify all`: drive every feature on the production build. It brings the run up on that
  build first, and removes a run on the dev server before that.
- `--jobs N` (default: the skill's `jobs` file, else the machine's cores) and
  `--deadline SECONDS` per feature (default 180) go anywhere.
- Every `verify` on the machine, from every project and thread, shares one queue. A feature
  starts only while the reserve, 20% of memory by default, stays free, and one always runs.
  The user sets another reserve with `VERIFY_RESERVE=<percent>` or the file
  `~/.config/verify/reserve`. A summary
  line with `waiting for room` says how long features waited; the time a pass shows does
  not include that wait.
- `verify room`: wait until the machine has room for one more browser session or process.
- `verify list`: every feature with its one-line summary.
- `verify lint [feature...]`: check the recipe rules the runner enforces.
- Lanes run on the production build. `# alone` features take them from one queue, longest
  first. A drive starts lanes itself, up to the number in the skill's `lanes` file, when its
  `# alone` features take at least twice as long as a copy takes to start and the copy fits
  in memory beside the reserve. `verify up --lanes N` keeps exactly N.
- `verify uncovered [area]`: entry points (routes, screens, commands) no feature's `# covers:`
  names, with the count covered; actions `bin/actions.sh` prints that no `# expects:` line
  cites by file and name; and lines of an area's expectation list (`.cache/expect/<area>.txt`)
  no recipe of that area cites. With an area of `.cache/areas.txt`, only that area's.
- In a companion repo, `apps` lists the app checkouts. `APP_<NAME>=<path> verify ...`
  drives another checkout of that app, such as a worktree.

## Recipes

`verify` runs each recipe under `set -euo pipefail` from the repository root, with `bin/` on
`PATH` and, when it exists, `bin/env.sh` sourced first for the run's values (base URLs,
ports, keys):

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

`verify lint` checks the format. The rules below are about what goes in it.

### Header

- Line 1 says what the feature lets a user do.
- `# touches:` lists the source files the feature's behavior lives in (routes, handlers,
  components, services, queries, migrations of its tables), as repository paths,
  `<app>/<path>` in a companion repo. Files, never folders; several `# touches:` lines are
  fine. Leave out files every feature only passes through, such as bootstrap code or shared
  config; a file that holds this feature's routes or handlers belongs in, even when other
  features' are there too.
- `# covers:` lists the entry points the recipe drives, comma-separated, written exactly as
  `bin/entrypoints.sh` prints them (such as `POST /api/notes, /notes/[id]`).
- `# expects: <behavior> (<source>) -> <step label>` comes once for every behavior the docs,
  the tests or the request state for this feature: what it does, its errors, limits and
  side effects. `<source>` is the line from the feature's or its area's expectation list in
  `.cache/expect/` without its `- `, such as `web/test/editor.test.ts: opens blank` or
  `README.md: ## Notes`. A behavior taken from the source code cites its file and function,
  as `<file name>: <function>` (`NoteEditor.tsx: handleSave`): `verify uncovered` counts an
  action covered only when a line names both. Join several labels with `, `. A behavior the
  run cannot reach, such as one whose data cannot be made through the app, its API or a
  documented helper, gets `-> not driven: <reason>`.
- Read the feature's tests and docs for these lines before writing steps; they are the
  recipe's depth. Then always take the rest from the source, one behavior per line, never
  merged: each field and its validation message, each button and what it does, each state
  (empty, loading, filtered, paging, editing, error, limit), each error response, each
  permission rule (who may, and who is refused), and each side effect (row, mail, file,
  event) in the feature's files.
- Behavior another feature covers is setup here, with no checks of its own.
- Optional lines:
  - `# shares: <group>: <the shared state it changes>` when the feature changes state that
    only some other features also change or read, such as the one active API key or one
    global setting. Features of the same group take turns; every other feature runs beside
    them.
  - `# alone: <the shared state it changes>` when every other feature would break
    meanwhile, such as a clock change or a service restart. The feature runs by itself.
  - `# deadline: <seconds>` when the whole feature needs longer than 180 s.
  - `# known failure: <step label>` for a product defect already reported. Its failure then
    reads `known failure at "<step label>"`: report that line as it is, with no new
    diagnosis.

  First give the feature its own tenant, account, key, workspace, schema, prefix or data
  folder. Mark it `# shares` or `# alone` only when the clash remains.

### Steps

- Write each locator from a snapshot of the real screen and each check from one real API
  response, never from the source alone: names and response shapes read from the source are
  often wrong. Open the screen once in a browser session of your own, named
  `VERIFY_SESSION=<feature>-probe` (a recorder uses `<area>-probe`), and save its snapshot
  (`bin/pw.sh snapshot`) with each of its dialogs and menus open. A behavior the snapshot
  does not show, such as an error, an empty state or a refused permission, keeps its
  `# expects:` line.
- `step "<label>" "<what it proves>"` comes before each user action. The second argument is
  one sentence with the action and its expected result; a failing step's summary line
  repeats it, so whoever repairs the recipe knows what the step was meant to prove.
- Every step ends with a check that exits non-zero when the result is wrong: `test`,
  `jq -e`, `grep -q` on a saved file, the driver's own assertion. A command that only prints
  proves nothing. Under `set -e`, `! command` never fails: use `test` or `if`.
- Exercise the real user path, not test-only endpoints or internal setters. Check side
  effects (rows, files, messages) next to what is visible. Administrative setup is fine,
  but never in place of the user action being proved.
- A save step fills every field the form offers (each input, select, toggle and list
  entry), not only the required ones, with values unlike the defaults. Then reload the page
  or read the record back and check each field, not only the success message: a field the
  app forgets to save shows only after a reload, and only when the step set it.
- A check that something is gone first waits for the dialog or menu that removed it to
  close, then checks that a neighbor the action left alone is visible and the item is
  absent. While a dialog is open or closing, the page behind it is hidden from role
  queries, so a wait for `detached` or `hidden` passes at once, while the item is still on
  screen.
- Do a multi-step UI action in one driver call (one Playwright `run-code` with several
  actions and their waits): every call costs about a second. Act through `run-code` only:
  the Playwright CLI's `click` and `press` wait 6 to 10 s for the network to go quiet, and
  do not wait for the element.
- Use stable handles: roles and accessible names, data attributes, routes, prompt strings.
  Never coordinates or tab order. The helper calls and traps of this project are in
  `PROJECT.md`.
- Save proof to `$EVIDENCE/`: a screenshot or snapshot for a UI, the response or output
  otherwise. On a failure, `bin/observe.sh` saves the app's state there.

### Waits and errors

These rules hold for recipes and for every helper in `bin/`.

- Size every wait for a busy machine, never an idle one: in `verify all` every feature runs
  at once, and a step can take many times its time alone. Wait for state with
  `wait_for <seconds> <command...>` or the driver's own waits, 30 s at most; `run-code`
  waits 30 s by default.
- A simple action, such as a save, that takes over 10 s in a drive of a few features is a
  finding to report, not a reason for a longer wait. A pass line names its steps over 10 s.
- Only a step that waits for slow work by design, such as a background job, a report over
  production-sized data, a restart or the first page after a restart, waits longer, with
  `# slow: <reason>` (`// slow: <reason>` inside JavaScript) on that line. Its limit is at
  least twice the step's time in a `verify all` pass line, never its time alone; when it
  timed out there, double it and run `verify all` again.
- A wait that runs out says what it waited for.
- Wait for something to happen, never for a fixed extra time: to prove a job left something
  alone, add an old probe item and stop waiting when the job removes it.
- Never wait for real time. A job interval, retry delay, rate-limit window or expiry that
  takes longer than a few seconds is shortened in the run's environment (`PROJECT.md` says
  how), never waited out. Never turn a behavior off to make a recipe faster or pass.
- Use a fresh identifier instead of waiting for a window to reset: a rate limit or quota
  counts per key, account or caller, so take a new one. Check whether a wait is needed
  before waiting.
- Remove a race instead of trying to win it: when a job would remove state a step still
  needs, keep that state through a stub mode or the recipe's own data, not a slower job.
- A failure names its cause. A driver helper prints a failed call's error on stderr, as
  `pw.sh` does, and nothing discards stderr. A step may then send a driver's stdout to
  `/dev/null` or into `jq`, and the summary line still shows the driver's error, such as the
  locator that timed out, never "exit 1" or a jq parse error.

### Data

- Every name the recipe creates starts with `verify-<feature>-`, dash included, or the
  closest the app's naming rules allow (such as `VERIFY-ITEMS-1`), so features running at
  once never collide. The recipe creates its own data; it never relies on another feature.
  When leftovers of an interrupted run would break a check, call `cleanup` once before
  creating data.
- `cleanup()` removes what the recipe created, found by that whole prefix or by ids the
  recipe saved, never "everything this account can list": an admin account lists every
  feature's data. It always runs, after a failure too. `|| true` goes only on a delete whose
  failure cannot matter.
- Other features run at the same time on the same environment. Never assume shared state,
  such as a global counter, a job queue or a list of every user's rows, is quiet: check only
  what this recipe created.

### Size

At most about 15 steps, and a pass in 45 s or less: the runner marks a slower pass `slow`.
Split a bigger or slower feature in two: the slowest feature sets the end of every
`verify all`.

### Done

A new or edited recipe is done only when it passes in `verify all` with no `--jobs`, where
every other feature runs beside it. A pass alone or in a small batch proves nothing about its
waits.

## Recorders

A recorder writes the recipes of one area, a line of `.cache/areas.txt`: a screen or a few
that share setup, about 1,000 lines of source.

Start one recorder per area, every area at once, heaviest first. Their feature runs wait in
the machine's queue, so they need no limit of their own. In T3 Code use `delegate_task` with
`mode: "async"`; otherwise use your tool's own background subagent, on its fast model (such
as `sonnet`) when it offers one. When your tool will not start more subagents:

- If your session runs commands without asking, start the rest as headless sessions of your
  own CLI, in the background, from the repository root, each with the short prompt and its
  output in `.cache/recorders/<area>.log`:
  `claude -p "<short prompt>" --model sonnet --permission-mode bypassPermissions` or
  `codex exec -m <model> --full-auto "<short prompt>"`. Each is a process of its own, so run
  `verify room` before starting each one: it returns once the machine has room.
- Otherwise start the next area each time a recorder returns.
- With no subagents and no CLI, record the areas yourself.

Never block on a foreground command while recorders run, or their returns reach you late.
Give each recorder this short prompt, with the paths and area filled in:

```
You are a recorder for verify-<app>. Follow
<absolute path>/.agents/skills/verify-<app>/RECORDERS.md, with the repository root
<absolute path>, the example recipe features/<example>.sh, and the area <area> of
.agents/skills/verify-<app>/.cache/areas.txt.
```

A recorder has returned when its result file `.cache/results/<area>.txt` appears, with or
without the host's completion notice: notices can be lost. Read only that file's lines. Add
their traps to `PROJECT.md`'s Gotchas when they hold for other features.

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

If the app works and the recipe fails, the recipe is broken. A feature that passes alone
and fails in `verify all` is a recipe or helper defect, never flakiness: find the wait sized
for an idle machine or the state another feature changes, fix it, and run `verify all`
again. A later pass does not excuse the failure.

When `doctor.sh` fails after a feature, the runner stops starting features. Fix the
environment, or run `verify down` and `verify up`, then rerun what did not run.

## Isolation

Follow `PROJECT.md`'s Isolation section. Verification never touches what the developer uses:
their running services, data, sessions and configuration. Never attach to, change, reset or
stop anything the run did not create. An occupied resource the run needs is a blocker.
At level `shared`, pass `--jobs 1` and write only to fixtures named `verify-<feature>-`.

## Report

Start from the summary lines. One line per driven feature: **pass**, **fail** (with the step
and the failure kind), or **blocked** (with what was tried). Name the changed files you
skipped and why. Link evidence with Markdown links to absolute paths, and check that each
linked file exists after `verify down`. Report a failed `verify down` separately: a
passing feature does not mean cleanup succeeded. For isolation level `shared`, label the
report `lower confidence: shared <resources>`.
