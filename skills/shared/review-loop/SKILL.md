---
name: review-loop
description: Use when the user asks for a review loop, or to have your own branch reviewed, fixed, and proven before handing it over.
---

# Review loop

You wrote the change on this branch. Independent reviewers review it in
rounds. You check what they find, fix the real problems, and prove the result
works. A fresh reviewer then checks that proof against the intent.

## Setup

- **Reviewers:** the review skills the user names; otherwise
  `{{defaults.reviewers}}`. Each entry is a review skill, such as
  `codex-review` or `grok-review`. That skill's own defaults give the model
  and effort, and it says how to run and wait for the review. If a listed
  skill is not available to you, tell the user and stop. Do not substitute
  another reviewer.
- **Target:** the current branch against its base: the PR's base branch, or
  `origin/main` when there is no PR.
- **Ledger:** `.plans/scratch/<branch>/review-ledger.md`, one table row per
  finding:

  | id | reviewer | severity | finding | outcome | reason | commit |
  | --- | --- | --- | --- | --- | --- | --- |
  | R1-1 | grok-review | high | `src/a.ts:40` drops the last page | fixed | | `abc123` |
  | R1-2 | codex-review, grok-review | medium | `src/b.ts:12` races on save | declined | the lock in `save()` serializes it | `abc123` |

  `reviewer` lists every reviewer that raised the finding, so the user can see
  each reviewer's hit rate. `severity` is `high`, `medium`, `low`, or `nit`,
  set by your own check of the code, not by the reviewer's label.
  `commit` is the head commit when you decided.

## Budget

Three rounds. Raise it to five when a finding concerns security, permissions,
auth, data loss, or state and concurrency, or when the user asks.

## A round

1. Commit your work, so every reviewer sees the same code. Pushing follows the
   caller's rules; this skill never pushes.
2. Start every reviewer before you end your turn to wait. Each runs its tool's built-in review command
   on the whole branch against its base, the same command every round. Round
   two is not a review of the changes since round one.
   - In T3 Code, a review skill with a T3 delegate path runs that way: a
     `delegate_task` whose task is only the slash command, with no `role`.
     Today that is `grok-review`.
   - Every other reviewer runs its skill's CLI command. `codex-review` always
     does.
   - A skill without a built-in review command, such as `cursor-grok-review`,
     gets a prompt with only the target and the git command that shows it,
     `git diff <base>...HEAD`. So does a reviewer whose built-in command
     cannot use the base: Grok's `/review` always compares with `origin/main`.
3. Keep reviewers blind. Give them no intent, no ledger, no earlier or
   declined findings, and nothing else you wrote. Context from the author
   biases the reviewer.
4. Wait until every reviewer finishes. If one fails, start it once more. If it
   fails again, go on without it and say so in the report.
5. Check each finding against the code:
   - Already in the ledger: add the reviewer to that row and skip it, unless
     the code around it changed since that row's commit. Then decide again.
   - Real: fix it.
   - Not real: decline it with a reason a reader can check.
   Record every new finding in the ledger.
6. After fixes that change behavior, verify the affected features the way the
   project does, then commit.

Stop when a round is clean: every reviewer finished, and after skipping what
the ledger already holds, nothing above `nit` is left. Also stop when the budget is spent. A spent
budget is not approval; report what is still open.

## Proof

1. Verify the head commit the way the project does. Keep the raw proof in
   `.plans/scratch/<branch>/proof/`: screenshots, transcripts, and command
   output with exit codes.
2. Run one evidence check with a fresh reviewer: the first reviewer in the
   list, through its skill's custom-prompt mode. The prompt holds only:
   - The intent, quoted word for word: the Jira ticket or the user's request.
     When neither exists, the acceptance criteria you wrote into the PR
     description.
   - The paths of the raw proof files. No summary from you.
   - The question: for each criterion, does the proof show it working? Answer
     shown, not shown, or shows a bug, and name the file that shows it.
3. Proof missing: gather it and run the evidence check once more.
4. Proof shows a bug: fix it, then run another round if the budget allows,
   and prove again. If the budget is spent, fix and verify it, and report that
   the fix had no review round.

## Report

When you may update the PR, put this line in its description:
`Reviewed with review-loop: <N> rounds with <reviewers>`. Otherwise put it in
the report.

The report lists:

- The rounds: head commit and result of each, and why the loop stopped.
- The reviewers.
- The fixed findings.
- The declined findings, each with its reason.
- The evidence check's answer for each criterion.
- What is unverified.
