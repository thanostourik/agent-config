---
name: review-loop
description: Use when the user asks for a review loop, or wants a branch you own (your own work or a PR taken over with takeover) reviewed, fixed, and verified before handoff.
---

# Review loop

Use this for changes you wrote on the current branch or a PR you took over with
`takeover`. Independent reviewers inspect the branch in rounds. You verify their
findings, fix real bugs, and collect evidence that the result works. A fresh
reviewer then checks that evidence against the original requirements.

## Setup

- **Reviewers:** three lists from [peer-review](../peer-review/SKILL.md)
  (`codex`, `claude`, `grok`, `cursor-grok`, or `gemini`):
  - **Round reviewers** run on every round: `{{defaults.reviewers}}`.
  - **One-pass reviewers** run once, starting in round one:
    `{{defaults.one_pass_reviewers}}`. Use this list for slower reviewers that
    are worth one full pass; they run in the background while you fix findings
    and run later rounds.
  - **Fallback reviewers** stand in if a round reviewer cannot run:
    `{{defaults.fallback_reviewers}}`.

  `none` means an empty list. If there are no round reviewers, tell the user and
  stop. Any list the user names replaces the default. If the user names
  reviewers without specifying a list, use them as the round reviewers with no
  one-pass reviewers. If a reviewer appears in both lists, treat it as a round
  reviewer only. Each reviewer's reference file in
  [peer-review](../peer-review/SKILL.md) gives its default model, effort, and
  how to run and wait for it.

  A reviewer cannot run if it is unavailable in your environment or fails twice
  in a row (for example, due to a usage limit). When that happens:
  - **One-pass reviewer:** continue without it.
  - **Round reviewer:** replace it for the rest of the loop with the first
    fallback reviewer whose model family is not already used in this loop (for
    example, do not add a second GPT reviewer alongside an existing one). If no
    such fallback exists, ask the user (using your question tool) which reviewer
    to use or whether to continue without one. A round is not clean if a round
    reviewer failed to complete it.

  Do not substitute reviewers any other way.

- **Target:** the current branch against its base (the PR's base branch, or
  `origin/main` when there is no PR). Record `git diff --shortstat` for the
  target before round one.

- **Follow-up loop:** if the ledger already has an earlier loop for this branch,
  review only the commits from that loop's last reviewed commit up to `HEAD`,
  and skip one-pass reviewers. If that commit is no longer on the branch (for
  example, after a rebase), review the whole branch again. Any target or
  reviewers the user specifies override these defaults.

- **Ledger:** `.plans/scratch/<branch>/review-ledger.md`. Give each loop its own
  section starting with its target and ending with its last reviewed commit,
  with one table row per finding:

  | id | reviewer | severity | finding | outcome | reason | commit |
  | --- | --- | --- | --- | --- | --- | --- |
  | R1-1 | codex | high | `src/a.ts:40` drops the last page | fixed | | `abc123` |
  | R1-2 | codex, grok | medium | `src/b.ts:12` races on save | declined | the lock in `save()` serializes it | `abc123` |

  `reviewer` lists every reviewer that raised the finding so the user can see
  each reviewer's hit rate. `severity` is `high`, `medium`, `low`, or `nit`,
  based on your own inspection of the code rather than the reviewer's label.
  `commit` is `HEAD` when you recorded the decision.

## Round limit

Default to {{defaults.rounds}} rounds. Raise the limit to {{defaults.max_rounds}}
if a `high` finding involves security, permissions, auth, data loss, or
state/concurrency, or if the user asks. If the user specifies a round count, use
that instead.

## Running a round

1. Commit your work so every reviewer sees the same code. Never push from this
   skill; leave pushing to the caller.
2. Start every round reviewer before ending your turn to wait. In round one,
   start the one-pass reviewers too. Each reviewer inspects the full target
   using its reference file in [peer-review](../peer-review/SKILL.md) on every
   round—do not narrow later rounds to only the fixes since the previous round.
3. Keep reviewers blind. Do not pass them the requirements, the ledger, earlier
   or declined findings, or any notes you wrote. Author context biases
   reviewers.
4. Wait for all round reviewers to finish (do not wait for one-pass reviewers).
   If a reviewer fails, retry it once. If it fails a second time, treat it as
   unavailable and follow the fallback rules in Setup; any replacement must
   review the current round.
5. Check each finding against the code. Reviews should make the change correct,
   not bigger:
   - **Declined or out of scope earlier:** add the reviewer to that row and skip
     it, unless the surrounding code changed since that row's commit (in which
     case, re-evaluate it).
   - **Fixed earlier and raised again:** re-check it; the fix may not hold.
   - **Real and introduced by this branch:** fix it with the smallest change
     that resolves it. No refactors, renames, or new features.
   - **Real, but pre-existing before this branch:** record it as `out of scope`.
   - **False positive:** decline it with a verifiable reason.
   Record every new finding in the ledger.
6. Verify each behavior-changing fix with a focused check (such as a single test
   or request), then commit. Save full project verification for the Verification
   step on the final commit.

A round is clean when every round reviewer finished and, after skipping declined
and out-of-scope findings, nothing above `low` remains. Fix `low` findings too,
but they do not require another review round.

One-pass reviewers inspect the round-one commit while you continue fixing and
committing. When a one-pass reviewer finishes, evaluate its findings against the
current code and count them toward the active round (expect `HEAD` to have
advanced from your own commits when `peer-review` checks the final git state).
If a one-pass reviewer finishes after a clean round and raises anything above
`low`, fix it and run another round.

Stop when the latest round is clean and every one-pass reviewer has finished
with nothing above `low` remaining. Also stop if you hit the round limit.
Hitting the limit is not approval—report any unresolved findings.

## Verification

1. Verify the final commit using the project's standard verification process.
   Save the raw evidence in `.plans/scratch/<branch>/proof/`: screenshots,
   transcripts, and command output with exit codes.
2. Run one evidence check with a fresh reviewer (the first round reviewer, or
   its replacement) using [peer-review](../peer-review/SKILL.md)'s custom-prompt
   mode. Include only:
   - The original requirements, quoted verbatim: the Jira ticket or the user's
     request. If neither exists, use the acceptance criteria in
     `.plans/scratch/<branch>/criteria.md`.
   - The paths to the raw evidence files—not the ledger, a summary, or anything
     else you wrote.
   - The question: for each criterion, does the evidence show it working? Answer
     `shown`, `not shown`, or `shows a bug`, and name the supporting file.
3. If evidence is missing, gather it and run the evidence check once more.
4. If the evidence shows a bug, fix it, run another review round if the round
   limit allows, and verify again. If the round limit is reached, fix and verify
   it anyway, and report that the fix had no review round.

## Report

This skill never writes to the PR; leave that to the caller.

Include in the report:

- The target, and whether this was a follow-up loop.
- Each round's head commit, result, and why the loop stopped.
- The round and one-pass reviewers that ran, with each reviewer's model and tool
  (for example, `GPT-6.1 Sol through Codex`), plus any reviewer that could not
  run and its replacement.
- Fixed findings.
- Declined findings, each with its reason.
- Out-of-scope findings, as follow-ups for the user.
- The diff size against the base before and after the loop.
- The evidence check's verdict for each criterion.
