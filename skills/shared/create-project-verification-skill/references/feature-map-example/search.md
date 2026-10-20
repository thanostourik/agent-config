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

Preconditions: the baseline holds, and the disposable data directory contains `Quarterly plan` with body text `Draft budget`.

```bash
notes() { command notes --data-dir=.agents/skills/verify-notes/.cache/data "$@"; }
evidence=.agents/skills/verify-notes/.cache/evidence/search
mkdir -p "$evidence"
notes list --format json | jq -e '.[] | select(.title == "Quarterly plan" and .body == "Draft budget")'
```

- **Toolbar entry.** Choose the `Search` button. A dialog named `Search notes` appears with focus in its searchbox.

```bash
pw.sh click "getByRole('button', { name: 'Search' })"
pw.sh run-code "async page => { await page.getByRole('dialog', { name: 'Search notes' }).waitFor(); if (!await page.getByRole('searchbox', { name: 'Search notes' }).evaluate(e => e === document.activeElement)) throw new Error('focus is not in the searchbox'); }"
```

- **Keyboard entry.** Close the dialog, focus the page, and press `/`. The same dialog appears with an empty searchbox.

```bash
pw.sh press Escape
pw.sh click "getByRole('heading', { name: 'All notes' })"
pw.sh press /
pw.sh run-code "async page => { await page.getByRole('dialog', { name: 'Search notes' }).waitFor(); if (await page.getByRole('searchbox', { name: 'Search notes' }).inputValue()) throw new Error('a slash was typed'); }"
```

- **Title match.** Type `quarterly`. The `Search results` list contains `Quarterly plan` and not `Grocery list`.

```bash
pw.sh fill "getByRole('searchbox', { name: 'Search notes' })" "quarterly"
pw.sh run-code "async page => { const results = page.getByRole('list', { name: 'Search results' }); await results.getByRole('link', { name: 'Quarterly plan' }).waitFor(); if (await results.getByRole('link', { name: 'Grocery list' }).count()) throw new Error('Grocery list matched'); }"
```

- **Body match.** Replace the query with `budget`. `Quarterly plan` stays with a body-match excerpt.

```bash
pw.sh fill "getByRole('searchbox', { name: 'Search notes' })" "budget"
pw.sh run-code "async page => { const results = page.getByRole('list', { name: 'Search results' }); await results.getByRole('link', { name: 'Quarterly plan' }).waitFor(); await results.getByText('Draft budget').waitFor(); }"
```

- **Open result.** Choose `Quarterly plan`. The dialog closes and the editor heading reads `Quarterly plan`.

```bash
pw.sh click "getByRole('link', { name: 'Quarterly plan' })"
pw.sh run-code "async page => { await page.getByRole('dialog', { name: 'Search notes' }).waitFor({ state: 'hidden' }); await page.getByRole('heading', { name: 'Quarterly plan' }).waitFor(); }"
```

- **Empty state.** Reopen search and enter `volcano`. A status named `No matching notes` appears after search completes.

```bash
pw.sh click "getByRole('button', { name: 'Search' })"
pw.sh fill "getByRole('searchbox', { name: 'Search notes' })" "volcano"
pw.sh run-code "async page => { await page.getByRole('status', { name: 'No matching notes' }).waitFor(); }"
```

- **Clear query.** Choose `Clear search`. The searchbox is empty and the `Recent notes` region replaces the result list.

```bash
pw.sh click "getByRole('button', { name: 'Clear search' })"
pw.sh run-code "async page => { await page.getByRole('region', { name: 'Recent notes' }).waitFor(); if (await page.getByRole('searchbox', { name: 'Search notes' }).inputValue()) throw new Error('query not cleared'); }"
```

- **CLI match.** Search from the terminal. The command succeeds and prints one note titled `Quarterly plan`.

```bash
notes search "quarterly" --format json | jq -e 'length == 1 and .[0].title == "Quarterly plan"'
```

- **CLI miss.** Search for an absent value. The command succeeds and prints `[]`.

```bash
test "$(notes search "volcano" --format json)" = "[]"
```

- **Proof.** Restore the populated result state. The snapshot and screenshot show the query and `Quarterly plan`.

```bash
pw.sh fill "getByRole('searchbox', { name: 'Search notes' })" "quarterly"
pw.sh run-code "async page => { await page.getByRole('link', { name: 'Quarterly plan', exact: true }).waitFor(); }"
pw.sh snapshot --filename="$evidence/results.aria.txt"
pw.sh screenshot --filename="$evidence/results.png"
```

- **Clean up.** Close search and return to the list. No data was changed.

```bash
pw.sh press Escape
pw.sh click "getByRole('link', { name: 'All notes' })"
```

## Contract

- README.md:## Search → Toolbar entry, Keyboard entry, Title match, Body match, Open result
- README.md:## Command line → CLI match, CLI miss
- test/search.test.ts:40-72 → Empty state, Clear query

## Gotchas

- Pressing `/` while the editor or searchbox has focus inserts text instead of opening search.
- Results update after a short debounce. Wait for the results list or empty status, not a fixed sleep.
- Archived notes are excluded unless the user enables `Include archived`.
- The CLI defaults to human-readable output. Use `--format json` for stable assertions.
- Opening a result changes browser state. Reopen search before proving another query.
