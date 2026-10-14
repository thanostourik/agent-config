# Workflow analysis: T3 Code threads, 2026-09-14 to 2026-10-14

Data: 384 threads and 2,570 user messages. 742 of those messages (29%) contain swearing, spread over
164 threads. Thread ids below are the first 8 characters.

## Ranked improvements

### 1. Give every answer a fixed shape (small)

- **Problem:** Agents bury the answer, use words they never define, and use status words like
  "partial" or "blocked" without saying what didn't happen. The current rules on this are abstract,
  and agents ignore them.
- **Evidence:**
  - 54 threads say "I don't understand" or similar. 41 threads complain about length.
  - About 15 threads have status words with nothing behind them. For example, 49d37e90 delivered a
    PR with only documentation for a task that asked for a fix.
  - Examples: 33137e94, b50b42cf, 976cbd52, 0a05b0ba, c4a0b6d4, 952d5684.
- **Fix:** Replace the abstract wording in `common.md` with a concrete shape:
  - The first line answers the literal question or gives the verdict, for example "Done, verified,
    ready to merge".
  - When I list points, answer each one in order.
  - Keep it to about 5 lines unless I ask for more.
  - A status word always says what was not done. For a fix task, deliver a fix or say plainly that
    you have none.
  - Use absolute paths when a file is in another repo.

### 2. Rewrite the "Local environment" rules (small)

- **Problem:** Two problems point in opposite directions.
  - Locally, agents ask permission to start servers, then leave containers and loops running.
  - On servers and in credential stores, they write and read things nobody allowed.
- **Evidence:**
  - Live staging was edited and the production compose file was rewritten (d865da7e).
  - `./sync --apply` ran on the real home folder (844474a0, d50f20de).
  - Agents read Chrome saved logins and `bw-session` (560355f3, 59cbdbed, 857b051f).
  - A private-key fragment was printed (cae77f57).
  - A Compose name collision replaced another project's container (ef609c12).
  - A wait loop was left running for 4 hours (6a7141ed).
  - About 8 threads asked "may I start the server?" (1b64fde3, 8b60259c, 7e554114).
- **Fix:** Rewrite the section in `common.md`:
  - Locally: start what you need without asking, set an explicit Compose project name, and tear down
    everything you started before you report.
  - Servers, `~/` config, and credential stores are read-only unless I name the write.
  - Print env keys, never their values.
  - Edit config files line by line. Never re-serialize a whole file.

### 3. Add a `triple-review` skill (medium)

- **Problem:** You paste the same 3-reviewer prompt by hand: general, simplify, over-engineering.
  Then you relay reviews between threads and ask "is there substance?" The reviewers nest helpers,
  stall, or come back without a verdict.
- **Evidence:**
  - The 3-reviewer prompt was pasted in 17 threads (1e9e9d6d, b4e644c1, 058f2c3a, 8fe0df09).
  - "Substance" relays happened in 17 threads (0921282b, 4b8b0506, 495da9e2).
  - "Do we need to fix anything?" came up in 5 threads (d50f20de).
- **Fix:** One skill that:
  - passes the branch's intent to each reviewer, and allows no nested agents;
  - writes one report that opens with "Needs a fix: yes/no" and tags each finding as "affects us",
    "edge case", or "nit";
  - applies the fixes that are clearly right, and re-reviews only the delta on "I made fixes";
  - can send one reviewer to another model.

### 4. Jira close-out in `squash-merge-pr`, plus its script bugs (medium)

- **Problem:** Almost every merge is followed by the same typed text, "log 30 mins and resolve the
  ticket". The script also fails after it has already done its work.
- **Evidence:**
  - The close-out request appears in 31 threads; in chunk 7, 24 of 33 merges had it. Examples:
    1e2712ab, 6a22a8a1, bed34010.
  - The script exits 1 with `getcwd` after it deletes its own worktree, in about 14 threads
    (09ef9574, 205378ae).
  - "Cannot fast-forward to multiple branches" happened twice (7e554114).
  - Removing the worktree deleted the evidence screenshots (a5a89300).
  - In agent-config, 11 merges ended with "not installed until `./sync --apply`".
- **Fix:**
  - Add optional `--log 30m --resolve` that takes the issue id from the branch name.
  - `cd` out of the worktree before removing it.
  - Keep the evidence screenshots before the worktree is removed.
  - In agent-config, offer to run sync after the merge.
  - A matching "mark in progress" step when a ticket starts (32 threads).

### 5. Restate constraints; make decisions; don't flip-flop (small)

- **Problem:** Agents drop hard constraints such as "free". They hand technical decisions back to
  you, and they reverse recommendations when you push back, without any new fact.
- **Evidence:**
  - "Free" was ignored, which cost 3 days, about 20 Jira tickets, and a revert. Threads: ae923c86,
    de2c8779, 48552872, 0560238f, c8698a1a.
  - Flip-flops: bd6cbfd0 (5 reversals), 9901a9d8, 293bb5fb, 000a1cd8.
  - 7 threads ask the agent to work "hands off" (6a7141ed, c740480b, 03f9eaf1).
  - Agents implemented after approval of only one point (39a32dc2, 970c13e1).
- **Fix:** Add to `common.md`:
  - Before proposing, restate my hard constraints in one line, and carry them into plans and
    tickets.
  - "Free" means nothing that can ever bill.
  - Decide technical questions yourself. Ask me only about product, money, or access, and include a
    recommendation.
  - Change a recommendation only for a fact you name.
  - Approval covers only the points I named.

### 6. Add a `read-t3-thread <id>` script (small)

- **Problem:** You often point an agent at another T3 thread. Each agent searches T3's database on
  its own, and some answer without reading the thread at all.
