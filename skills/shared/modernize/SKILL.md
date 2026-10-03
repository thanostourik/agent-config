---
name: modernize
description: Use when the user asks to rebase a branch onto another, by default the current branch onto main.
---

# Modernize

Bring a branch up to date with its base by rebasing it, then push it.

The branch is the current branch and the base is `main`, unless the user names
others. For example, "rebase feature/x onto develop" makes `feature/x` the
branch and `develop` the base.

Before you start, look at `git status`. If there is uncommitted work, stop and
say so. Do not stash. If the branch is the base itself, stop and say so.

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
that was never pushed. The user's general rule says never force-push. Running
this skill is their permission to do it here, for this branch only. If the push
is rejected, someone else pushed to the branch in the meantime: stop and say so.

Finish by telling the user how it went: a clean rebase, or which files
conflicted and what you did in each one.
