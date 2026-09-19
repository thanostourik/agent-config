# Sync redesign: mirror what sync owns, touch nothing else

## What sync must do

1. **Mirror.** After `./sync --apply`, everything sync owns matches this
   repository and `config.json`. That covers adding, updating, and deleting.
   Deleting a source, removing one file from a skill, changing a skill's
   `harness`, and setting `enabled: false` all end the same way: the installed
   copy goes away.
2. **Touch nothing else.** The tool folders and `~/.local/bin/` also hold things
   the tools and I put there. Sync never changes or deletes those.
3. **Keep its own files in one place.** Bookkeeping and backups live under
   `~/.config/agent-config/`. Tool folders hold installed content only.
4. **Back up only what git does not have.** A backup is made only when sync is
   about to destroy content that exists nowhere else.
5. **Stay simple.** Plain Python, standard library only. Preview by default,
   `--check`, `--apply`, `--home` keep working as they do now.

## Why today's sync cannot do this

Sync looks only at what the repository contains now. It has no record of what
it installed before. So it cannot see that something was removed, and it cannot
tell its own files from mine. Backups and the `--replace-existing` flag make up
for that: every existing file is treated as possibly mine.

## Design

### Two kinds of owned things

Sync installs two kinds of things. The design calls both of them **items**.

- **A file.** Sync owns the whole file: instruction files, every file of a
  skill, agent files, the Codex and Cursor hook files, `bin/` scripts.
- **An entry.** Sync owns one value inside a file that belongs to a tool:
  - the `hooks` key in `~/.claude/settings.json`
  - each Jira server under `mcpServers` / `mcp` in the three JSON MCP files
  - each `[mcp_servers.<name>]` table in the two TOML MCP files

  Sync never owns the rest of such a file.

### The state file

`~/.config/agent-config/state.json` lists every item sync installed, with a
SHA-256 hash of what it wrote.

```json
{
  "files":   {".claude/skills/file-pr/SKILL.md": "<sha256>"},
  "entries": {".claude.json#mcpServers.jira": "<sha256>",
              ".claude/settings.json#hooks": "<sha256>"}
}
```

Paths are relative to the home folder. An entry's hash is taken over its value
as canonical JSON, so formatting differences in the tool's file do not matter.
TOML tables are read with `tomllib` and hashed the same way.

This file replaces `managed-mcp.json`. Sync deletes the old file on the first
apply. It needs no migration: the first run finds the installed Jira entries
equal to the desired ones and records them (see "First run").

Sync rejects a state file that is not valid JSON of this shape, or that holds
an absolute path or a `..` part, and exits with 2 before any write.

### One rule for every item

On each run sync builds the **desired set** from the repository and
`config.json`. A disabled item is simply not in it. Then, for each item that is
desired or recorded:

An item on disk is **clean** when it equals what sync wants to install, or when
its hash equals the recorded hash. Clean means: nothing there is mine, and git
has the content.

| Desired | On disk | Sync does |
| --- | --- | --- |
| yes | missing | creates it |
| yes | equals the desired content | nothing (records it if unrecorded; fixes a missing executable bit) |
| yes | clean | replaces it. No flag, no backup |
| yes | not clean | blocked without `--replace-existing`. With it: backup, then replace |
| no, recorded | missing | drops the record |
| no, recorded | clean | deletes it. No flag, no backup |
| no, recorded | not clean | blocked without `--replace-existing`. With it: backup, then delete |
| no, not recorded | anything | never looked at |

Items to delete are simply "recorded paths minus desired paths". That covers a
removed source, a removed file inside a skill, a disabled item, and a changed
`harness` list with one mechanism. The separate deletion code for disabled
items goes away.

As today, one blocked item stops the whole run before any write.

### File details

- A symlink at a file's path is never clean, even when it points at matching
  content. With the flag, sync backs up the link itself and replaces the link.
  It never writes through it.
- A directory at a file's path is always blocked, with or without the flag.
- A symlinked parent folder is allowed. People symlink their dotfile folders
  on purpose, and today's sync already works that way.
- After deleting skill files, sync removes folders that became empty, up to but
  not including the tool's skills folder.

### Entry details

- Sync reads each shared file once, applies all its entry changes, and writes
  it once.
- A Jira server name that already exists in the file but is not recorded is
  "not clean". So a server I wrote by hand is never overwritten silently. The
  same holds for a `hooks` key sync never wrote: disabling hooks leaves it
  alone. (Today sync deletes that key regardless.)
- A shared file is never blocked as a whole, and needs no flag, when only
  clean entries change.
