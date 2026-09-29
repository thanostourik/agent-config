# Notes verification map

This directory is the maintained source for verifying the user-facing behavior of Notes. Read the index, then use the matching feature file as the recipe.

## Baseline

- `bin/doctor.sh` reports Notes healthy at `http://127.0.0.1:4173`, on the disposable data directory `bin/launch.sh` created, with the expected build revision.
- The data directory holds notes titled `Quarterly plan` and `Grocery list`.
- The `notes` CLI is on `PATH`.

## Driving conventions

- Every command runs from the repository root. `pw` means `.agents/skills/verify-notes/bin/pw.sh`, which runs `npx playwright cli -s=notes` with its files kept in the skill's `.cache/`.
- Start every feature from the baseline unless its preconditions say otherwise.
- Prefer roles and accessible names over CSS selectors or DOM position.
- Treat every command as literal. Keep quoted names and flags unchanged.
- For terminal steps, record the command, stdout, stderr, and exit code.
- A feature that changes seeded data restores it before it ends.

## Features

- [Create a note](./create-note.md) covers browser and CLI creation, cancellation, persistence, and cleanup.
- [Search notes](./search.md) covers toolbar, keyboard, and CLI search with matching, empty, and clear states.
