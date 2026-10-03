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

Run `~/.local/bin/squash-merge-pr` from the PR's branch checkout. Add the PR
number or URL only if the user gave one. The script does every git and gh step
and every check. Do not run those steps yourself.

If the script exits with an error, report its output (the step it stopped at
and whether the PR was merged) and stop. Do not retry, work around it, or
finish the remaining steps by hand.

If it succeeds, report the PR link, the merge result, the main update, and the
branch cleanup result from its output.
