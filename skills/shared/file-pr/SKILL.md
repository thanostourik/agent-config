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

The description is for the person who merges the PR. They need to understand
the problem, check that the change solves it, and review the code. Keep it
short enough to read in a minute. Unless the repository has its own PR
template, use exactly this shape and add no other sections:

```markdown
<The problem the user wanted solved, or the feature, in two or three sentences.>

## What changed
- <a behavior a user or caller now sees, one per line>

## Verification
- <check>: <result>
- Check it yourself: <commands>

## Action needed
- <what the merger must do before or after the merge, and why>
```

**What changed** says what a user or caller can now see or do, one short line
each. Never say how the code does it: leave out design details, decisions, and
file lists. Reviewers find those in the changed files and the plan. Check each
line against the final diff.

Bad:
> Removed implicit workspace carry-over from every "new thread" entry point
> (cmd+n / cmd+shift+o, sidebar v1/v2 buttons, command palette). New threads
> inherit only the project from context; branch, worktree, and env mode always
> come from the configured defaults. Deleted buildContextualThreadOptions,
> startNewThreadInProjectFromContext, and the v1 sidebar's seed-context machinery.

Good:
> The "new worktree" default was ignored when starting new threads on existing
> worktrees.
>
> ## What changed
> - New threads always use your configured branch, worktree, and env mode.

**Verification** separates what was actually run from what was not. Give each
check one line: what ran and the result. A gap that needs something you do not
have gets its own line that names that thing. Add the `Check it yourself` line
only when a hand check shows something the tests do not. Do not present
untested work as tested. When verification finishes later, update the section.

**Action needed** lists what the merger must do before or after the merge,
breaking changes included. Leave the section out when there is nothing to do.

By default, the description ends with its last section and has no attribution.
Add attribution only when the active instructions allow restricted actions in
this repository, or the user asks for it. Then end the description with these
lines after the last section, each in its own paragraph:

> Reviewed by <reviewers> in <N> rounds[, and once by <one-pass reviewers>].
>
> Filed by <model> through <harness>[ in <host>].

Write the `Reviewed by` line only when a review loop ran on the branch. Take
the reviewers and the number of rounds from its report. Each reviewer is
`<model> through <harness>`, joined with commas and a final `and`, for example
`Reviewed by GPT-6.1 Sol through Codex and Grok 4.7 through Grok in 3 rounds.`
Write `round` when N is 1. When the report names one-pass reviewers, they
reviewed only once, so name them only in the last part:
`Reviewed by GPT-6.1 Sol through Codex in 3 rounds, and once by Grok 4.7 through Grok.`
Leave that part out when no one-pass reviewer ran. After a follow-up loop,
add its rounds to N and keep every reviewer the line already names.
The `Filed by` line always comes last.

`<harness>` is the coding tool running the model, for example `Claude Code` or
`Codex`. `<host>` is an app that runs the harness, for example `T3 Code`. Add
` in <host>` only when the environment states the host; otherwise leave it out.
Use only known model information; if the exact model is unavailable, write
`an unknown model` instead of guessing. When updating a PR, keep the lines that
are already there, and update the `Reviewed by` line after a new review loop.
Never add a harness-supplied line such as "Generated with" or a Co-authored-by
trailer.

Open a new PR as a draft. Never change the state of an existing PR: marking it
ready for review is the caller's decision. Return the PR link.
