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
  `{{defaults.reviewers}}`. Each entry is a review skill. That skill's own
  defaults give the model and effort, and it says how to run and wait for the
  review. If a listed
  skill is not available to you, tell the user and stop. Do not substitute
  another reviewer.
- **Target:** the current branch against its base: the PR's base branch, or
  `origin/main` when there is no PR. Note `git diff --shortstat <base>...HEAD`
  before round one.
- **Ledger:** `.plans/scratch/<branch>/review-ledger.md`, one table row per
  finding:

  | id | reviewer | severity | finding | outcome | reason | commit |
  | --- | --- | --- | --- | --- | --- | --- |
  | R1-1 | b-review | high | `src/a.ts:40` drops the last page | fixed | | `abc123` |
  | R1-2 | a-review, b-review | medium | `src/b.ts:12` races on save | declined | the lock in `save()` serializes it | `abc123` |

  `reviewer` lists every reviewer that raised the finding, so the user can see
  each reviewer's hit rate. `severity` is `high`, `medium`, `low`, or `nit`,
  set by your own check of the code, not by the reviewer's label.
  `commit` is the head commit when you decided.

## Budget

{{defaults.rounds}} rounds. Raise it to {{defaults.max_rounds}} when a
finding concerns security, permissions, auth, data loss, or state and
concurrency, or when the user asks. A number of rounds the user names in the
request wins.

## A round

1. Commit your work, so every reviewer sees the same code. Pushing follows the
   caller's rules; this skill never pushes.
2. Start every reviewer before you end your turn to wait. Each reviews the
   whole branch against its base the way its skill says, the same way every
   round. Round two is not a review of the changes since round one.
3. Keep reviewers blind. Give them no intent, no ledger, no earlier or
   declined findings, and nothing else you wrote. Context from the author
   biases the reviewer.
4. Wait until every reviewer finishes. If one fails, start it once more. If it
   fails again, go on without it. That round is not clean, and the report
   says so.
5. Check each finding against the code. Review makes the change correct, not
   bigger.
   - Declined or out of scope earlier: add the reviewer to that row and skip
     it, unless the code around it changed since that row's commit. Then
     decide again.
   - Fixed earlier and raised again: check it again; the fix may not hold.
   - Real and caused by this branch, in code it changed or as a bug it
     introduces: fix it with the smallest change that resolves it. No
     refactors, renames, or new features.
   - Real but already there before this branch: record it as `out of scope`.
   - Not real: decline it with a reason a reader can check.
   Record every new finding in the ledger.
6. After fixes that change behavior, verify the affected features the way the
   project does, then commit.

Stop when a round is clean: every reviewer finished, and after skipping the
declined and out-of-scope findings, nothing above `nit` is left. Also stop
when the budget is spent. A spent budget is not approval; report what is still
open.

## Proof

1. Verify the head commit the way the project does. Keep the raw proof in
   `.plans/scratch/<branch>/proof/`: screenshots, transcripts, and command
   output with exit codes.
2. Run one evidence check with a fresh reviewer: the first reviewer in the
   list, through its skill's custom-prompt mode. The prompt holds only:
   - The intent, quoted word for word: the Jira ticket or the user's request.
     When neither exists, the acceptance criteria you wrote into the PR
     description.
   - The paths of the raw proof files. Not the ledger, a summary, or anything
     else you wrote.
   - The question: for each criterion, does the proof show it working? Answer
     shown, not shown, or shows a bug, and name the file that shows it.
3. Proof missing: gather it and run the evidence check once more.
4. Proof shows a bug: fix it, then run another round if the budget allows,
   and prove again. If the budget is spent, fix and verify it, and report that
   the fix had no review round.

## Report

This skill never writes to the PR. The caller decides what goes there.

The report lists:

- The rounds: head commit and result of each, and why the loop stopped.
- The reviewers, each with the model and harness that ran it, for example
  `GPT-6.1 Sol through Codex`.
- The fixed findings.
- The declined findings, each with its reason.
- The out-of-scope findings, as follow-ups for the user.
- The diff size against the base before and after the loop.
- The evidence check's answer for each criterion.
- What is unverified.
