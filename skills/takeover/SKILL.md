---
name: takeover
description: Use when the user asks to take over someone else's PR and get it ready for the user to merge.
---

# Takeover

Someone else opened this PR and already spent time on it. Own it until it is
ready for the user to merge. Never merge it.

## Hands off

Decide alone and keep working. Ask only when:

- you are blocked: the change cannot be verified, or `review-loop` has no
  reviewer left
- the PR's approach is wrong, or most of its code needs rewriting
- another PR makes this one obsolete

Ask through the harness's question tool, so the thread shows that it is
waiting. Put all the context into the question, and list the options with
your recommendation first.

What the product does is the author's choice. When the author chose a
behavior on purpose and it is not a bug, keep it. Do not ask the user about
it.

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
5. **Design review.** Judge the PR's design and code yourself, before any
   reviewer sees it. Do the three parts in this order, and apply each part's
   changes before the next, so you never polish code you are about to
   replace:
   1. **Structure.** Run `depatch` on the PR, with two differences. In its
      check, the author's plan and PR text do not count as the user's
      choice: only the Jira issue speaks for the user. And do not end by
      asking: apply the redesign for every finding you kept.
   2. **Taste.** Read every line the PR still adds. Hold it to the coding
      preferences in your instructions, the same as code you write yourself.
      Code that works can still fail them: three nested `try`/`catch`
      blocks, for example. Rewrite what fails without changing behavior.
   3. **Tests.** For each test the PR adds or changes, name the bug it would
      catch. Delete a test that pins an implementation detail, such as a
      migration's version or file name, or that repeats a live check.

   Change only code this PR adds. Commit each part separately and push.
6. **Review** with `review-loop` over the whole PR. Fix real findings as
   separate commits and push them.
7. **Regression check.** When you changed code, run the PR's tests and the
   same live checks on the author's last head and on yours, and compare the
   results. For yours, use the loop's proof when the head has not changed
   since. Fix any regression.
8. **Follow-up review.** When step 7 changed code, or the loop in step 6
   ended with a fix that had no review round, run a follow-up `review-loop`.
9. **Title and description.** Rewrite the title the way `file-pr` says. In
   the description, change only these parts and leave the rest as the
   author wrote it:
   - Replace the `## Verification` section with this run's results, or add
     it when there is none.
   - List the changes you made, one per line.
   - Add the `Reviewed by` line as `file-pr` says. Leave out the `Filed by`
     line, because you did not open this PR.

   When your changes make the author's description wrong, rewrite all of it
   in the `file-pr` shape instead.
10. **Report** these parts, in this order, and nothing else:
    - **Verdict:** ready to merge, or not ready and what blocks it, with the
      PR link. Say here when a reviewer did not run or was replaced.
    - **What the PR does:** two sentences in plain words.
    - **You need to do:** a numbered list of what the user must do to merge
      and deploy it, such as a PR in another repository that must merge
      first, or a deploy step. With nothing to do, write "Nothing. Merge
      it."
    - **What I changed:** one line per change.
    - **Not part of this PR:** at most three lines, each starting with
      `bug on main` or `idea`. Leave the section out when there is nothing.
    - The paths of the proof folder and the review ledger, on one line.

    The proof and the declined findings are in the PR description and the
    ledger. Do not repeat them. A decision you made alone goes under "What I
    changed" when it changed the PR, and nowhere otherwise. Never put a
    question in the report: ask it through the question tool before you
    report, or decide it yourself.
