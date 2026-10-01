---
name: file-pr
description: Use when creating or updating a pull request.
metadata:
  harness: "claude-code, codex, grok, opencode, cursor"
---

# File PR

Before filing, check whether a PR for this branch already exists. If one does,
update it instead of creating a duplicate: push the new commits and rewrite the
description so it matches the branch as it is now. Review the diff locally
against the intended base branch (`origin/main` when that is the repository's
default) to make sure its contents match the goal.

PR titles usually become commit messages, so use the conventional commit-message
format required by the active instructions, including the type and scope. When
the work has an issue (from the branch name, the user, or Jira), end the title
with its ID in parentheses: `type(scope): summary (ISSUE-123)`. Look at recently
merged PRs and Git history for examples that follow those instructions. Prefer a
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

End the description with a `## Verification` section that separates what was
actually run from what was not. Name each check and its result. When a check
has not run yet, say so plainly and say how the user can run it. Do not present
untested work as tested. When verification finishes later, update the section.
Follow any repository PR template.

After the verification section, add one last line, exactly in this form:

> Filed by <model> through <harness>.

`<harness>` is the coding tool running the model, for example `Claude Code` or
`Codex`. Use only known model information; if the exact model is unavailable,
write `an unknown model` instead of guessing. This line is the only
attribution: do not add a harness-supplied line such as "Generated with" or a
Co-authored-by trailer.

Open a ready-for-review PR rather than a draft so review bots can run, unless
the user requests a draft. Return the PR link.
