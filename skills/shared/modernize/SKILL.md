---
name: modernize
description: Use when the user asks to rebase a branch onto another, by default the current branch onto its PR's base branch.
---

# Modernize

Bring a branch up to date with its base by rebasing it, then push it.

The branch is the current branch, unless the user names another. The base is
the one the user names, otherwise the base branch of the branch's open PR
(`gh pr view <branch> --json baseRefName`), otherwise `main`. For example,
"rebase feature/x onto develop" makes `feature/x` the branch and `develop` the
base.

Before you start, look at `git status`. If there is uncommitted work, stop and
say so. Do not stash. If the branch is the base itself, stop and say so.

If the branch's PR is part of a GitHub stack, fetch, rebase, and push as
"Stacked branches" below says, instead of the next two paragraphs and the push
step. The PR is part of one when
`gh api repos/{owner}/{repo}/pulls/<number> --jq .stack` prints an object, not
`null`.

Fetch, then check that the remote copy of the branch has nothing the local one
lacks: `git log <branch>..origin/<branch>` must print nothing. If it prints
commits, someone else pushed to the branch: stop and say so. The push below
would delete those commits. Skip this check if the branch was never pushed.

Rebase the branch onto `origin/<base>`. The local base branch may be old, so do
not use it.

When a commit conflicts, find out what each side was trying to do and keep
both. If the reason for a change on the base is not obvious, read the commit
that made it. Taking one side whole is fine only when the other side is truly
obsolete. If the two sides disagree about how the code should behave and you
cannot tell which one is right, stop and ask instead of guessing.

When the rebase is done, push with
`git push --force-with-lease -u origin <branch>`. This also works for a branch
that was never pushed. If the push is rejected, someone else pushed to the branch
in the meantime: stop and say so.

Finish by telling the user how it went: a clean rebase, or which files
conflicted and what you did in each one.

## Stacked branches

A plain rebase would replay commits the base already holds as squash commits,
so update the whole stack with `gh stack` instead:

1. If `gh stack view --json` does not list the branch, run
   `gh stack checkout <PR number>`.
2. Fetch. For each layer that `gh stack view --json` does not mark `isMerged`,
   `git cherry <layer> origin/<layer> origin/<trunk>` must print no line that
   starts with `+`. A `+` line is a commit someone else pushed: stop and say
   so. Commits that GitHub rebased after a merge show as `-` lines.
3. Run `gh stack rebase`. Resolve conflicts as above, `git add` the files, and
   run `gh stack rebase --continue`.
4. Run `gh stack push`. If it is rejected, stop and say so.
