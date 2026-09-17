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

To turn a skill, agent, hook, or Jira MCP off, copy `config.example.json` to
`config.json` and set that entry's `enabled` to `false`. Do not commit
`config.json`. Sync treats a missing entry as on. The next `./sync --apply`
removes the copies it installed for disabled items.

Jira MCP URLs also go in `config.json` (never in git). Paste this into a new
agent session to wire it up:

```
Follow SETUP.md in this repository to wire Jira MCP into Claude Code, Codex, Grok, Cursor, and OpenCode. Use my existing Bitwarden login whose URI is the Jira URL. Do not put the URL or credentials in git, do not create or rename Bitwarden items, and do not run bw login from the agent.
```

See [SETUP.md](SETUP.md) for the steps. Sync refuses to overwrite a file that
differs unless you pass `--replace-existing`. Backups are saved next to the
replaced file as `<file>.backup-<timestamp>`. See [AGENTS.md](AGENTS.md) for
the folder layout, install locations, and tests.
