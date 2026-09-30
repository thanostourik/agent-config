# Search notes

Search lets a user find notes by title or body text, inspect a matching note, and distinguish no matches from an unavailable search.

## Sub-features

- `search-open` opens search from each supported browser entry point.
- `search-match` returns title and body matches without changing note data.
- `search-open-result` opens a result in the note editor.
- `search-empty` shows a complete empty state for a query with no matches.
- `search-clear` removes the query and restores the recent-notes view.
- `search-cli` returns the same matching notes from the terminal.

## How to get to it (user POV)

- Choose the `Search` button in the browser toolbar.
- Press `/` in the browser while focus is outside an editable field.
- Run `notes search <query>` in a terminal.

## Driving it with Playwright CLI and the notes CLI

Preconditions:

- The baseline holds.
- The disposable data directory contains `Quarterly plan` with body text `Draft budget`.
- Run `mkdir -p .agents/skills/verify-notes/.cache/evidence/search`.

- **Toolbar entry.** Choose the `Search` button. Run `pw click "getByRole('button', { name: 'Search' })"`. A dialog named `Search notes` appears with focus in its searchbox.
- **Keyboard entry.** Close the dialog, focus the page, and press `/`. Run `pw press Escape`, `pw click "getByRole('heading', { name: 'All notes' })"` and `pw press /`. The same dialog appears and the page does not insert a slash.
- **Title match.** Type `quarterly`. Run `pw fill "getByRole('searchbox', { name: 'Search notes' })" "quarterly"`. The `Search results` list contains `Quarterly plan` and does not contain `Grocery list`.
- **Body match.** Replace the query with `budget`. Run `pw fill "getByRole('searchbox', { name: 'Search notes' })" "budget"`. The result `Quarterly plan` remains visible with a body-match excerpt.
- **Open result.** Choose `Quarterly plan`. Run `pw click "getByRole('link', { name: 'Quarterly plan' })"`. The dialog closes and the editor heading reads `Quarterly plan`.
- **Empty state.** Reopen search and enter `volcano`. Run `pw click "getByRole('button', { name: 'Search' })"` and `pw fill "getByRole('searchbox', { name: 'Search notes' })" "volcano"`. A status named `No matching notes` appears after search completes.
- **Clear query.** Choose `Clear search`. Run `pw click "getByRole('button', { name: 'Clear search' })"`. The searchbox is empty and the `Recent notes` region replaces the result list.
- **CLI match.** Search from the terminal. Run `notes search "quarterly" --format json`. Exit code `0` and stdout contain one object whose title is `Quarterly plan`.
- **CLI miss.** Search for an absent value. Run `notes search "volcano" --format json`. Exit code `0` and stdout are `[]`.
- **Proof.** Restore the populated result state. Run `pw fill "getByRole('searchbox', { name: 'Search notes' })" "quarterly"` and `pw run-code "async page => { await page.getByRole('link', { name: 'Quarterly plan', exact: true }).waitFor(); }"`, then `pw snapshot --filename=.agents/skills/verify-notes/.cache/evidence/search/results.aria.txt` and `pw screenshot --filename=.agents/skills/verify-notes/.cache/evidence/search/results.png`. Both artifacts identify Notes, the query, and `Quarterly plan`.
- **Clean up.** Run `pw press Escape` and `pw click "getByRole('link', { name: 'All notes' })"`. The baseline list returns. No data was changed; run cleanup closes the session and removes the disposable environment while retaining evidence.

## Gotchas

- Pressing `/` while the editor or searchbox has focus inserts text instead of opening search.
- Results update after a short debounce. Wait for the results list or empty status, not a fixed sleep.
- Archived notes are excluded unless the user enables `Include archived`.
- The CLI defaults to human-readable output. Use `--format json` for stable assertions.
- Opening a result changes browser state. Reopen search before proving another query.
