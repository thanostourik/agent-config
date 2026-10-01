# Notes verification map

This directory is the maintained source for verifying the browser and CLI behavior of Notes. Read the index, then use the matching feature file as the recipe.

## Baseline

- `bin/doctor.sh` reports Notes healthy at `http://127.0.0.1:4173`, on the disposable data directory `bin/launch.sh` created, with the expected build revision.
- Launch creates a new disposable data directory at `.agents/skills/verify-notes/.cache/data` with notes titled `Quarterly plan` (body `Draft budget`) and `Grocery list` (body `Milk`). It does not reset an existing directory.
- The `notes` CLI is on `PATH`.
- Every run starts a new Notes instance with its own data and browser session. A healthy Notes instance already running is not a verification target.

## Driving conventions

- Every command runs from the repository root. `pw` means `.agents/skills/verify-notes/bin/pw.sh`, which runs `npx playwright cli -s=notes` with its files kept in the skill's `.cache/`.
- `notes` in the recipes means `notes --data-dir=.agents/skills/verify-notes/.cache/data`. The recipes write the shorthands for brevity. When you run a step, type the full command, because no alias or environment variable from an earlier session exists.
- Start every feature from the baseline unless its preconditions say otherwise.
- Prefer roles and accessible names over CSS selectors or DOM position.
- Treat every command as literal. Keep quoted names and flags unchanged.
- For terminal steps, record the command, stdout, stderr, and exit code.
- Wait for the named UI state or command result within the deadline documented by `verify-notes`. Long operations report progress while waiting; timeout captures diagnostics and triggers run cleanup.
- A feature that changes seeded data restores it before it ends.
- Only one agent drives this environment. Source readers never change its browser or data.
- Every recipe supplies its own prerequisites and removes its fixtures. After driving, including a failed drive, `bin/cleanup.sh` stops the run's app and browser and removes its data directory and temporary sessions. Pre-existing resources remain unchanged. No reset-before step is needed; evidence survives cleanup.
- Reports use pass, fail, partial or blocked, list any omitted checks, and link evidence using absolute Markdown targets resolved from the current checkout. Check those files exist after cleanup. Source-only map maintenance reports `Source-reviewed; no live drives run` instead of pass.

## Feature file shape

Each feature file starts with an H1 and one paragraph describing the observable behavior, then exactly four H2s in this order:

1. `Sub-features`: short IDs, one line per behavior.
2. `How to get to it (user POV)`: every entry point a user has.
3. `Driving it with <tool>`: `Preconditions:` with exact setup, then labeled bullets that pair each user action with an exact command and its observable result, ending with proof and fixture cleanup.
4. `Gotchas`: traps that waste or invalidate a run.

## Features

Each entry carries a status. `proven` means a drive passed every step. `draft` means it has not been driven yet. Maintenance drives every step of a `draft` feature and then marks it `proven`.

- [Create a note](./create-note.md) `proven` covers browser and CLI creation, cancellation, persistence, and cleanup.
- [Search notes](./search.md) `draft` covers toolbar, keyboard, and CLI search with matching, empty, and clear states.