- **Evidence:** 36 threads reference a thread id. Agents did not read it in 422ac983 and ae730cac;
  ae730cac built the wrong skill as a result.
- **Fix:** Add `bin/read-t3-thread` next to `t3-start-thread`. It opens T3's database read-only and
  prints the thread's messages. Add one line to `common.md`: "a T3 thread id means: read it with
  this script."

### 7. Fix the git and plan rules that clash with how you work (small)

- **Problem:** "No force-push, ever" leads agents to create workaround branches and duplicate PRs.
  "Plans are committed files" turns "make me a plan" into a branch and a PR.
- **Evidence:**
  - Workaround branches and duplicate PRs: 4b8b0506, cb5fa653, f90592ae, 970c13e1.
  - A plan request became a plan file with a branch and PR: ae923c86, de2c8779, 3fe66726, da2656d4.
  - A branch was cut from a random branch instead of main: 57211316.
  - Missing `refactor/` prefix: 9cc60d2c, 24058916.
  - The "too broad, split it" rule fired on a plan you had already agreed: dfb537cb, 95422252.
- **Fix:**
  - Allow `--force-with-lease` when I ask for a history rewrite. Never use a new branch to avoid
    one.
  - Plans asked for in discussion stay in chat.
  - Branch from `origin/main`.
  - Add `refactor/`.
  - The split rule doesn't apply to an agreed plan.
  - Check for overlap with thread dc1ca79a first.

### 8. Fill the Jira gaps on the read side (medium)

- **Problem:** Every thread rediscovers which Jira project belongs to which repo. Ticket text is too
  long, links point to localhost, and agents fall back to the browser when the MCP can't do
  something.
- **Evidence:**
  - "Summarize my open issues" came up in 26 threads; ce749d22 asked you which project.
  - create-jira-issue asks which project even when it is obvious (1df0cbdb, 13dbeaeb, 0560238f).
  - Its "Acceptance criteria" and "Notes" sections were rejected (de2c8779, d748fee7).
  - `jira-gate-proxy` links point to `127.0.0.1` (fcea0e9d, 632493f8).
  - Agents asked you to log in to Jira in the browser (5a2b1538, de2c8779).
- **Fix:**
  - Add a repo-to-Jira-project map: contentcloud is CHA, CHADM, and REP; cinova is CIN.
  - Default to the current repo's project instead of asking.
  - Shorter template.
  - Links always go to the real Jira host.
  - When the MCP can't do something, report it and stop. No browser fallback.

### 9. Stop the review monitors from burning the usage limit (small)

- **Problem:** The review skills post a progress update every minute. On long reviews that eats the
  session limit and floods the thread.
- **Evidence:**
  - bf6da768 had 79 "Still running" turns and hit the session limit 21 times in a row.
  - 293bb5fb had about 26 pings during one review.
  - The rule sits at `skills/shared/codex-review/SKILL.md:59`.
- **Fix:** Wait on the process with a long blocking wait or a completion notice. Report only on
  completion, or every 5 minutes or so.

### 10. Enforce "no Co-authored-by" with a git hook (small)

- **Problem:** The rule in `common.md` is still broken, because some harnesses add the trailer
  themselves. Cursor even rewrites the commit command.
- **Evidence:**
  - You raised trailers or attribution 60 times, in 35 threads.
  - The 10-10 batch pasted the rule into every prompt.
  - Trailers were still added in 970c13e1, f90592ae, 9bd8d85d, and cb5fa653.
- **Fix:** Sync installs a global `commit-msg` hook that removes `Co-authored-by` lines. It goes in
  `core.hooksPath` and chains to each repo's own hooks. Then remove the pasted reminders.

## Model and effort

| Model / effort | Went well | Went badly |
| --- | --- | --- |
| codex gpt-6-astra/xhigh, astra/high | Bug fixes with verify skill and PR; stable design work ("fresh mind" after bd6cbfd0) | Multi-repo git at low effort (47ce4540) |
| codex gpt-6.1-sol/high (58 threads) | Clearly specified Jira ticket to PR to merge | Open-ended advice, ticket writing, live-server ops (d865da7e); used the integrated browser instead of Playwright; 36% of messages angry |
| claude opus-5-5/high (56) | Long autonomous runs (e1f76023), spawned single-bug fixes | Multi-day design threads with compaction (fce4c261, bf6da768, 293bb5fb); flip-flops |
| claude opus-5-5/low | Simple ops | Design (bd6cbfd0) |
| claude fable-5-1/low (46) | Rebases, small clear tasks; lowest anger rate (10%) | Wordy; git and plan rules |
| claude sonnet-5-5/high | Scripts, batch workers | Verification and branching in bug fixes (57211316, 7e554114) |
| claude haiku-5-5 | Trivial Jira lists | 3 of 3 real tasks failed (ae730cac, f90592ae, 15317f4a) |
| cursor grok-4.7 | Single-shot reviews, small tasks | Debugging, design; transport errors killed about 6 threads |
| cursor grok-4.6, opencode free models | Short Q&A | Design and setup (cf1f0b68, cde41e30, c85c0118); 59% of grok-4.6 messages angry |

Pattern: short, well-specified tasks go smoothly on every model. The anger concentrates in
multi-day threads that hit compaction, and in design or live-system work.

## Left out

- Already fixed since: `gh pr edit` failing (gh was updated), the Jira MCP's slow start (#37, #38),
  and squash-merge-pr's invented checks (now a script).
- Fixed but not yet checked: whether Sol now uses Playwright after #40 and #46.
- T3's own bug: it replayed old messages as new turns in 14 threads on 09-15 and 09-16. That is not
  in this repository.
