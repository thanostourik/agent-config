# agent-config

My personal instructions, skills, and settings for Claude Code, Codex, Grok, Cursor,
and OpenCode, kept in one place. I edit the files here, then `./sync` copies them into
each tool's configuration folder.

## Contents

- [Use](#use)
- [Configuration](#configuration)
- [Restricted repositories](#restricted-repositories)
- [Skills](#skills)
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

## Configuration

`config.defaults.json` holds the shipped settings. `config.json` (gitignored) overrides
single settings. Sync reads both, and your value replaces the shipped one.

Put only the setting you change in `config.json`. Then run `./sync --apply`.

| I want to | Put this in `config.json` |
|---|---|
| Change a skill's model | `{"skills": {"codex-review": {"defaults": {"model": "gpt-6.1-sol"}}}}` |
| Turn a skill off | `{"skills": {"bro": {"enabled": false}}}` |
| Change a list | `{"skills": {"review-loop": {"defaults": {"reviewers": ["codex-review", "grok-review"]}}}}` |
| Add a Jira instance | `{"mcp": {"jira": {"instances": {"work": {"url": "<Jira URL>"}}}}}` |
| Allow restricted actions in a repo | `{"allow": {"restricted": ["owner/repo"]}}` |

What to know:

- **What the file holds:** which skills, agents, hooks, and Jira MCP are on, and each
  skill's model, provider, and effort under `defaults`.
- **Objects merge key by key.** Setting one skill's model keeps its other settings.
- **A list replaces the whole shipped list.** In the example above, `review-loop` runs
  both `codex-review` and `grok-review` in every round, instead of Grok only once.
- **Turning something off** removes the copies sync installed. The next
  `./sync --apply` does this.
- **A model or effort you name in a request still wins** over these settings.
- **Jira URLs** go only in `config.json`, never in git.

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
`./sync --apply`: it writes the list into the instructions and the `file-pr` skill.

## Skills

Every skill installs to every tool unless its `harness` field says otherwise. The agent
starts most of them by itself when the situation fits. Skills marked *manual* run only
when you name them:

- Claude Code, Cursor, Grok: type `/skill-name`, for example `/squash-merge-pr`.
- Codex: type `$skill-name`, for example `$squash-merge-pr`.

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

Verification skills let an agent drive the real app and prove its work before it calls
the work done. These four skills come from this repository. Each project then gets its own
`verify-<app>` skills. They install to Claude Code, Codex, Grok, and Cursor, not OpenCode.

| Skill | When | What it does |
|---|---|---|
| `create-project-local-stack` | Once per project, before the verification skills. | Generates `local-stack/` in the project: one command that starts everything the app needs, isolated per stack, with fakes for shared services. |
| `create-project-verification-skill` | Once per project. | Writes the project's `verify-<app>` and `maintain-verify-<app>` skills, the feature map and an `AGENTS.md` section. |
| `maintain-project-verification-skill` | After this repo's generator changed and you ran `./sync --apply`. | Brings the project's skills up to date. |
| `with-verification` | Any task, in any repository. | Add "with verify" to a request. The agent finds the project's `verify-<app>` skill and runs it before calling the work done. See below. |

Run the two `*-project-verification-skill` skills from the project's root, in a new
session. Both are manual: the agent never starts them on its own. Add a mode after the
name, for example `/create-project-verification-skill quick`.

| Skill | Modes |
|---|---|
| `create-project-verification-skill` | none: write all features, then fully audit<br>`quick`: write and drive one feature per surface, nothing more |
| `maintain-project-verification-skill` | none: update the map, drive the features with new and changed steps<br>`map only`: no drives<br>`full audit`: drive every feature |

`quick` maps and proves only one feature per surface. The next
`/maintain-verify-<app>` finds the other features in the source, adds them and drives
them. If a project already has these skills, `create` stops and asks whether to replace
or upgrade them. Where a project cannot create a disposable environment, `create` asks
you what to do instead of guessing.

**After generation**, the project's own skills are the daily tools:

| Skill | Use |
|---|---|
| `verify-<app>` | Agents use it on their own before calling work done. You can also ask for it by name. |
| `/maintain-verify-<app>` | Keeps the feature map honest. Adds features missing from the map and drives the features with new and changed steps. Add `map only` or `full audit`. |

**`with-verification` and restricted repositories.** A restricted repository (see
[above](#restricted-repositories)) must not contain agent files. So its verification
skills live in a **companion repo**: a separate git repo next to the app checkouts that
holds only the agent files. `with-verification` is installed globally, so it works from
any repository. It finds the companion that lists the current checkout, drives that
companion's `verify-<app>` skill against your diff, and reports. If the repository has its
own `verify-<app>` skill, it uses that one instead. Two runs share one companion, so it
takes a lock first. If the change alters the feature map, it asks whether to only report
or to update the map in the companion through a draft PR.

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
