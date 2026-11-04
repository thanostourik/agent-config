# takeover skill

## Goal

The user lands PRs that colleagues opened, most of them written with agents.
`takeover` gets such a PR ready for the user to merge, the same way every
time: review, fix on the colleague's branch, depatch, check for regressions,
update the title and description. The user still merges with
`squash-merge-pr`.

The steps come from the user's landings of the last 30 days: CHA-763
(backend #59, insights #5, web-react #63), web-react #71 and #72, insights #12
and #13, and website #15.

## Design

- New skill `skills/shared/takeover/SKILL.md`, for every tool, and an entry
  in `config.defaults.json`.
- Steps:
  1. Intent from the PR, its Jira issue, and its plan. Without a Jira issue,
     criteria in `.plans/scratch/<branch>/criteria.md`, which `review-loop`'s
     evidence check reads.
  2. Check out the PR's own branch. Commit, push, rebase, and
     `--force-with-lease` to it need no question. In every landing thread the
     agent stopped to ask about this, or opened a stacked PR instead.
  3. `modernize` when the branch is behind. A rebase needs no review round
     (#71).
  4. Other repositories named in the project's `AGENTS.md`: does the change
     need a matching change there? In contentcloud, a web-react change often
     needs a backend-spring one.
  5. `review-loop` over the whole PR. Fixes are separate commits.
  6. `depatch` every time, and its redesign when it finds patching.
  7. Regression check against the author's last head, when our commits
     changed behavior (CHA-763 found 3 regressions this way).
  8. Follow-up `review-loop` when steps 6 or 7 changed code, or a fix had no
     review round (#72). The last loop also verifies the final code.
  9. Title from `file-pr`'s rules (#15 reached main off-style). Description:
     replace or add `## Verification`, list our fixes, add `Reviewed by`, no
     `Filed by`. Rewrite it whole only when our changes made it wrong.
  10. Report: verdict, PR link and proof, PRs in other repos that must merge
      first, decisions made alone, declined findings and follow-ups.
- Never merges.
- `review-loop`: its first line and description also cover a PR taken over
  with `takeover`. Agents on #71, #72 and #13 decided the loop does not apply
  to a colleague's branch.

## Out of scope

- Replacement PRs, PR comments, and watching CI or review bots.
- Changes to `tourik`, `modernize`, and `file-pr`.

## Verification

- The sync tests pass.
- `./sync --home <temp> --apply` installs `takeover` to all five tools, with
  the new `review-loop` text.
