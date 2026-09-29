---
name: squash-merge-pr
description: Squash merge a PR, update local main, and delete the PR's local and remote branches. Use only when the user explicitly invokes squash-merge-pr.
disable-model-invocation: true
---

# Squash merge PR

Run only when the user explicitly invokes this skill. A general request to
merge a PR does not invoke it. Invoking it authorizes the squash merge,
updating local main, and deleting this PR's local and remote branches without
asking again.

Stop on any failed command or unmet check. Report what succeeded and what
remains. Do not stash, discard work, rebase, bypass merge requirements, or
enable automatic merging.

## Prepare

Check `git status`. If there is uncommitted work, stop and say so.

Use the PR the user specified, or find the PR for the current branch with
`gh pr view`. If the target is ambiguous, ask. Read its URL, state, base
branch, head branch, and head commit. Confirm it is open, targets `main`,
belongs to the repository at `origin`, and is not from a fork. Confirm the
current local branch is the PR's head branch and its tip equals the PR's head
commit. Otherwise stop and explain the mismatch. Record that commit for
the merge and cleanup checks. Never delete `main`.

## Merge and update main

Confirm the PR is mergeable and its required checks have passed. If checks
are pending or failing, or the merge status is unknown or blocked, stop.

Squash merge with `gh pr merge "$pr_url" --squash --match-head-commit "$pr_head"`,
using the recorded PR URL and head commit. Do not use `--delete-branch`:
branch cleanup comes after updating main.

Read the PR again and confirm its state is `MERGED` before continuing.
If GitHub queued the merge, stop and report that cleanup is still pending.

Run `git switch main`, then `git pull --ff-only origin main`. This updates
main without creating a merge commit. Confirm local main equals
`origin/main` and contains the PR's reported merge commit before cleanup.
If main has local-only commits or the merge commit is missing, stop.

## Delete the PR branches

Check the local PR branch and the branch on `origin` again. Each existing
branch must still point to the recorded PR head commit. If either has changed,
stop rather than deleting newer work. A branch already deleted needs no action.

Delete the remote PR branch with `git push origin --delete "$pr_branch"`,
then delete the local PR branch with `git branch -D "$pr_branch"`.
The checked local branch needs `-D` because squash merging does not put its
original commits into main's history. This permission applies only to that
branch after the checks above.

Verify that both PR branches are absent, the current branch is `main`, and
the working tree is clean. Report the PR link, merge result, main update,
and branch cleanup result.
