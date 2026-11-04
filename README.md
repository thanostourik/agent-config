# agent-config

My personal instructions, skills, and settings for Claude Code, Codex, Grok, Cursor,
and OpenCode, kept in one place. I edit the files here, then `./sync` copies them into
each tool's configuration folder.

## Contents

- [Use](#use)
- [Project verification skills](#project-verification-skills)
- [Other skills](#other-skills)
- [Scripts](#scripts)
- [Setup and ownership rules](#setup-and-ownership-rules)

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
runs Grok in every review-loop round, not only once.
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

## Other skills

Each skill installs to every tool unless its `harness` field says otherwise. The agent
picks most of them by itself from the situation. Skills marked *manual* run only when
you name them.

### Pull requests

| Skill | What it does |
|---|---|
| `file-pr` | Opens a draft PR, or updates the existing one, with a title and description that match the branch. |
| `modernize` | Rebases a branch onto its base (by default the PR's base branch) and pushes it. |
| `takeover` | Takes over a colleague's PR and works on it until it is ready for you to merge. It never merges. |
| `squash-merge-pr` | *Manual.* Squash-merges the PR and cleans up its branches and worktree. |
| `tourik` | "Tourik mode": you are not watching, the agent owns the work until the PR is ready. It never merges. |

### Reviews

| Skill | What it does |
|---|---|
| `claude-review`, `codex-review`, `grok-review`, `cursor-grok-review` | One independent review of a change by Claude, Codex, or Grok (Grok also through Cursor). Model and effort come from `config.defaults.json`. |
| `review-loop` | Reviews your branch in rounds. The agent fixes real findings and proves the result works, then a fresh reviewer checks that proof. |
| `triple-review` | Three reviewers at once (general, simplicity, over-engineering), then one short report. |
| `depatch` | Read-only. Checks whether code reads like patches piled on patches and sketches how it would look if written once. |

### Planning and writing

| Skill | What it does |
|---|---|
| `grill-me` | Interviews you about a plan or decision in rounds of numbered questions, each with a recommended answer. |
| `html-communication` | Presents plans, reports, comparisons, or UI mockups as one readable HTML file. |
| `bro` | *Manual.* Restates the last message in plain language, without jargon. |

### Coordination and tickets

| Skill | What it does |
|---|---|
| `t3-fan-out` | Starts one T3 thread and worktree per task, waits for all of them, and reports once. |
| `create-jira-issue` | Creates (or drafts) Jira issues through the Jira MCP, after asking which project. |

### Local stack and verification

| Skill | What it does |
|---|---|
| `create-project-local-stack` | Generates `local-stack/` in a project: one command that starts everything the app needs, isolated per stack, with fakes for shared services. |
| `with-verification` | Add "with verify" to a task and the agent drives the project's `verify-<app>` skill before calling the work done. |

The two skills that create and maintain `verify-<app>` are under
[Project verification skills](#project-verification-skills).

## Scripts

`bin/` scripts install to `~/.local/bin/`.

| Script | What it does |
|---|---|
| `squash-merge-pr` | Does every git and `gh` step of the squash merge. Needs `git`, a logged-in `gh`, and `jq`. |
| `usage-report` | Prints what Codex and Claude Code sessions and their subagents cost in tokens. Needs only Python. |
| `mcp-atlassian-start` | Starts the Jira MCP server with the login read from Bitwarden. |
| `jira-gate-proxy` | Helps `mcp-atlassian-start --gate` reach a Jira behind Apache basic auth. |

## Setup and ownership rules

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
