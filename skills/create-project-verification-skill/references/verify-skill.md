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
project's own facts are in `PROJECT.md`: read it once before your first command. Paths below
are relative to this skill's folder, `.agents/skills/verify-<app>/`. Run every command from
the repository root.

## Check a change

At isolation level `checks-only` there is no live drive: run the focused checks `PROJECT.md`
names, and report every feature `blocked: no isolation`. Otherwise:

1. When the code is ready, run `bin/verify up`. It reuses the run's environment when it is
   already up and restarts only the app. Keep it up for the whole task.
2. Bring the recipes in line with the change, as part of the change, like tests. For
   behavior the change adds, alters or removes, write or edit `features/<feature>.sh`
   ([Recipes](#recipes)). A whole new feature can go to a recorder ([Recorders](#recorders)).
3. Run `bin/verify affected`. It drives the features whose `# touches:` line names a changed
   file, or whose recipe or helper changed, then prints one summary line per feature.
4. It also lists changed files no feature names. For each one that changes behavior a
   feature covers, drive that feature by name (`bin/verify <feature>`) and add the file to
   its `# touches:` line. Skip files that change no behavior: tests, docs, build files.
5. A failure: the summary line names the step and the failing command. Open the log only
   when that line is not enough. Classify it ([When a drive fails](#when-a-drive-fails)),
   fix it, and rerun only that feature.
6. At the end of the task, also after a failure, run `bin/verify down`.

Do not drive features the change cannot affect. Run `bin/verify all` only when the user asks,
after an upgrade of this skill, or when a change touches what every feature uses (launch,
sign-in, a shared helper) and you cannot name fewer features.

A drive can outlast your command timeout. Start `bin/verify` in the background, wait for it,
and read its output once. Do not poll it or tail its logs.

## Commands

- `bin/verify up` / `bin/verify down`: start or reuse, and remove, the run's environment.
- `bin/verify affected [--dry] [--base <ref>]`: select and drive; `--dry` only selects.
- `bin/verify <feature>...`, `bin/verify all`: drive those features, or every feature.
- `--jobs N` (default 8) and `--deadline SECONDS` per feature (default 180) go anywhere.
- `bin/verify list`: every feature with its one-line summary. This is the feature map.
- `bin/verify lint [feature...]`: the recipe rules the runner enforces.
- `bin/verify uncovered`: entry points no feature's `# touches:` names.
- In a companion repo, `apps` lists the app checkouts. `APP_<NAME>=<path> bin/verify ...`
  drives another checkout of that app, such as a worktree.

## Recipes

A feature is one user-facing capability: a screen, a route group, a command, an endpoint
group, a job. Its recipe is `features/<feature>.sh`, a bash script that `bin/verify` runs
under `set -euo pipefail` from the repository root, with `bin/` on `PATH`:

```bash
# Create a note from the browser and the CLI, and confirm the saved note.
# touches: web/src/NoteEditor.tsx server/routes/notes.ts cli/create.go
cleanup() { notes delete --title verify-create-note || true; }

step "Open editor"
pw.sh click "getByRole('button', { name: 'New note' })"
pw.sh run-code "async page => { await page.getByRole('form', { name: 'Note editor' }).waitFor(); }"

step "Save note"
pw.sh fill "getByRole('textbox', { name: 'Title' })" verify-create-note
pw.sh click "getByRole('button', { name: 'Save note' })"
wait_for 10 api GET /notes?title=verify-create-note
```

- Line 1: `# <what the feature lets a user do>`. Line 2: `# touches:` and the source files the
  feature's behavior lives in (handlers, components, services, queries, migrations of its
  tables), as repository paths, `<app>/<path>` in a companion repo. Files, never folders.
  Leave out what every feature uses, such as the app's entry point.
- `# alone` on its own line when the feature changes state other features read, such as
  global settings. It then runs by itself.
- `step "<label>"` before each user action. Every step ends with a check that exits non-zero
  when the result is wrong: `test`, `jq -e`, `grep -q` on a saved file, the driver's own
  assertion. A command that only prints proves nothing. Under `set -e`, `! command` never
  fails: use `test` or `if`.
- Wait for state with `wait_for <seconds> <command...>` or the driver's own waits, with a
  deadline of the expected time plus a margin. Never `sleep` or `waitForTimeout`.
- Save proof to `$EVIDENCE/`: a screenshot or snapshot for a UI, the response or output
  otherwise. On a failure, `bin/observe.sh` saves the app's state there.
- Every name the recipe creates starts with `verify-<feature>`, so features running at once
  never collide. The recipe creates its own data; it never relies on another feature.
- `cleanup()` removes what the recipe created. It always runs, after a failure too. `|| true`
  goes only on a delete whose failure cannot matter.
- Exercise the real user path, not test-only endpoints or internal setters. Check side
  effects (rows, files, messages) next to what is visible. Administrative setup is fine,
  but never in place of the user action being proved.
- At most about 15 steps. A bigger feature is two features.
- Use stable handles: roles and accessible names, data attributes, routes, prompt strings.
  Never coordinates or tab order. The helper calls and traps of this project are in
  `PROJECT.md`.

## Recorders

A recorder is a helper agent that writes one or a few new recipes. Start several at once
when there are several features, up to 8. Give each this prompt, with the features and their
one-line scopes filled in:

```
You record end-to-end recipes for verify-<app>. From the repository root, read
.agents/skills/verify-<app>/SKILL.md (sections Recipes and When a drive fails),
.agents/skills/verify-<app>/PROJECT.md, and the shortest recipe in
.agents/skills/verify-<app>/features/. Then, for each feature below, read its source, write
.agents/skills/verify-<app>/features/<feature>.sh, and run
.agents/skills/verify-<app>/bin/verify <feature> until it passes. The environment is
already up: never run verify up, down or all. Stop a feature after 5 runs, and report it
blocked with its last summary line. Behavior another feature covers is setup here, with no
checks of its own. Return one line per feature: passed, product defect: <what>, or
blocked: <reason>. Add one line per trap that cost you a run, for PROJECT.md's Gotchas.
Features: <feature>: <scope>; ...
```

When they return, read only their lines. Add their traps to `PROJECT.md`'s Gotchas when they
hold for other features.

## When a drive fails

Record the action, the expected result and its basis (the request, a documented contract
or a test), and the actual result. Diagnose before fixing. The failure is one of:

- **Recipe or helper defect:** a command, locator or wait is wrong. Fix it without changing
  the expected behavior, and rerun the feature.
- **Environment defect or missing prerequisite:** create what is missing with the project's
  own APIs or setup, inside the run's environment. Missing seed data is not a blocker.
- **Product defect:** the app contradicts supported expected behavior. Fix the code when it
  is part of the task. Otherwise report it and leave the recipe failing.
- **Uncertain expectation:** report what you saw and the decision that is missing. Never
  rewrite an expectation just to pass.

When `doctor.sh` fails after a feature, the runner stops starting features. Fix the
environment, or run `bin/verify down` and `bin/verify up`, then rerun what did not run.

## Isolation

Follow `PROJECT.md`'s Isolation section. Verification never touches what the developer uses:
their running services, data, sessions and configuration. Never attach to, change, reset or
stop anything the run did not create. An occupied resource the run needs is a blocker.
At level `shared`, pass `--jobs 1` and write only to fixtures named `verify-<feature>`.

## Report

Start from the summary lines. One line per driven feature: **pass**, **fail** (with the step
and the failure kind), or **blocked** (with what was tried). Name the changed files you
skipped and why. Link evidence with Markdown links to absolute paths, and check that each
linked file exists after `bin/verify down`. Report a failed `bin/verify down` separately: a
passing feature does not mean cleanup succeeded. For isolation level `shared`, label the
report `lower confidence: shared <resources>`.
