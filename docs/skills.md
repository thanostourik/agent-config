# Skills and scripts

Every skill installs to all six tools unless noted. The agent starts most of them by
itself when the task fits. Skills marked *Manual* run only when you name them:

- Claude Code, Cursor, Grok: type `/skill-name`, for example `/squash-merge-pr`.
- Codex: type `$skill-name`, for example `$squash-merge-pr`.

To turn a skill off or change its defaults, see [configuration.md](configuration.md).
To add a skill or choose which tools get it, see [AGENTS.md](../AGENTS.md).

## Pull requests

| Skill | What it does |
|---|---|
| `file-pr` | Opens a draft PR, or updates the existing one, with a title and description that match the branch. |
| `modernize` | Rebases a branch onto its base (by default the PR's base branch) and pushes it. |
| `takeover` | Takes over a colleague's PR and works on it until it is ready for you to merge. It never merges. |
| `tourik` | "Tourik mode": you are not watching, and the agent owns the work until the PR is ready. It never merges. |
| `squash-merge-pr` | *Manual.* Squash-merges the PR and cleans up its branches and worktree. |

## Reviews

| Skill | What it does |
|---|---|
| `peer-review` | Independent read-only review: runs your default fast reviewers in parallel, a named provider, or `deep` mode (adds deep reviewers in the background while fast results report first). |
| `peer-review-loop` | Reviews your branch in rounds using `peer-review`'s fast and deep reviewers, fixes real findings, proves the result works, and checks that proof with a fresh reviewer. |
| `depatch` | Checks whether code reads like patches piled on patches or is more complicated than it needs to be. A fresh agent designs it from scratch without seeing the code, then compares. It changes no code. |

## Planning and writing

| Skill | What it does |
|---|---|
| `grill-me` | Interviews you about a plan or decision in rounds of numbered questions, each with a recommended answer. |
| `html-communication` | Presents a plan, report, comparison, or UI mockup as one readable HTML file. |
| `draftie` | Uploads one HTML file to draftie and gives you its link, or reads a draft back from a draftie link. Needs `npx draftie auth login` once. |
| `bro` | *Manual.* Restates the last message in plain language, without jargon. |

## Coordination and tickets

| Skill | What it does |
|---|---|
| `t3-fan-out` | Starts one T3 thread and worktree per task, waits for all of them, and reports once. Say "fan out" to trigger it, "detach" to let the threads run on their own, or "delegates" to run the tasks as delegates of the current thread. |
| `create-jira-issue` | Creates or drafts Jira issues through the Jira MCP server, after asking which project. |

## Verification

These install to Claude Code, Codex, Grok, Cursor, and Antigravity, not to OpenCode.
[verification.md](verification.md) explains how to use them.

| Skill | What it does |
|---|---|
| `create-project-local-stack` | *Manual.* Writes `local-stack/` in a project: one command that starts everything the app needs. |
| `create-project-verification-skill` | *Manual.* Writes the project's own `verify-<app>` skill. |
| `maintain-project-verification-skill` | *Manual.* Updates a project's `verify-<app>` skill after the generator here changed. |
| `with-verification` | Add "with verify" to any request. The agent runs the project's `verify-<app>` skill before it calls the work done. |

## Scripts

Sync installs the scripts in `bin/` to `~/.local/bin/`.

| Script | What it does |
|---|---|
| `squash-merge-pr` | Does every git and `gh` step of the squash merge. Needs `git`, a logged-in `gh`, and `jq`. |
| `usage-report` | Prints how many tokens each Codex and Claude Code session used, subagents included. Needs only Python. |
| `verify-time` | Prints how much of the working time of Claude Code sessions went into `bin/verify`: drives, stack starts, drive rounds, repeated drives and waiting for room. Needs only Python. |
| `mcp-atlassian-start` | Starts the Jira MCP server with the login it reads from Bitwarden. |
| `jira-gate-proxy` | Lets `mcp-atlassian-start --gate` reach a Jira that sits behind Authentik. |
| `guard-command` | Pre-command hook script that blocks irreversible system-wide destructive commands (Docker prunes, bulk Docker wipes, recursive `rm` on root/home/system directories, and raw disk writes). |
