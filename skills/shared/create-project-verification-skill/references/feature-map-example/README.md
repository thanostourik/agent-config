# Notes verification map

This directory is the maintained source for verifying the browser and CLI behavior of Notes. Read the index, then use the matching feature file as the recipe.

## Baseline

- `bin/doctor.sh` reports Notes healthy at `http://127.0.0.1:4173`, on the disposable data directory `bin/launch.sh` created, with the expected build revision.
- Launch creates a new disposable data directory at `.agents/skills/verify-notes/.cache/data` with notes titled `Quarterly plan` (body `Draft budget`) and `Grocery list` (body `Milk`). It does not reset an existing directory.
- The `notes` CLI is on `PATH`.
- Every run starts a new Notes instance with its own data and browser session. A healthy Notes instance already running is not a verification target.

## Driving conventions

- Run features with `.agents/skills/verify-notes/bin/drive.sh --jobs 3 <feature...>`. It runs each step's `bash` block from the repository root with `bin/` on `PATH`, so blocks call `pw.sh` by name. `pw.sh` opens the browser session named after the feature, so parallel features never share one.
- Write a new or changed recipe into a staged copy of its feature file with `.agents/skills/verify-notes/bin/rec.sh <feature> start`, then run the whole copy against the running app with `rec.sh <feature> run`: it runs it the way `drive.sh` would and shows each command of a failing step, the end of its output and the path of its full log. `rec.sh install` moves the copies that passed into `features/`.
- The Preconditions block defines what later steps use, such as the `notes` function that points the CLI at the run's data directory.
- Prefer roles and accessible names over CSS selectors or DOM position.
- Every block fails when its expected result is not met. A value the step only prints gets a check.
- Each step is one action and its result; split a step that proves several. A recipe drives the app and never runs the project's tests or build.
- Blocks wait with Playwright's `waitFor` or a CLI command's own exit, never with `sleep`. A contract that states a time is checked with a wait bounded to that time plus a small margin.
- The proof step saves evidence under `.agents/skills/verify-notes/.cache/evidence/<feature>/`: an accessibility snapshot and a screenshot for the browser, the JSON output for the CLI.
- An expected result changes only when the contract changed. The checks the app fails stay in one step, right after the proof step and last before `Clean up`, with any setup it needs inside it: its sentence states the contract, its block runs every check and fails at the end, and `rec.sh <feature> run --known-failure '<Label>'` runs it. It is never weakened, dropped or moved to Gotchas.
- Every recipe supplies its own prerequisites, uses titles no other feature uses, and in its `Clean up` step removes its fixtures and closes its sessions, ending with a check that they are gone. `|| true` goes only on a command that check covers. After driving, including a failed drive, `bin/cleanup.sh` stops the run's app and browser and removes its data directory and temporary sessions. Pre-existing resources remain unchanged. No reset-before step is needed; evidence survives cleanup.
- Reports use pass, fail, partial or blocked, list any omitted checks, and link evidence using absolute Markdown targets resolved from the current checkout. Check those files exist after cleanup. Source-only map maintenance reports `Source-reviewed; no live drives run` instead of pass.

## Gotchas

- `notes` exits 0 when a note it was asked for is missing; check its JSON output, not its exit code.

## Change triggers

- The note editor, the create form, the notes API and `notes create`: create-note
- The search index, the toolbar search box, its keyboard shortcut and `notes search`: search
- The data directory format, server startup or the CLI's argument parsing: create-note and search

## Feature file shape

Each feature file starts with an H1 and one paragraph describing the observable behavior, then exactly four H2s in this order:

1. `Sub-features`: short IDs, one line per behavior.
2. `How to get to it (user POV)`: every entry point a user has.
3. `Driving it with <tools>`, naming every driver the recipe uses: `Preconditions:` with its setup and a `bash` block, then labeled bullets, each pairing a user action and its observable result with a `bash` block that fails when the result is not met. The last step is `Clean up`. The section holds at most about 15 steps, `Clean up` included; a feature that needs more is split into several features.
4. `Gotchas`: traps that waste or invalidate a run.

## Features

- [Create a note](./create-note.md) covers browser and CLI creation, cancellation, persistence, and cleanup.
- [Search notes](./search.md) covers toolbar, keyboard, and CLI search with matching, empty, and clear states.
