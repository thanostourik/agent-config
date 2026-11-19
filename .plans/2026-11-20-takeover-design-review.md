# takeover: design review, shorter report, faster loop

## Goal

`takeover` ran 17 times between 4 and 18 November. The fixes it made were
real, but four things failed again and again:

- No Claude model judged the code. Codex and Grok looked for bugs, and
  `depatch` only counts a problem that repeated fixes produced. A PR badly
  designed in one commit passed clean (backend #109).
- Nobody judged the tests the PR added. In backend #98, #99 and #109 the run
  said "ready", then the user read the tests and had them deleted.
- The report was long and unclear about what the user had to do. The user
  asked "is it ready?" or "do I have to do something?" again in six runs.
- The loop ran the project's live verification after every round (backend
  #104: eight runs, 91 minutes), and a reviewer out of credits stopped the
  run until the user answered (web-react #115, backend #98: 85 minutes).

## Design

### takeover

- **Hands off.** A new section. The agent decides alone and asks, through
  the question tool, only when it is blocked, when the PR's approach is wrong
  or most of its code needs rewriting, or when another PR makes it obsolete.
  A behavior the author chose on purpose stands and is not handed to the
  user.
- **Design review**, a new step before `review-loop`. It replaces the
  `depatch` step that ran after the loop. The main agent does it, in this
  order, applying each part before the next:
  1. Structure. It runs `depatch` and compares the blind design with the PR.
     Every difference counts, patch scar or not.
  2. Taste. It reads every line the PR still adds and holds it to the coding
     preferences in its instructions. Behavior stays the same.
  3. Tests. It names the bug each added or changed test would catch, and
     deletes a test that pins an implementation detail or repeats a live
     check.

  It changes only code the PR adds.
- **Order.** Design review comes first, so the reviewers see the final shape
  once. Before, the redesign came after the loop and needed a review round
  of its own.
- **Regression check** runs whenever the agent changed code, not only
  behavior. It is the proof that the design review changed none.
- **Follow-up review** stays only for a regression fix, or a fix that had no
  review round.
- **Report** in a fixed order: verdict, what the PR does, what the user must
  do, what the agent changed, and at most three lines of things that are not
  part of this PR. Proof and declined findings stay in the PR description
  and the ledger. No question goes into the report.

### review-loop

- **Live verification once.** A round checks its fixes with a focused check.
  The project's verification runs once on the final head, in Proof.
- **A reviewer that cannot run.** One rule for a missing skill and for two
  failures in a row. A one-pass reviewer is left out. A round reviewer is
  replaced by the first of `defaults.fallback_reviewers` (shipped:
  `claude-review`) whose model family is not already reviewing. With none,
  the agent asks through the question tool.

### depatch

- Its last line told the agent never to start the redesign. `tourik` and
  `takeover` both call it and say what happens with the result, so the line
  now applies only when the user ran the skill.

## Out of scope

- Changes to `tourik`, `file-pr`, and the review skills.
- The number of review rounds.

## Verification

- The sync tests pass.
- `./sync --home <temp> --apply` installs the three skills with every marker
  filled.
