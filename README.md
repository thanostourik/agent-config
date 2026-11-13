# agent-config

My personal instructions, skills, and settings for Claude Code, Codex, Grok, Cursor,
and OpenCode, kept in one place. I edit the files here. Then `./sync` copies them into
each tool's configuration folder.

## Install

You need Python 3.11 or newer. There is nothing else to install.

```
git clone https://github.com/thanostourik/agent-config
cd agent-config
./sync            # show what would change, write nothing
./sync --apply    # write the changes
```

Run `./sync --apply` again after every edit or `git pull`.

Sync changes only the files it installed. If a file it wants to write is already there
and sync did not write it, sync stops and names the file. To replace such files, run
`./sync --apply --replace-existing`. Sync first saves the old files under
`~/.config/agent-config/backups/`.

A few tools need more than copied files: Jira, Claude reviews, and stacked PRs. Their
steps are in [SETUP.md](SETUP.md). You can let an agent do them. Paste this into a new
session:

```
Follow SETUP.md in this repository and complete every setup the tools in this repo need.
```

## What sync installs

| Folder | What it holds | Where it goes |
|---|---|---|
| `instructions/` | My preferences. `common.md` is for every tool, `<tool>.md` adds more for one tool. | Each tool's global instructions file, such as `~/.claude/CLAUDE.md` |
| `skills/` | Skills: instructions for one kind of task, such as opening a PR. | Each tool's skills folder |
| `bin/` | Scripts that the skills call. | `~/.local/bin/` |

Sync can also install agent definitions, hooks, and a Jira MCP server. See
[AGENTS.md](AGENTS.md) for those and for the exact install paths.

## Skills

The agent starts most skills by itself when the task fits. Some are manual: they run
only when you type `/skill-name` (`$skill-name` in Codex).

| Group | Skills |
|---|---|
| Pull requests | `file-pr`, `modernize`, `takeover`, `tourik`, `squash-merge-pr` |
| Reviews | `claude-review`, `codex-review`, `grok-review`, `cursor-grok-review`, `review-loop`, `triple-review`, `depatch` |
| Planning and writing | `grill-me`, `html-communication`, `bro` |
| Coordination and tickets | `t3-fan-out`, `create-jira-issue` |
| Verification | `create-project-local-stack`, `create-project-verification-skill`, `maintain-project-verification-skill`, `with-verification` |

[docs/skills.md](docs/skills.md) says what each one does.

## Settings

The shipped settings are in `config.defaults.json`. To change one, create `config.json`
next to it and put only that setting there. Git ignores `config.json`. For example, this
removes the `bro` skill from every tool:

```json
{ "skills": { "bro": { "enabled": false } } }
```

Then run `./sync --apply`. [docs/configuration.md](docs/configuration.md) lists
everything you can set.

## More

- [docs/skills.md](docs/skills.md): every skill and script, and what it does.
- [docs/configuration.md](docs/configuration.md): all settings, and every `./sync` command.
- [docs/verification.md](docs/verification.md): how an agent runs the real app to prove
  its change works.
- [SETUP.md](SETUP.md): extra machine setup for Jira, Claude reviews, and stacked PRs.
- [AGENTS.md](AGENTS.md): how this repository works inside. Folder layout, install paths,
  what sync may overwrite, how to add a skill, and how to run the tests.

## Credits

`create-project-verification-skill` and `maintain-project-verification-skill` started
from poteto's `create-verification-skill` and `maintain-verification-skill` in pstack.
