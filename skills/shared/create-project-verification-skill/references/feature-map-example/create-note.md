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

Preconditions: the baseline holds and contains neither `Release checklist` nor `CLI note`. Do not delete an unexpected pre-existing note.

```bash
notes() { command notes --data-dir=.agents/skills/verify-notes/.cache/data "$@"; }
evidence=.agents/skills/verify-notes/.cache/evidence/create-note
mkdir -p "$evidence"
test "$(notes list --format json | jq '[.[] | select(.title == "Release checklist" or .title == "CLI note")] | length')" = 0
```

- **Open editor.** Choose `New note`. A form named `Note editor` appears with focus in the `Title` textbox.

```bash
pw.sh click "getByRole('button', { name: 'New note' })"
pw.sh run-code "async page => { await page.getByRole('form', { name: 'Note editor' }).waitFor(); if (!await page.getByRole('textbox', { name: 'Title' }).evaluate(e => e === document.activeElement)) throw new Error('focus is not in Title'); }"
```

- **Enter content.** Type the title and body. The `Save note` button becomes enabled.

```bash
pw.sh fill "getByRole('textbox', { name: 'Title' })" "Release checklist"
pw.sh fill "getByRole('textbox', { name: 'Body' })" "Tag and publish"
pw.sh run-code "async page => { if (await page.getByRole('button', { name: 'Save note' }).isDisabled()) throw new Error('Save note is disabled'); }"
```

- **Save note.** Choose `Save note`. A status named `Note saved` appears and the heading reads `Release checklist`.

```bash
pw.sh click "getByRole('button', { name: 'Save note' })"
pw.sh run-code "async page => { await page.getByRole('status', { name: 'Note saved' }).waitFor(); await page.getByRole('heading', { name: 'Release checklist' }).waitFor(); }"
```

- **Confirm persistence.** Return to the note list and reopen the note. The editor shows both saved values.

```bash
pw.sh click "getByRole('link', { name: 'All notes' })"
pw.sh click "getByRole('link', { name: 'Release checklist' })"
pw.sh run-code "async page => { const title = await page.getByRole('textbox', { name: 'Title' }).inputValue(); const body = await page.getByRole('textbox', { name: 'Body' }).inputValue(); if (title !== 'Release checklist' || body !== 'Tag and publish') throw new Error(`saved values: ${title} / ${body}`); }"
```

- **Cancel draft.** Open a new note, enter `Discard me`, and choose `Cancel`. The note list returns and has no `Discard me` link.

```bash
pw.sh click "getByRole('button', { name: 'New note' })"
pw.sh fill "getByRole('textbox', { name: 'Title' })" "Discard me"
pw.sh click "getByRole('button', { name: 'Cancel' })"
pw.sh run-code "async page => { await page.getByRole('heading', { name: 'All notes' }).waitFor(); if (await page.getByRole('link', { name: 'Discard me' }).count()) throw new Error('draft was saved'); }"
```

- **Keyboard entry.** Focus the page and press `n`. The same blank `Note editor` form opens. Cancel returns without saving.

```bash
pw.sh click "getByRole('heading', { name: 'All notes' })"
pw.sh press n
pw.sh run-code "async page => { await page.getByRole('form', { name: 'Note editor' }).waitFor(); if (await page.getByRole('textbox', { name: 'Title' }).inputValue()) throw new Error('editor is not blank'); }"
pw.sh click "getByRole('button', { name: 'Cancel' })"
```

- **CLI entry.** Create a second note from the terminal. The command succeeds and prints the new note's ID and title.

```bash
notes create --title "CLI note" --body "Created from terminal" --format json | tee "$evidence/cli-create.json" | jq -e '.id and .title == "CLI note"'
```

- **Proof.** Reload the list. Both saved titles appear.

```bash
pw.sh reload
pw.sh run-code "async page => { await page.getByRole('link', { name: 'Release checklist', exact: true }).waitFor(); await page.getByRole('link', { name: 'CLI note', exact: true }).waitFor(); }"
pw.sh snapshot --filename="$evidence/list.aria.txt"
pw.sh screenshot --filename="$evidence/list.png"
```

- **Clean up.** Delete both fixtures. Only notes from the baseline or other features remain.

```bash
notes delete --title "Release checklist" || true
notes delete --title "CLI note" || true
test "$(notes list --format json | jq '[.[] | select(.title == "Release checklist" or .title == "CLI note")] | length')" = 0
```

## Gotchas

- Pressing `n` while a textbox has focus types the character instead of opening a new editor.
- Titles are trimmed on save. Assert the rendered title, not the draft input value.
- A save status alone is insufficient proof. Reopen the note from the list.
- The `Clean up` step lets this recipe run again without resetting the app. It also runs when a step fails, and keeps proof artifacts.
