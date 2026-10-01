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

## Project verification skills

Two skills set up and maintain verification for one project. Run them from the
project's root, in a new session. Both are manual: the agent never starts them
on its own.

Start a skill like this:

- Claude Code, Cursor, Grok: type `/skill-name` and the mode, for example
  `/create-project-verification-skill quick`.
- Codex: type `$skill-name` and the mode, for example
  `$create-project-verification-skill quick`.

| Skill | When | Modes |
|---|---|---|
| `create-project-verification-skill` | Once per project. It writes the project's `verify-<app>` and `maintain-verify-<app>` skills, the feature map and an `AGENTS.md` section. | none: write, then fully audit<br>`quick`: write, then a smoke proof of one feature per surface. Features not driven stay `draft`. |
| `maintain-project-verification-skill` | After this repo's generator changed and you ran `./sync --apply`. It brings the project's skills up to date. | none: update the map, drive new, changed and `draft` steps<br>`map only`: no drives<br>`full audit`: drive every step<br>`quick`: like none, one feature per surface |

After generation, the project's own skills are the daily tools:

| Skill | Use |
|---|---|
| `verify-<app>` | Agents use it on their own before calling work done. You can also ask for it by name. |
| `/maintain-verify-<app>` | Keeps the feature map honest. Drives new, changed and `draft` steps. Add `map only` or `full audit`. |

`quick` skips the full audit, so undriven features stay `draft` until the next
`/maintain-verify-<app>` drives them. Where a project cannot create a
disposable environment, the create skill asks you what to do instead of
guessing.

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
