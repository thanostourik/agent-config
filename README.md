# agent-config

My personal instructions, skills, hooks, and agent definitions for Claude Code, Codex,
Grok, Cursor, and OpenCode, kept in one place.

## Use

```
./sync                                # show what would change, write nothing
./sync --check                        # same, but exit 1 when changes are pending
./sync --apply                        # copy the files into each tool's config folder
./sync --apply --replace-existing     # also overwrite files that differ, keeping a backup
./sync --clean-backups                # delete the backups next to installed files
./sync --home /tmp/test --apply       # install into another folder, for testing
```

Sync refuses to overwrite a file that differs unless you pass `--replace-existing`.
Backups are saved next to the replaced file as `<file>.backup-<timestamp>`.

See [AGENTS.md](AGENTS.md) for the folder layout, install locations, and tests.
