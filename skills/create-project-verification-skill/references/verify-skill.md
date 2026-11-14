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
- `/verify-<app> full`: drive every feature, repair the failing ones, and record what no
  recipe covers. Follow `FULL.md`.

A request with the same meaning, such as "update the verification map" for `full`, picks the
same mode.

## Check a change

At isolation level `checks-only` there is no live drive: run the focused checks `PROJECT.md`
names, and report every feature `blocked: no isolation`. Otherwise:

1. When the code is ready, run `verify up`. It reuses the run's environment when it is
   already up, and restarts only the app. Keep the environment up for the whole task.
   - Run `verify up` again after every code change, before driving: the app runs the code
     it started with.
   - The environment also keeps what earlier code did to it, such as the migrations it
     applied. When a change or a rebase alters one of those (edits, renames or renumbers an
     applied migration, or adds one before it), run `verify down` first, so `verify up`
     starts from the new code.
2. Bring the recipes in line with the change, as part of the change, like tests. For
   behavior the change adds, alters or removes, write or edit `features/<feature>.sh` as
   [Recipes](#recipes) says. A whole new feature or screen can go to a recorder: `FULL.md`
   says how to start one.
3. Run `verify affected`, also when you already know which features you would drive. It
   drives two groups of features, and prints each feature's summary line as soon as that
   feature finishes, as `[<done>/<total>] <line>`:
   - the features whose recipe the change edited or added;
   - the features that check the edited code. For each changed line, `verify affected`
     finds the function, handler, component or query the line sits in. A feature checks
     that code when one of its `# expects:` lines cites it, or cites a unit test of it.
4. Decide which other features the change affects, and drive them together in one
   `verify <feature>...`. A feature is affected when one of its steps checks a result the
   edited code produces. `verify affected` prints the features to judge, and never drives
   them. Judge every feature they name, and leave none out unread:
   - **Features that cite code that uses the edited code.** Each feature comes with the
     caller it cites, and under it up to four behaviors it checks: first the ones that
     share words with the edit. Most of these features only pass through the edited
     code. Drive one only when a behavior under it is a result the edited code produces,
     such as the refusal a changed guard gives.
   - **Features that list a changed file.** Nothing they cite uses the edited code, but
     a step of theirs can still check it. Search their steps for what the edited code
     produces, such as its route, message, field or label
     (`grep -l '/login?error' features/*.sh`). Read every step the search finds before
     you leave its feature out.
   - **Features that list a changed file and have no `# expects:` line with a step.**
     Nothing says what they check. Read their steps.
   - **Features that use a changed helper.** Drive one for each call of the helper the
     change altered.
   - **Edited code no recipe cites or reaches.** A change also reaches features where no
     call shows it: through a row a job picks up, a queue, an event, a file, a setting,
     or a framework that wires classes by type. Search the recipes for what the edited
     code produces, and drive the features whose steps check it.

   Three rules decide the unclear cases:
   - A step that checks the result of the edited function counts, also when its input
     is not the input the change is about. Drive its feature even when you expect the
     step to pass unchanged: the drive exists to catch what you did not expect.
   - Two features that reach the edited code through the same caller, as
     `verify affected` names it, and feed it the same kind of input, check the same
     thing. One of them is enough: name the other in your report. Features that reach it
     through different callers are different checks.
   - A feature that only passes through the edited code is not affected. Its steps need
     that code to work, the way every feature needs sign-in, a layout or a connection,
     but they check something else. A step that feeds the edited code a value on its way
     to another check passes through.
5. Work through the three lists `verify affected` also prints:
   - **Entry points and actions (`bin/actions.sh`) in changed files that no recipe
     covers.** These are the screens, routes, buttons and handlers the change added.
     `verify affected` fails while this list is not empty, even when every driven feature
     passed. Give each item a step and an `# expects:` line, in the feature it belongs to
     or in a new one. Or give it an `# expects:` line marked not driven, with its reason.
     Then drive those features.
   - **Changed files no feature names, with nothing reached.** When such a file changes
     behavior a feature checks, drive that feature by name and add the file to its
     `# touches:` line. Skip files that change no behavior: tests, docs, build files.
   - **`# expects:` lines marked not driven that the change added or edited**, including
     lines another author of the branch wrote. Check each reason against
     [Header](#header). Give a line whose reason does not hold a step, and drive its
     feature.
6. On a failure, open the log only when the summary line is not enough. Classify the
   failure ([When a drive fails](#when-a-drive-fails)), fix it, and rerun only the failed
   features, together in one `verify <feature>...`.
7. At the end of the task, also after a failure, run `verify down`.

Drive only the features the change affects. Never drive every feature `verify affected`
lists for you to judge, and never run `verify all` to check a change, unless the user asks
for it.

## Commands

A drive can outlast your command timeout. Run `verify` the way your harness runs background
commands. Wait until it finishes, then read its output once. Do not poll it or tail its logs.

- `verify up` / `verify down`: start or reuse the run's environment, and remove it. The app
  runs on its dev server unless the first `verify up` set `VERIFY_APP=build`. A failed
  `verify up` prints the launch output of each copy that did not start, and the errors its
  app logged meanwhile (`bin/server-errors.sh`).
- `verify affected [--dry] [--base <ref>]`: drive the features whose recipe a change
  against the default branch edited, and the features that check the code it edited. It
  lists the features left for you to judge, as [Check a change](#check-a-change)
  describes. `--dry` only lists and drives nothing, so it never checks a change.
  `--base <ref>` compares against another ref. It exits 1 while the change adds entry
  points or actions no recipe covers.
- `verify <feature>...`: drive those features on the run's environment.
- `verify all`: drive every feature on the production build. It brings the run up on that
  build first, and removes a run on the dev server before that.
- `verify all --failed`: the same, but drive only the features that did not pass in the
  last `verify all` or `verify all --failed`, plus the features whose recipe changed since
  that run started and the features that check the code changed since then. It lists the
  features left to judge, as `verify affected` does.
- `verify uncovered [area]`: list what no recipe covers:
  - entry points (routes, screens, commands) that no feature's `# covers:` line names, with
    the count covered;
  - actions `bin/actions.sh` prints that no `# expects:` line cites by file and name;
  - lines of an area's expectation list (`.cache/expect/<area>.txt`) that no recipe of that
    area cites.

  With an area of `.cache/areas.txt`, it lists only that area's. It ends with every reason
  an `# expects:` line is marked not driven, most used first, with the count of its lines
  and its features.
- `verify list`: every feature with its one-line summary.
- `verify lint [feature...]`: check the recipe rules the runner enforces.
- `verify room`: wait until the machine has room for one more browser session or process.
- `--jobs N` (default: the skill's `jobs` file, else the machine's cores) and
  `--deadline SECONDS` per feature (default 180) go anywhere.
- Every `verify` on the machine, from every project and thread, shares one queue. A feature
  starts only while the reserve stays free, which is 20% of memory by default. One feature
  always runs. The user sets another reserve with `VERIFY_RESERVE=<percent>` or the file
  `~/.config/verify/reserve`. A summary line with `waiting for room` says how long features
  waited. The time a pass shows does not include that wait.
- Lanes run on the production build. `# alone` features take them from one queue, longest
  first. `verify up --lanes N` keeps exactly N. A drive also starts lanes itself, up to the
  number in the skill's `lanes` file, when both hold:
  - its `# alone` features take at least twice as long as a copy takes to start;
  - the copy, with a feature running on it, fits in memory beside the reserve.

  The summary line of a feature that ran on a lane names it (`lane 1`).
- In a companion repo, `apps` lists the app checkouts. `APP_<NAME>=<path> verify ...`
  drives another checkout of that app, such as a worktree. A `--base <ref>` that only the
  app checkout has still works: the companion's own changes are then compared with its
  default branch.

## Recipes

`verify` runs each recipe under `set -euo pipefail` from the repository root, with `bin/` on
`PATH`. When `bin/env.sh` exists, `verify` sources it first for the run's values (base URLs,
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
- `# touches:` lists the source files the feature's behavior lives in: routes, handlers,
  components, services, queries, migrations of its tables. Write them as repository paths,
  `<app>/<path>` in a companion repo. Name files, never folders. Several `# touches:` lines
  are fine. Leave out files every feature only passes through, such as bootstrap code or
  shared config. A file that holds this feature's routes or handlers belongs in, even when
  other features' are there too.
- `# covers:` lists the entry points the recipe drives, comma-separated, written exactly as
  `bin/entrypoints.sh` prints them (such as `POST /api/notes, /notes/[id]`).
- `# expects: <behavior> (<source>) -> <step label>` comes once for every behavior the
  docs, the tests or the request state for this feature: what it does, its errors, limits
  and side effects. Join several labels with `, `.
  - `<source>` is the behavior's line in the expectation list of the feature or its area
    (`.cache/expect/`), without the `- `, such as `web/test/editor.test.ts: opens blank` or
    `README.md: ## Notes`.
  - A behavior taken from the source code cites its file and function instead, as
    `<file name>: <function>` (`NoteEditor.tsx: handleSave`). `verify uncovered` counts an
    action covered only when a line names both.
  - Cite the function that produces the behavior, by its name in the code, never by a
    label of your own such as `BLE getFile`. `verify affected` drives the feature when a
    change edits the function it cites, and finds that function only by this name.
- A behavior no step of the recipe drives gets `-> not driven: <reason>`. Only three
  reasons hold:
  - Another feature drives it: `covered by <feature>`.
  - The app can never receive that input. The reason names what stops it, such as a unique
    index or the filter of an earlier layer.
  - Nothing the run owns could make it happen, even after you extend its stubs, helpers
    and fixtures. The reason names what it would take, such as a charge at the real
    payment provider, or a second request landing between two statements of the first.

  These are not reasons:
  - A stub, fake or helper that does not yet return the data, or cannot yet fail on
    demand. It is the project's own tooling: extend it, or start a listener of the
    feature's own, as part of writing the recipe.
  - A shared service the step would have to stop or reconfigure. Mark the feature
    `# alone`.
  - A unit test that covers the behavior. A unit test runs on input its author typed, so
    it proves nothing about what the running app receives.
- The `# expects:` lines decide how deep the recipe goes:
  - Read the feature's tests and docs for them before writing steps. Read each test's
    body, not only its name. The expectation list holds one line per test, but a test that
    checks several cases, such as a loop over rejected values or one date at each edge of a
    period, gives one `# expects:` line per case, each citing that test.
  - Then always take the rest from the source, one behavior per line, never merged: each
    field and its validation message, each button and what it does, each state (empty,
    loading, filtered, paging, editing, error, limit), each error response, each
    permission rule (who may, and who is refused), and each side effect (row, mail, file,
    event) in the feature's files.
- Behavior another feature covers is setup here, with no checks of its own.
- Optional lines:
  - `# shares: <group>: <the shared state it changes>` when the feature changes state that
    only some other features also change or read, such as the one active API key or one
    global setting. Features of the same group take turns. Every other feature runs beside
    them.
  - `# alone: <the shared state it changes>` when every other feature would break
    meanwhile, such as a clock change or a service restart. The feature runs by itself.
  - `# deadline: <seconds>` when the whole feature needs longer than 180 s. Give it at
    least one and a half times its time in a `verify all` pass. The runner marks a pass
    that used two thirds of its deadline.
  - `# known failure: <step label>` for a product defect already reported. Its failure then
    reads `known failure at "<step label>"`. Report that line as it is, with no new
    diagnosis.

  First give the feature its own tenant, account, key, workspace, schema, prefix or data
  folder. Mark it `# shares` or `# alone` only when the clash remains.

### Steps

- Write each locator from a snapshot of the real screen, and each check from one real API
  response. Never write them from the source alone: names and response shapes read from
  the source are often wrong.
  - Open the screen once in a browser session of your own, named
    `VERIFY_SESSION=<feature>-probe` (a recorder uses `<area>-probe`). Save its snapshot
    (`bin/pw.sh snapshot`) with each of its dialogs and menus open.
  - A behavior the snapshot does not show, such as an error, an empty state or a refused
    permission, keeps its `# expects:` line.
- `step "<label>" "<what it proves>"` comes before each user action. The second argument is
  one sentence with the action and its expected result. A failing step's summary line
  repeats it, so whoever repairs the recipe knows what the step was meant to prove.
- Every step ends with a check that exits non-zero when the result is wrong: `test`,
  `jq -e`, `grep -q` on a saved file, the driver's own assertion. A command that only prints
  proves nothing. Under `set -e`, `! command` never fails: use `test` or `if`.
- Exercise the real user path, not test-only endpoints or internal setters. Check side
  effects (rows, files, messages) next to what is visible. Administrative setup is fine,
  but never in place of the user action being proved.
- A save step fills every field the form offers (each input, select, toggle and list
  entry), not only the required ones, with values unlike the defaults. Then it reloads the
  page or reads the record back and checks each field, not only the success message. A
  field the app forgets to save shows only after a reload, and only when the step set it.
- A check that something is gone first waits for the dialog or menu that removed it to
  close. Then it checks that a neighbor the action left alone is visible and the item is
  absent. While a dialog is open or closing, the page behind it is hidden from role
  queries, so a wait for `detached` or `hidden` passes at once, while the item is still on
  screen.
- Do a multi-step UI action in one driver call (one Playwright `run-code` with several
  actions and their waits): every call costs about a second. Act through `run-code` only.
  The Playwright CLI's `click` and `press` wait 6 to 10 s for the network to go quiet, and
  do not wait for the element.
- Use stable handles: roles and accessible names, data attributes, routes, prompt strings.
  Never coordinates or tab order. The helper calls and traps of this project are in
  `PROJECT.md`.
- Save proof to `$EVIDENCE/`: a screenshot or snapshot for a UI, the response or output
  otherwise. On a failure, `bin/observe.sh` saves the app's state there, and
  `bin/server-errors.sh` saves the app's server errors since the failing step began to
  `server-errors.txt`. The summary line then shows the first of them.

### Waits and errors

These rules hold for recipes and for every helper in `bin/`.

- Size every wait for a busy machine, never an idle one. In `verify all` every feature runs
  at once, and a step can take many times its time alone. Wait for state with
  `wait_for <seconds> <command...>` or the driver's own waits, 30 s at most. `run-code`
  waits 30 s by default.
- A simple action, such as a save, that takes over 10 s in a drive of a few features is a
  finding to report, not a reason for a longer wait. A pass line names its steps over 10 s.
- Only a step that waits for slow work by design waits longer, such as a background job, a
  report over production-sized data or a restart. Put `# slow: <reason>` on that line
  (`// slow: <reason>` inside JavaScript). Its limit is at least twice the step's time in a
  `verify all` pass line, never its time alone. When it timed out there, double it and
  drive it again with `verify all --failed`.
- Every Playwright call in a slow step gets that same limit, the click that starts a
  navigation included, such as with `page.setDefaultTimeout(<ms>)` first in the `run-code`
  function. Playwright counts the navigation a click starts inside the click's own timeout,
  so raising only the wait after the click changes nothing.
- A helper that restarts the app returns only when a real page answers, signed in where
  the app has sign-in, never only a health check. A server answers its health check before
  its first page is ready. The steps after a restart then need no longer waits.
- A wait that runs out says what it waited for.
- Wait for something to happen, never for a fixed extra time. To prove a job left something
  alone, add an old probe item and stop waiting when the job removes it.
- Never wait for real time. A job interval, retry delay, rate-limit window or expiry that
  takes longer than a few seconds is shortened in the run's environment (`PROJECT.md` says
  how), never waited out. Never turn a behavior off to make a recipe faster or pass.
- Use a fresh identifier instead of waiting for a window to reset. A rate limit or quota
  counts per key, account or caller, so take a new one. Check whether a wait is needed
  before waiting.
- Remove a race instead of trying to win it. When a job would remove state a step still
  needs, keep that state through a stub mode or the recipe's own data, not a slower job.
- A failure names its cause. A driver helper prints a failed call's error on stderr, as
  `pw.sh` does, and nothing discards stderr. A step may then send a driver's stdout to
  `/dev/null` or into `jq`, and the summary line still shows the driver's error, such as the
  locator that timed out, never "exit 1" or a jq parse error.

### Data

- Every name the recipe creates starts with `verify-<feature>-`, dash included, or the
  closest the app's naming rules allow (such as `VERIFY-ITEMS-1`), so features running at
  once never collide. The recipe creates its own data. It never relies on another feature.
  When leftovers of an interrupted run would break a check, call `cleanup` once before
  creating data.
- `cleanup()` removes what the recipe created, found by that whole prefix or by ids the
  recipe saved. It never removes "everything this account can list": an admin account lists
  every feature's data. It always runs, after a failure too. `|| true` goes only on a
  delete whose failure cannot matter.
- Other features run at the same time on the same environment. Never assume shared state
  is quiet, such as a global counter, a job queue or a list of every user's rows. Check
  only what this recipe created.
- A fixture that inserts rows directly, past the app, holds every rule real data holds,
  such as a finished order always having its line items. Its author checks that against the
  seed data or the dump. Every feature shares one database at once, and pages that add up
  every row (reports, dashboards, counts) also read this feature's rows. One row real data
  never has can break another feature's page.
- A row that several features insert directly comes from one fixture helper in `bin/`, such
  as `fixture user verify-notes-1 editor`, never from the same `insert` in each recipe. The
  table's columns and the rules of real data then sit in one place. A schema change needs
  one edit there, and `verify affected` lists every feature that uses a changed helper.

### Size

At most about 15 steps, and a pass in 45 s or less: the runner marks a slower pass `slow`.
Split a bigger or slower feature in two. The slowest feature sets the end of every
`verify all`.

### Done

In Full mode (`FULL.md`), and when the generator proves recipes, a new or repaired recipe
is done only when it passes in the final `verify all` with no `--jobs`, where every other
feature runs beside it. A pass in `verify all --failed`, alone or in a small batch, proves
nothing about its waits. It only saves full drives until the final one.

When you [check a change](#check-a-change), and when the maintain skill proves an upgrade,
a pass in the features you drive is enough: a full drive per change takes too long. Size
the recipe's waits for `verify all` anyway.

## When a drive fails

Record the action, the expected result and its basis (the request, a documented contract
or a test), and the actual result. Diagnose before fixing. In the log, each step's line
ends with the time since the recipe began, such as `(at 21s)`. A step took the difference
to the next line. The failure is one of:

- **Recipe or helper defect:** a command, locator or wait is wrong. Fix it without changing
  the expected behavior, and rerun the feature.
- **Environment defect or missing prerequisite:** create what is missing with the project's
  own APIs or setup, inside the run's environment. Missing seed data is not a blocker.
- **Product defect:** the app contradicts supported expected behavior. Fix the code when it
  is part of the task. Otherwise report it, leave the recipe failing, and add
  `# known failure: <step label>` to its header. Put that check last, so it hides no other.
- **Uncertain expectation:** report what you saw and the decision that is missing. Never
  rewrite an expectation just to pass.

A summary line with `server errors:` means the app failed while the step ran. Read that
file before the recipe. The error may come from another feature's data.

If the app works and the recipe fails, the recipe is broken. Some features fail in one
drive and pass in another on the same code, such as alone after `verify all`, or on a
second try on a busy machine. That is a recipe or helper defect, never flakiness or machine
load. Find the wait sized for an idle machine, or the state another feature changes, and
fix it. Then drive the feature again with the other failed features, with
`verify all --failed` when it failed in `verify all`. A later pass does not excuse the
failure.

When `doctor.sh` fails after a feature, the runner stops starting features. Fix the
environment, or run `verify down` and `verify up`, then rerun what did not run.

## Isolation

Follow `PROJECT.md`'s Isolation section. Verification never touches what the developer uses:
their running services, data, sessions and configuration. Never attach to, change, reset or
stop anything the run did not create. An occupied resource the run needs is a blocker.
At level `shared`, pass `--jobs 1` and write only to fixtures named `verify-<feature>-`.

## Report

Start from the summary lines.

- Name each drive by its command and its number of features, such as "`verify affected`,
  5 features". Only `verify all` without `--failed` drives every feature, so call no other
  drive full.
- Give one line per driven feature: **pass**, **fail** (with the step and the failure
  kind), or **blocked** (with what was tried). For a feature you drove by name, add the
  step that checks the edited code.
- Name the changed files you skipped and why. Name the features you left out because
  another driven feature checks the same call, and the edited code that other features
  only pass through, so the user can ask for them or for `verify all`.
- List every `# expects:` line the change left marked not driven, with its reason.
- Link evidence with Markdown links to absolute paths, and check that each linked file
  exists after `verify down`.
- Report a failed `verify down` separately: a passing feature does not mean cleanup
  succeeded.
- For isolation level `shared`, label the report `lower confidence: shared <resources>`.
