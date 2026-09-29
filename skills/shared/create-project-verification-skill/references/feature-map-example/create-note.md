# Create a note

Create note lets a user save a titled note from the browser or CLI, cancel an unfinished draft, and confirm the saved note from a second user-facing view.

## Sub-features

- `create-open` opens a blank editor from each browser entry point.
- `create-save` persists a title and body.
- `create-cancel` discards an unfinished browser draft.
- `create-cli` creates the same note shape from the terminal.

## How to get to it (user POV)

- Choose the `New note` button in the browser toolbar.
- Press `n` in the browser while focus is outside an editable field.
- Run `notes create --title <title> --body <body>` in a terminal.

## Driving it with Playwright CLI and the notes CLI

Preconditions:

- Notes is healthy at `http://127.0.0.1:4173`.
- No note is titled `Release checklist`.
- `bin/doctor.sh` reports the expected URL and disposable data directory.

- **Open editor.** Choose `New note`. Run `npx playwright cli -s=notes click "getByRole('button', { name: 'New note' })"`. A form named `Note editor` appears with focus in the `Title` textbox.
- **Enter content.** Type the title and body. Run `npx playwright cli -s=notes fill "getByRole('textbox', { name: 'Title' })" "Release checklist"` and `npx playwright cli -s=notes fill "getByRole('textbox', { name: 'Body' })" "Tag and publish"`. The `Save note` button becomes enabled.
- **Save note.** Choose `Save note`. Run `npx playwright cli -s=notes click "getByRole('button', { name: 'Save note' })"`. A status named `Note saved` appears and the heading reads `Release checklist`.
- **Confirm persistence.** Return to the note list and reopen the note. Run `npx playwright cli -s=notes click "getByRole('link', { name: 'All notes' })"` and `npx playwright cli -s=notes click "getByRole('link', { name: 'Release checklist' })"`. The editor shows both saved values.
- **Cancel draft.** Open a new note, enter `Discard me`, and choose `Cancel`. Run `npx playwright cli -s=notes click "getByRole('button', { name: 'New note' })"`, `npx playwright cli -s=notes fill "getByRole('textbox', { name: 'Title' })" "Discard me"`, and `npx playwright cli -s=notes click "getByRole('button', { name: 'Cancel' })"`. The note list returns and has no `Discard me` link.
- **CLI entry.** Create a second note. Run `notes create --title "CLI note" --body "Created from terminal" --format json`. Exit code `0` and stdout contain the new note ID and title.
- **Proof.** Reopen both saved notes from `All notes`. Run `npx playwright cli -s=notes snapshot --filename=.agents/skills/verify-notes/.cache/evidence/create-note/list.aria.txt` and `npx playwright cli -s=notes screenshot --filename=.agents/skills/verify-notes/.cache/evidence/create-note/list.png`. The artifacts show `Release checklist` and `CLI note`.

## Gotchas

- Pressing `n` while a textbox has focus types the character instead of opening a new editor.
- Titles are trimmed on save. Assert the rendered title, not the draft input value.
- A save status alone is insufficient proof. Reopen the note from the list.
- Remove `Release checklist` and `CLI note` during fixture cleanup, but retain their proof artifacts.
