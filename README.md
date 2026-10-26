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

`config.defaults.json` holds the shipped settings: which skills, agents, hooks,
and Jira MCP are on, and each skill's model, provider, and effort under
`defaults`. To change a setting, put only that setting in `config.json`
(gitignored). Sync reads both, and your value replaces the shipped one. For
example, `{"skills": {"codex-review": {"defaults": {"model": "gpt-6.1-sol"}}}}`
changes one model, and `{"skills": {"bro": {"enabled": false}}}` turns `bro`
off. A list replaces the whole shipped list:
`{"skills": {"review-loop": {"defaults": {"reviewers": ["codex-review", "grok-review"]}}}}`
runs Grok in every review-loop round, not only in its final round.
The next `./sync --apply` removes the copies it installed for disabled items.
A model or effort you name in a request still wins.

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
| `create-project-verification-skill` | Once per project. It writes the project's `verify-<app>` and `maintain-verify-<app>` skills, the feature map and an `AGENTS.md` section. | none: write all features, then fully audit<br>`quick`: write and drive one feature per surface, nothing more |
| `maintain-project-verification-skill` | After this repo's generator changed and you ran `./sync --apply`. It brings the project's skills up to date. | none: update the map, drive the features with new and changed steps<br>`map only`: no drives<br>`full audit`: drive every feature |

After generation, the project's own skills are the daily tools:

| Skill | Use |
|---|---|
| `verify-<app>` | Agents use it on their own before calling work done. You can also ask for it by name. |
| `/maintain-verify-<app>` | Keeps the feature map honest. Adds features missing from the map and drives the features with new and changed steps. Add `map only` or `full audit`. |

`quick` maps and proves only one feature per surface. The next
`/maintain-verify-<app>` finds the other features in the source, adds them and
drives them. If a project already has these skills, `create` stops and asks
whether to replace or upgrade them. Where a project cannot create a
disposable environment, `create` asks you what to do instead of guessing.

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
