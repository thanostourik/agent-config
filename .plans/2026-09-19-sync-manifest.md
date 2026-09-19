# Sync mirrors the repository through a manifest

## Problem

Sync should make the installed files match this repository, for the files it
owns, and leave everything else alone. Today it falls short in three ways:

- A file removed from a source skill stays installed. Example: deleting
  `skills/shared/modernize/agents/openai.yaml` leaves the copy in
  `~/.codex/skills/modernize/agents/`.
- A skill, agent, or `bin/` script removed from the repository stays installed
  forever. Only `enabled: false` in `config.json` removes it.
- Backups sit next to the live files. A backup in `~/.local/bin/` is an
  executable on `PATH`. A backup of a skill folder sits inside the skills
  directory, where the tool may load it as a second skill. Most backups hold
  content sync wrote itself, which git already has.

The cause is the same each time: sync does not remember what it installed.

## Design

Sync keeps a manifest: a JSON file listing every file it installed, with a
SHA-256 hash of the content it wrote.

- Location: `~/.config/agent-config/manifest.json`, next to `managed-mcp.json`.
- Shape: `{"files": {"<path relative to home>": "<sha256>"}}`.

Everything sync needs for bookkeeping lives under `~/.config/agent-config/`:
the manifest, `managed-mcp.json`, and backups. The tool folders and
`~/.local/bin/` hold only installed content.

### Decision per file

The desired set is what the repository and `config.json` say should be
installed. A disabled item is simply not in the desired set.

| Repository | Manifest | Disk | Sync does |
| --- | --- | --- | --- |
| wants it | any | same content as source | nothing; records the hash |
| wants it | listed | matches the manifest hash | replaces it, no backup, no flag |
| wants it | listed | differs from the manifest hash | blocked without `--replace-existing`; with it, backup then replace |
| wants it | not listed | missing | creates it |
| wants it | not listed | exists, differs from source | blocked without `--replace-existing`; with it, backup then replace |
| gone | listed | matches the manifest hash | deletes it, no backup |
| gone | listed | differs from the manifest hash | blocked without `--replace-existing`; with it, backup then delete |
| gone | listed | missing | drops the manifest entry |
| gone | not listed | any | never touched |

After deleting files, sync removes the folders that became empty, up to but not
including the tool's skills or agents root.

This replaces the current `deletes` list. Disabling an item and deleting its
source now take the same path.

### Backups

- A backup is made only when sync overwrites or deletes content it did not
  write (the "differs" rows above).
- Backups go to `~/.config/agent-config/backups/<timestamp>/<path relative to home>`.
- `--clean-backups` deletes that one folder.

### Merged files

`~/.claude/settings.json` and the five MCP files are shared with the tools.
Sync owns one key inside each, not the file.

- They stay out of the manifest. `managed-mcp.json` keeps recording the Jira
  server names.
- Sync always keeps a backup when it rewrites one, in the central backups
  folder, because the rest of the file is not in git.
- Proposed change: drop the `--replace-existing` requirement for these files.
  Sync only replaces its own key, so the flag protects nothing, and the tools
  rewrite these files often enough that the flag would be needed every time.

### First run

The manifest starts empty. A file whose content already equals the source is
recorded as owned without a prompt. A file that differs needs
`--replace-existing` once. Stale files that were orphaned before the first
manifest run are not on the manifest, so sync does not clean them.

### Unchanged

- `./sync` with no flag previews, `--check` exit codes, `--home`.
- Symlink safety: sync never writes through a symlink. A symlink at a target
  counts as "differs".
- A missing executable bit on a `bin/` file still triggers a rewrite.

## Steps

1. Manifest read and write, and the per-file decision table, replacing the
   `changes` / `deletes` logic in `main`.
2. Central backups and the new `--clean-backups`.
3. Merged files: central backup, no flag.
4. Tests, focused on the table:
   - a file removed from a source skill is deleted
   - a removed skill is deleted and its empty folder goes away
   - an unlisted file inside an installed skill folder is left alone
   - a hand-edited owned file blocks, then is backed up centrally and replaced
   - first run adopts identical files without a flag
   - existing backup and disable tests move to the new behavior
5. Update the "Using sync" section of `AGENTS.md`.

## Verification

- `python -m unittest discover -s tests -v`
- A run against a temporary `--home`: install, remove a file from a skill in a
  copy of the repository, sync again, and confirm the installed file is gone and
  no `.backup-*` exists in any tool folder.

## Follow-up, not in this change

After this merges and one `./sync --apply` has recorded the manifest,
`skills/shared/modernize/agents/openai.yaml` can be deleted instead of flipped
(PR #13).
