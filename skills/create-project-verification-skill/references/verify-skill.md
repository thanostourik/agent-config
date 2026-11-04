---
name: verify-<app>
description: "Drive <app> end to end to prove a change works: drive the features a change affects, write or fix their recipes, or drive every feature. Use before calling any work on <app> done, and when asked to verify, test end to end or record a feature."
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

## Check a change

At isolation level `checks-only` there is no live drive: run the focused checks `PROJECT.md`
names, and report every feature `blocked: no isolation`. Otherwise:

1. When the code is ready, run `verify up`. It reuses the run's environment when it is
   already up and restarts only the app. Keep it up for the whole task.
2. Bring the recipes in line with the change, as part of the change, like tests. For
   behavior the change adds, alters or removes, write or edit `features/<feature>.sh`
   ([Recipes](#recipes)). A whole new feature can go to a recorder ([Recorders](#recorders)).
3. Run `verify affected`. It drives the features whose `# touches:` line names a changed
   file, or whose recipe or helper changed, then prints one summary line per feature.
4. It also lists changed files no feature names. For each one that changes behavior a
   feature covers, drive that feature by name (`verify <feature>`) and add the file to
   its `# touches:` line. Skip files that change no behavior: tests, docs, build files.
   Then read `verify list` against your diff and drive every other feature the change can
   affect: the file match misses a feature that depends on a file listed only under
   another feature, such as a shared service or component.
5. A failure: the summary line names the step and the failing command. Open the log only
   when that line is not enough. Classify it ([When a drive fails](#when-a-drive-fails)),
   fix it, and rerun only that feature.
6. At the end of the task, also after a failure, run `verify down`.

Do not drive features the change cannot affect. Run `verify all` only when the user asks,
after an upgrade of this skill, or when a change touches what every feature uses (launch,
sign-in, a shared helper) and you cannot name fewer features.

## Keep the map current

When the user asks to update or maintain verification, or `verify all` has not passed for a
while: run `verify up`, `verify all` and `verify uncovered`, and rerun `bin/harvest` into
`.cache/expect/` for each feature whose tests or docs changed, so `verify lint` names the
behaviors its recipe no longer cites. Send each failing feature and
each uncovered entry point to recorders ([Recorders](#recorders)): a failing recipe is
repaired or its product defect reported, an uncovered entry point gets a recipe or joins an
existing feature's `# covers:`. Then `verify down`, commit, and report what changed.

A drive can outlast your command timeout. Start `verify` in the background, wait for it,
and read its output once. Do not poll it or tail its logs.

## Commands

- `verify up` / `verify down`: start or reuse, and remove, the run's environment.
- `verify affected [--dry] [--base <ref>]`: select and drive; `--dry` only selects.
- `verify <feature>...`, `verify all`: drive those features, or every feature.
- `--jobs N` (default: the skill's `jobs` file, else 8) and `--deadline SECONDS` per feature (default 180) go anywhere.
- `verify list`: every feature with its one-line summary. This is the feature map.
- `verify lint [feature...]`: the recipe rules the runner enforces.
- `verify up --lanes N`: also start N extra copies of the environment; `# alone` features
  take them from one queue, longest first. Without `--lanes`, the count comes from the
  skill's `lanes` file.
- `verify uncovered`: entry points (routes, screens, commands) no feature's `# covers:`
  names, with the count covered.
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
  effects. `<source>` is the line from `.cache/expect/<feature>.txt` without its `- `, such as
  `web/test/editor.test.ts: opens blank` or `README.md: ## Notes`; a behavior taken from the
  source code cites its file. Several labels are joined by `, `. A behavior the run cannot
  reach gets `-> not driven: <reason>`. `verify lint` refuses a line whose step does not
  exist, and, while `.cache/expect/<feature>.txt` exists, a recipe that cites none of
  its listed tests or headings. Read
  the feature's tests and docs for these lines before writing steps; they are the recipe's
  depth. When they state little, take the lines from the source: each validation, error
  response, permission check and side effect of the feature's handlers is a behavior.
- Optional header lines: `# alone` when the feature changes state other features read, such
  as global settings, so it runs by itself; `# deadline: <seconds>` when the whole feature
  needs longer than 180 s; `# known failure: <step label>` for a product defect already
  reported, so its failure reads `(known failure)` and needs no new diagnosis.
- The feature name is the file name. It is never a `verify` command: `up`, `down`, `list`,
  `lint`, `uncovered`, `affected`, `all`, `help`.
- `step "<label>" "<what it proves>"` before each user action: the second argument is one
  sentence with the action and its expected result. A failing step's summary line repeats
  it, so whoever repairs the recipe knows what the step was meant to prove. Every step ends with a check that exits non-zero
  when the result is wrong: `test`, `jq -e`, `grep -q` on a saved file, the driver's own
  assertion. A command that only prints proves nothing. Under `set -e`, `! command` never
  fails: use `test` or `if`.
- Wait for state with `wait_for <seconds> <command...>` or the driver's own waits, with a
  deadline of the expected time plus a margin. Never `sleep` or `waitForTimeout`.
- Save proof to `$EVIDENCE/`: a screenshot or snapshot for a UI, the response or output
  otherwise. On a failure, `bin/observe.sh` saves the app's state there.
- Every name the recipe creates starts with `verify-<feature>-`, dash included, or the
  closest the app's naming rules allow (such as `VERIFY-ITEMS-1`), so features running at
  once never collide. Cleanup matches that whole prefix, dash included: `ingestion` must
  never delete `ingestion-sources`' data.
  The recipe creates its own data; it never relies on another feature. When leftovers of an
  interrupted run would break a check, call `cleanup` once before creating data.
- `cleanup()` removes what the recipe created, found by its `verify-<feature>-` prefix or
  by ids the recipe saved, never "everything this account can list": an admin account lists
  every feature's data. It always runs, after a failure too. `|| true`
  goes only on a delete whose failure cannot matter.
- Other features run at the same time on the same environment. Never assume shared state,
  such as a global counter, a job queue or a list of every user's rows, is quiet: check only
  what this recipe created. Give the feature its own tenant, account, key or workspace
  before marking it `# alone`.
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
- Make a race impossible instead of racing it: when a job would remove state a step still
  needs, hold that state through a stub mode or the recipe's own data, not a slower job.
- Exercise the real user path, not test-only endpoints or internal setters. Check side
  effects (rows, files, messages) next to what is visible. Administrative setup is fine,
  but never in place of the user action being proved.
- At most about 15 steps, and under about a minute on a quiet machine. A bigger or slower
  feature is two features: the slowest feature sets the end of every full drive.
- Use stable handles: roles and accessible names, data attributes, routes, prompt strings.
  Never coordinates or tab order. The helper calls and traps of this project are in
  `PROJECT.md`.

## Recorders

A recorder is a helper agent that writes one or a few new recipes. Start several at once
when there are several features, up to 12. When the host refuses one, start it again when
another returns; with no helper agents at all, record the features yourself. Give each this
prompt, with the features and their
one-line scopes, the example recipe and the repository's absolute path filled in:

```
You record end-to-end recipes for verify-<app>. The repository root is <absolute path>; run
every command from there. Read
.agents/skills/verify-<app>/SKILL.md (sections Recipes and When a drive fails),
.agents/skills/verify-<app>/PROJECT.md, the example recipe
.agents/skills/verify-<app>/features/<example>.sh, and each feature's expectation list
.agents/skills/verify-<app>/.cache/expect/<feature>.txt. Then, for each feature below, read
its source, write .agents/skills/verify-<app>/features/<feature>.sh with one '# expects:'
line per listed behavior, and run .agents/skills/verify-<app>/bin/verify <feature> until it
passes. Last, run your features once together with three others that already have a
result file in .agents/skills/verify-<app>/.cache/results/ (all of them when fewer exist)
(bin/verify <yours> <others>), because every drive runs features in parallel: check only
data your recipe created. A step label never contains a comma. The environment is
already up: never run verify up, down or all. Stop a feature after 5 runs, and report it
blocked with its last summary line. A defect in a helper: fix it when the fix is small and
cannot break other features, by writing a copy and moving it over the helper with mv (other
drives are running it, and bash reads a script while it runs), and name it in your result
line; otherwise report
blocked: helper <name>: <defect>. Behavior another feature covers is setup here, with no
checks of its own. Return one line per feature: passed, product defect: <what>, or
blocked: <reason>. For a product defect, add '# known failure: <step label>' to the recipe's
header. While iterating, drive only your own features. Edit only your own recipes: no git
branch, commit or stash, and no edit to PROJECT.md. Stop every process your
attempts started. As your last action, write those lines, and one line per trap that cost
you a run for PROJECT.md's Gotchas, to
.agents/skills/verify-<app>/.cache/results/<your first feature>.txt (through a temporary file
and mv), then return the same lines.
Features: <feature>: <scope>; entry points: <...>; ...
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
