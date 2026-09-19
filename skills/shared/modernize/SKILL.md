---
name: modernize
description: Use when the user asks to rebase the current branch onto main.
---

# Modernize

Bring the current branch up to date with main by rebasing it, then push it.

Before you start, look at `git status`. If you are on main, or there is
uncommitted work, stop and say so. Do not stash.

Fetch, then rebase onto `origin/main`. The local `main` may be old, so do not
use it.

When a commit conflicts, find out what each side was trying to do and keep
both. If the reason for a change on main is not obvious, read the commit that
made it. Taking one side whole is fine only when the other side is truly
obsolete. If the two sides disagree about how the code should behave and you
cannot tell which one is right, stop and ask instead of guessing.

When the rebase is done, push with `git push --force-with-lease`. The user's
general rule says never force-push. Running this skill is their permission to
do it here, for this branch only. If the push is rejected, someone else pushed
to the branch in the meantime: stop and say so.

Finish by telling the user how it went: a clean rebase, or which files
conflicted and what you did in each one.
