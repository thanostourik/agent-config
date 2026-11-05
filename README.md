# agent-config

My personal instructions, skills, and settings for Claude Code, Codex, Grok, Cursor,
and OpenCode, kept in one place. I edit the files here, then `./sync` copies them into
each tool's configuration folder.

## Contents

- [Use](#use)
  - [Instructions](#instructions)
- [Configuration](#configuration)
- [Restricted repositories](#restricted-repositories)
- [Skills](#skills)
  - [Skill destinations](#skill-destinations)
  - [Pull requests](#pull-requests)
  - [Reviews](#reviews)
  - [Planning and writing](#planning-and-writing)
  - [Coordination and tickets](#coordination-and-tickets)
  - [Verification](#verification)
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

### Instructions

`instructions/common.md` holds the preferences for every tool. `instructions/<tool>.md`
adds preferences for one tool and may be empty. Sync joins the two, common part first,
and installs the result as that tool's global instructions file: `~/.claude/CLAUDE.md`,
`~/.codex/AGENTS.md`, `~/.grok/AGENTS.md`, `~/.config/opencode/AGENTS.md`, and
`~/.cursor/rules/agent-config.mdc`.

## Configuration

The shipped settings are in `config.defaults.json`. Do not edit that file. Put your
changes in `config.json` next to it (gitignored), then run `./sync --apply`.

`config.json` has the same shape as `config.defaults.json`, but holds only the keys you
change. Every key you leave out keeps its shipped value.

**Turn something off.** Set `enabled` to `false` under `skills`, `agents`, or `hooks`.
The key is the skill's folder name, or the agent's or hook's file name without the
extension. The next `./sync --apply` removes it from every tool.

```json
{ "skills": { "bro": { "enabled": false } } }
```

**Change a skill default.** Copy any key from a skill's `defaults` in
`config.defaults.json` and give it a new value. A list replaces the shipped list.

```json
{ "skills": { "codex-review": { "defaults": { "model": "<model id>" } } } }
```

**Jira and restricted repositories** are set in `config.json` too. See
[SETUP.md](SETUP.md#jira-mcp) and [Restricted repositories](#restricted-repositories).

A model or effort you name in a request always wins over these settings.

## Restricted repositories

Some clients must not see that an agent worked on their code. The agent does two things
only in repositories where you allow them. These are the restricted actions:

- adding its attribution lines ("Filed by ... through ...") to PR descriptions;
- marking a PR ready for review when the work is finished and verified.

Everywhere else the agent leaves no trace: no attribution, and the PR stays a draft for
you to publish.

To allow a repository, add its GitHub owner (all of the owner's repos) or one
`owner/repo` to `allow.restricted` in `config.json`. Entries are not case-sensitive:

```json
{ "allow": { "restricted": ["some-owner", "some-org/some-repo"] } }
```

`config.defaults.json` ships an empty list, so by default no repository allows them.
The agent reads the repository's name with `gh repo view --json nameWithOwner`. A
repository that is not on GitHub never allows them. After editing the list, run
`./sync --apply`: it writes the list into the installed instructions.

## Skills

Every skill installs to every tool unless its `harness` field says otherwise. The agent
starts most of them by itself when the situation fits. Manual skills run only when you
name them:

- Claude Code, Cursor, Grok: type `/skill-name`, for example `/squash-merge-pr`.
- Codex: type `$skill-name`, for example `$squash-merge-pr`.

### Skill destinations

Store skills in `skills/<name>/`. No `harness` means all five tools. To select
only certain destinations, put this in the opening `SKILL.md` frontmatter:

```yaml
metadata:
  harness: "codex, cursor"
```

Names: `claude-code`, `codex`, `grok`, `opencode`, `cursor`, `agents`.
`agents` installs to `~/.agents/skills/`, which some tools also read; include
it explicitly when wanted. The list replaces the default destinations.

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

### Verification

These skills let an agent run the real app and prove its change works before it calls the
work done. They install to Claude Code, Codex, Grok, and Cursor, not OpenCode.

**Set up a project.** These are manual. Run them from the project's root, each in a new
session:

| Skill | What it does |
|---|---|
| `create-project-local-stack` | Writes `local-stack/`: one command that starts everything the app needs, isolated from other copies, with fakes for shared services. Developers run it next to their IDE; agents run many at once to check their work. |
| `create-project-verification-skill` | Writes the project's own `verify-<app>` and `maintain-verify-<app>` skills, a feature map, and an `AGENTS.md` section. When `local-stack/` exists, the skills start the app through it. Add `quick` to write and drive only one feature per surface. |

If the project already has verification skills, `create-project-verification-skill`
stops and asks whether to replace or upgrade them.

**Use it every day.** After setup, the project has its own skills:

| Skill | What it does |
|---|---|
| `verify-<app>` | Agents run it on their own before they call work done. You can also ask for it by name. |
| `/maintain-verify-<app>` | Keeps the feature map up to date: adds features missing from it and drives the ones whose steps changed. Add `map only` to skip driving, or `full audit` to drive every feature. After a `quick` setup, its first run adds and drives the remaining features. |
| `with-verification` | Add "with verify" to any request, in any repository. The agent finds the project's `verify-<app>` skill and runs it before it calls the work done. |

**Keep up with this repository.** When the generator here changes, run `./sync --apply`,
then `/maintain-project-verification-skill` in each project. It updates the project's
skills and map, and drives the features with new or changed steps. Add `map only` to skip
driving, or `full audit` to drive every feature.

**Restricted repositories.** A [restricted repository](#restricted-repositories) must not
hold agent files, so its verification skills live in a **companion repo**: a separate git
repo next to the app checkouts that holds only agent files, plus an `apps` file listing
those checkouts. To set one up, run `create-project-verification-skill` inside the
companion repo instead of the app repo. `with-verification` is installed globally, so it works from the
restricted repository itself: it finds the companion that lists the current checkout and
runs that companion's `verify-<app>` against your change. If the repository has its own
`verify-<app>`, it uses that one instead.

## Scripts

`bin/` scripts install to `~/.local/bin/`.

| Script | What it does |
|---|---|
| `squash-merge-pr` | Does every git and `gh` step of the squash merge. Needs `git`, a logged-in `gh`, and `jq`. |
| `usage-report` | Prints what Codex and Claude Code sessions and their subagents cost in tokens. Needs only Python. |
| `mcp-atlassian-start` | Starts the Jira MCP server with the login read from Bitwarden. |
| `jira-gate-proxy` | Helps `mcp-atlassian-start --gate` reach a Jira behind Apache basic auth. |

## Setup and ownership rules

Some tools need machine setup beyond copying files, such as Jira MCP and stacked PRs.
Paste this into a new agent session:

```
Follow SETUP.md in this repository and complete every setup the tools in this repo need.
```

See [SETUP.md](SETUP.md).

Sync adds, updates, and deletes what it installed, and touches nothing else. It refuses to
replace or delete content it did not write unless you pass `--replace-existing`, and then
saves it under `~/.config/agent-config/backups/<timestamp>/` first. See
[AGENTS.md](AGENTS.md) for the ownership rules, folder layout, install locations, and
tests.
