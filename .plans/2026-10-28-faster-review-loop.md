# Faster review loop

Review loops took most of a tourik run's time. The CHA-972 run took 2h04m,
and writing the code took under 4 minutes. The ledgers of CHA-972 (4 loops)
and yeet parts 1a and 1b show four causes:

- Every round finds one or two new `low` findings, so loops end on the budget,
  not on a clean round. In CHA-972, rounds 4 and 5 of the first loop cost
  about 45 minutes for one low each. In its fourth loop, the final round found
  one low, which forced a fifth round.
- Grok waits block the end of the loop. In yeet 1b, Codex was clean at 20:24
  and Grok returned at 20:53 with 3 findings, all declined.
- Follow-up loops re-review the whole branch. The fourth CHA-972 loop fixed 4
  files, reviewed all 83, and Grok's one fix was in older code. On follow-ups,
  Grok produced 3 low fixes over loops 2 and 4. On new work it found real
  medium bugs, so it stays for new work.
- "State and concurrency" raised the budget to 5 on almost every React loop.

## Changes to `review-loop`

1. A round is clean when nothing above `low` is left. Lows are still fixed,
   with no review round of their own.
2. Final reviewers become one-pass reviewers (`defaults.one_pass_reviewers`,
   default `["grok-review"]`). They start in round one next to the round
   reviewers, and the loop does not wait for them. Their findings are checked
   against the current code when they arrive and count toward the round
   running then. The loop stops only after they finished with nothing above
   `low` left. Trade-off: Grok reviews the round one code, and later fixes
   are reviewed by the round reviewers only.
3. A follow-up loop is a loop on a branch whose ledger already holds an
   earlier loop. It reviews from the last loop's last reviewed commit to
   `HEAD`, without one-pass reviewers. After a rebase that drops that commit,
   it reviews the whole branch. Each loop's ledger section records its target
   and its last reviewed commit.
4. The budget rises to the maximum only for a `high` finding in the risky
   areas.

`file-pr` names one-pass reviewers as "once by", and after a follow-up loop
adds its rounds to the count. Tourik is unchanged.

Out of scope: Kong's token-exchange limit cost about 28 minutes of CHA-972's
run. That fix belongs in web-react's verification skill.
