---
name: file-pr
description: Create or update a concise pull request. Use when creating or updating a PR.
metadata:
  harness: "claude-code, codex, grok, opencode, cursor"
---

# File PR

Before filing, check whether a PR for this branch already exists. Reuse an
existing open PR instead of creating a duplicate. Review the diff locally
against the intended base branch (`origin/main` when that is the repository's
default) to make sure its contents match the goal.

PR titles usually become commit messages, so use the conventional commit-message
format required by the active instructions, including the type, scope, and issue
ID when applicable. Look at recently merged PRs and Git history for examples
that follow those instructions. Prefer a
concise, human-readable title that explains why the change matters:

Bad:
> feat(server): negotiate permessage-deflate on the websocket

Good:
> feat(server): cut websocket frame size by 70%+ with compression

Use measured numbers only when the change's validation supports them.

Open the description with the problem the user wanted solved, then briefly
explain how the final change solves it. Check the description against the final
diff so it describes what actually changed. Do not lead with an implementation
inventory:

Bad:
> Removed implicit workspace carry-over from every "new thread" entry point
> (cmd+n / cmd+shift+o, sidebar v1/v2 buttons, command palette). New threads
> inherit only the project from context; branch, worktree, and env mode always
> come from the configured defaults. Deleted buildContextualThreadOptions,
> startNewThreadInProjectFromContext, and the v1 sidebar's seed-context machinery.

Good:
> The "new worktree" default was ignored when starting new threads on existing
> worktrees. Now new threads consistently use your configured preferences.

Include relevant validation results and follow any repository PR template.
Add a short blurb at the end naming the model and harness (the coding tool
running the model) that made the changes. Use only known model information;
if the exact model is unavailable, say so instead of guessing.

Open a ready-for-review PR rather than a draft so review bots can run, unless
the user requests a draft. Return the PR link.