- **Every rewrite of a shared file gets a backup.** The rest of the file is not
  in git. Sync rewrites one only when an entry actually changes.
- A JSON file, or the server bucket inside it, that is not an object: error,
  exit 2, no writes. (Today the bucket is silently replaced with `{}`.)
- **TOML is edited as text, then verified by parsing.** The standard library
  can read TOML (`tomllib`) but not write it. So sync removes the lines of its
  own tables, appends the new ones, and then parses the result. The result must
  equal the original parse with exactly sync's tables changed. If not, sync
  exits with 2 and writes nothing. This fixes the known bug where
  `[features] # comment` after a Jira table was deleted with it: the table
  header scan is corrected to allow a trailing comment, and the verification
  catches every case the scan still cannot handle (inline tables, dotted keys,
  quoted names) instead of corrupting the file.

### Backups

- Made only for the "not clean" rows and for shared-file rewrites.
- Location: `~/.config/agent-config/backups/<timestamp>/<path relative to home>`.
- `--clean-backups` deletes that folder. It no longer looks for `.backup-*`
  files in tool folders. The old ones are already gone.

### Writing order and crashes

Sync writes items first and `state.json` last, atomically. There is no journal.
Every crash state fixes itself on the next run: a written item equals its
desired content, so the "equals" row records it; a deleted item is "recorded,
missing", so the record is dropped. One gap remains: sync crashes after
creating an item, and I delete that same source before the next run. That item
stays installed. This is rare enough to accept.

### First run

`state.json` does not exist, so nothing is recorded.

- Items that already equal the desired content are recorded. One summary line,
  no flag.
- Items that differ need `--replace-existing` once and are backed up.
- Anything orphaned before this run is not recorded, so sync leaves it. That is
  the correct reading of "touch nothing else".

A change to `state.json` counts as a pending change. The preview says so,
`--check` returns 1, and only `--apply` writes it.

### Code shape

`main` today builds the file list and decides and writes in one long function.
The new shape:

- `desired_items(config, home)`: returns the wanted files (content, executable)
  and wanted entries (value). This is today's source walking, minus all
  deletion and enable/disable branching beyond "skip it".
- `load_state(home)` / `write_state(home, state)`.
- `decide(desired, state, home, replace_existing)`: applies the table, returns
  a list of actions. It reads the disk and writes nothing.
- `apply(actions)`: backups, writes, deletes, pruning, then the state file.
- Preview, `--check`, and `--apply` differ only in what they do with the
  action list.

## Steps

Each step is a commit that leaves the tests passing.

1. State file, `desired_items`, `decide`, `apply` for **files**. Central
   backups and the new `--clean-backups`.
2. **Entries**: hooks key and JSON MCP servers on the same table. Remove
   `managed-mcp.json`.
3. **TOML entries** with parse verification, including the header scan fix.
4. `AGENTS.md`: rewrite "Using sync" and the MCP paragraph for the new rules.
   Update the docstring in `sync`.

## Tests

Existing tests move to the new behavior. New tests target the table rows, one
scenario each, using `subTest` where the same rule applies to several item
kinds:

- a file removed from a source skill is deleted; its empty folder goes away; an
  unrecorded file next to it stays
- a removed skill, agent, and `bin/` script are deleted
- a changed `harness` moves the skill
- a clean update needs no flag and leaves no backup
- a hand-edited file blocks; with the flag it lands in the central backup
  folder and is replaced; same for a hand-edited file whose source is gone
- a recorded file that went missing is recreated; a lost executable bit is
  repaired
- a symlink with matching content is still blocked
- first run: identical files are recorded without a flag; `--check` returns 1,
  then 0 after apply
- a hand-written `jira` server is not overwritten without the flag
- disabling hooks leaves an unrecorded `hooks` key alone
- TOML: `[features] # comment` after the Jira table survives; an unsupported
  shape exits with 2 and writes nothing
- a malformed `state.json` exits with 2
- `--clean-backups` empties the central folder only

## Verification

- `python -m unittest discover -s tests -v`
- By hand against a temporary `--home`: apply, delete a file from a skill in a
  copy of the repository, apply again. The installed file is gone, no
  `.backup-*` exists anywhere, and `state.json` no longer lists it.
- Not covered by tests: the first run against my real home folder. I run
  `./sync` (preview) there and read the output before applying.

## Follow-up, not in this change

After this merges and one `./sync --apply` has written `state.json`,
`skills/shared/modernize/agents/openai.yaml` can be deleted instead of flipped
(PR #13).
