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

- The baseline holds.
- The baseline contains neither `Release checklist` nor `CLI note`. Run `notes list --format json` to confirm before creating them; do not delete an unexpected pre-existing note.
- Run `mkdir -p .agents/skills/verify-notes/.cache/evidence/create-note`.

- **Open editor.** Choose `New note`. Run `pw click "getByRole('button', { name: 'New note' })"`. A form named `Note editor` appears with focus in the `Title` textbox.
- **Enter content.** Type the title and body. Run `pw fill "getByRole('textbox', { name: 'Title' })" "Release checklist"` and `pw fill "getByRole('textbox', { name: 'Body' })" "Tag and publish"`. The `Save note` button becomes enabled.
- **Save note.** Choose `Save note`. Run `pw click "getByRole('button', { name: 'Save note' })"`. A status named `Note saved` appears and the heading reads `Release checklist`.
- **Confirm persistence.** Return to the note list and reopen the note. Run `pw click "getByRole('link', { name: 'All notes' })"` and `pw click "getByRole('link', { name: 'Release checklist' })"`. The editor shows both saved values.
- **Cancel draft.** Open a new note, enter `Discard me`, and choose `Cancel`. Run `pw click "getByRole('button', { name: 'New note' })"`, `pw fill "getByRole('textbox', { name: 'Title' })" "Discard me"`, and `pw click "getByRole('button', { name: 'Cancel' })"`. The note list returns and has no `Discard me` link.
- **Keyboard entry.** Focus the page and press `n`. Run `pw click "getByRole('heading', { name: 'All notes' })"` and `pw press n`. The same blank `Note editor` form opens. Run `pw click "getByRole('button', { name: 'Cancel' })"` to return without saving.
- **CLI entry.** Create a second note. Run `notes create --title "CLI note" --body "Created from terminal" --format json`. Exit code `0` and stdout contain the new note ID and title.
- **Proof.** Reload the list to include the CLI-created note. Run `pw reload`, then `pw run-code "async page => { await page.getByRole('link', { name: 'Release checklist', exact: true }).waitFor(); await page.getByRole('link', { name: 'CLI note', exact: true }).waitFor(); }"`. Run `pw snapshot --filename=.agents/skills/verify-notes/.cache/evidence/create-note/list.aria.txt` and `pw screenshot --filename=.agents/skills/verify-notes/.cache/evidence/create-note/list.png`. The artifacts show both saved titles.
- **Clean fixtures.** Run `notes delete --title "Release checklist"` and `notes delete --title "CLI note"`, then `notes list --format json`. Only the two baseline notes remain. If a preceding step failed, remove only fixtures that step created; run cleanup still removes the run's disposable data directory.

## Gotchas

- Pressing `n` while a textbox has focus types the character instead of opening a new editor.
- Titles are trimmed on save. Assert the rendered title, not the draft input value.
- A save status alone is insufficient proof. Reopen the note from the list.
- Fixture cleanup lets this recipe run again without resetting the app. Run cleanup also executes when a step fails, and retains proof artifacts.
