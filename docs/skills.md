# Skills and scripts

Every skill installs to all five tools unless noted. The agent starts most of them by
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
| `claude-review`, `codex-review`, `grok-review`, `cursor-grok-review` | One independent review of a change by Claude, Codex, or Grok. `cursor-grok-review` runs Grok through Cursor. You can set each one's model and effort. |
| `review-loop` | Reviews your branch in rounds. The agent fixes the real findings and proves the result works. Then a fresh reviewer checks that proof. |
| `triple-review` | Three reviewers at once, then one short report. One reviews in general, one looks for simpler solutions, one looks for over-engineering. |
| `depatch` | Checks whether code reads like patches piled on patches, and sketches how it would look if written once. It changes no files. |

## Planning and writing

| Skill | What it does |
|---|---|
| `grill-me` | Interviews you about a plan or decision in rounds of numbered questions, each with a recommended answer. |
| `html-communication` | Presents a plan, report, comparison, or UI mockup as one readable HTML file. |
| `bro` | *Manual.* Restates the last message in plain language, without jargon. |

## Coordination and tickets

| Skill | What it does |
|---|---|
| `t3-fan-out` | Starts one T3 thread and worktree per task, waits for all of them, and reports once. |
| `create-jira-issue` | Creates or drafts Jira issues through the Jira MCP server, after asking which project. |

## Verification

These install to Claude Code, Codex, Grok, and Cursor, not to OpenCode.
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
| `mcp-atlassian-start` | Starts the Jira MCP server with the login it reads from Bitwarden. |
| `jira-gate-proxy` | Lets `mcp-atlassian-start --gate` reach a Jira that sits behind Authentik. |
