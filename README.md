# agent-config

My personal instructions, skills, hooks, and agent definitions for Claude Code, Codex,
Grok, Cursor, and OpenCode, kept in one place.

## Use

```
./sync                                # show what would change, write nothing
./sync --check                        # same, but exit 1 when changes are pending
./sync --apply                        # make each tool's config folder match this repository
./sync --apply --replace-existing     # also replace content sync did not write, keeping a backup
./sync --clean-backups                # delete the backups sync has saved
./sync --home /tmp/test --apply       # install into another folder, for testing
```

To turn a skill, agent, hook, or Jira MCP off, copy `config.example.json` to
`config.json` and set that entry's `enabled` to `false`. Do not commit
`config.json`. Sync treats a missing entry as on. The next `./sync --apply`
removes the copies it installed for disabled items.

Jira MCP URLs also go in `config.json` (never in git). Some tools need machine
setup beyond copying files. Paste this into a new agent session:

```
Follow SETUP.md in this repository and complete every setup the tools in this repo need.
```

See [SETUP.md](SETUP.md). Sync adds, updates, and deletes what it installed,
and touches nothing else. It refuses to replace or delete content it did not
write unless you pass `--replace-existing`, and then saves it under
`~/.config/agent-config/backups/<timestamp>/` first. See [AGENTS.md](AGENTS.md)
for the ownership rules, folder layout, install locations, and tests.
