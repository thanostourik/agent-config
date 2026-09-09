# agent-config

My personal instructions, skills, and agent definitions for Claude Code, Codex,
Grok, Cursor, and OpenCode, kept in one place.

## Use

```
./sync            # show what would change
./sync --apply    # copy the files into each tool's config folder
```

If a file already exists with different content, sync refuses to overwrite it.
Add `--replace-existing` to allow it. Sync keeps a timestamped backup of the old file.

See [AGENTS.md](AGENTS.md) for the folder layout, install locations, and tests.
