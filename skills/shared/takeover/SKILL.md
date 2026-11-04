---
name: takeover
description: Use when the user asks to take over someone else's PR and get it ready for the user to merge.
---

# Takeover

Someone else opened this PR. Own it until it is ready for the user to merge.
Never merge it.

## Steps

1. **Intent.** Read the PR's title, body, commits and full diff, its Jira
   issue, and any plan it adds in `.plans/`. Without a Jira issue, write 3 to
   5 checkable criteria from the PR body to
   `.plans/scratch/<branch>/criteria.md`.
2. **Branch.** Check out the PR's own branch. You may commit, push, rebase,
   and force-push with `--force-with-lease` to it without asking.
3. **Rebase** with `modernize` when the branch is behind its base. A rebase
   needs no review round of its own.
4. **Other repositories.** When the project's `AGENTS.md` names other
   repositories, check whether this change needs a matching change in one of
   them: an open PR there, or a change nobody has made yet.
5. **Review** with `review-loop` over the whole PR. Fix real findings as
   separate commits and push them.
6. **Depatch.** Run `depatch`. If it finds patching, do its redesign.
7. **Regression check.** When your commits changed behavior, run the PR's
   tests and the same live checks on the author's last head and on yours,
   and compare the results. Fix any regression.
8. **Follow-up review.** When steps 6 or 7 changed code, or the loop in step
   5 ended with a fix that had no review round, run a follow-up `review-loop`.
9. **Title and description.** Rewrite the title the way `file-pr` says. In
   the description, change only these parts and leave the rest as the
   author wrote it:
   - Replace the `## Verification` section with this run's results, or add
     it when there is none.
   - List the fixes you made, one behavior per line.
   - Add the `Reviewed by` line as `file-pr` says. Leave out the `Filed by`
     line, because you did not open this PR.

   When your changes make the author's description wrong, rewrite all of it
   in the `file-pr` shape instead.
10. **Report:**
    - the verdict: ready to merge, or not ready and what it still needs
    - the PR link and the proof
    - the PRs in other repositories that must merge first, or "none"
    - every decision you made alone
    - the declined findings, with reasons, and follow-ups
