---
name: tourik
description: Use when the user asks for "tourik mode".
---

# tourik

Run only when the user asks for tourik mode. It means: "I'm not watching. Own
the work until the PR is ready for me to merge. Never merge it."

## What this mode allows

Without asking again, you may:

- create a branch for the work before the first file you create or edit
- commit after each working step and push right away
- open the PR with the `file-pr` skill as a draft, keep its description
  current, and mark it ready at the end
- rebase your own branch onto its base, and push it with `--force-with-lease`

You never merge the PR. You never push to, rebase, or rewrite `main` or another
person's branch. You never merge another branch into yours. If a
`--force-with-lease` push is rejected, someone else pushed: stop and ask.

Name the branch and write commit messages in the formats the active
instructions give. When the work has an issue ID, put it in the branch name and
in every commit message.

## Stay active

Stay active from step 1 to step 7 without ending your turn. Nobody will prompt
you again, so ending the turn early stops the work.

## Steps

1. **Intent.** Find what the change must do:
   - When the user gives a Jira ticket, read it through the Jira MCP.
   - Otherwise take it from the user's request, or from a plan in `.plans/`.

   If the goal is ambiguous in a way that changes the result, ask. If the
   intent has no clear acceptance criteria, write 3 to 5 checkable criteria.
   They go into the PR description in step 4.
2. **Implement** the smallest change that meets the intent.
3. **Verify** as "How to verify" below says.
4. **Open the PR** as a draft with the `file-pr` skill. From here on, update
   its description whenever the scope or the verification status changes.
5. **Review.** Run the `review-loop` skill on the PR. If it made fixes in two
   or more rounds, run the `depatch` skill on the branch. Do not act on its
   result or stop to ask about it: it goes into the report.
6. **Ready gate.** All of this must hold on the latest commit:
   - Every intended behavior has proof.
   - Every review finding is fixed, declined with a written reason, or
     recorded as `out of scope` by `review-loop`.
   - The PR has no conflicts with its base. If it has, rebase onto the base,
     push with `--force-with-lease`, and redo the proof the rebase could
     change.

   Then mark the PR ready for review.
7. **Report:**
   - the PR link
   - the proof
   - every decision you made alone
   - the declined findings, with reasons
   - follow-ups: the out-of-scope findings
   - the `depatch` verdict and patch scars, when it ran
   - what is unverified

## How to verify

First find out how this project lets an agent run the app:

- **A `verify-<app>` skill** in `.agents/skills/` or `.claude/skills/`. Its
  Isolation section says `Isolation level: full | shared | checks-only`.
  - `full`: every run gets its own disposable environment. Start yours, even
    while other agents run theirs.
  - `shared`: verification uses resources others may be using. The skill's
    Doctor check runs before every launch.
  - `checks-only`: run the tests and checks the skill names, and report the
    live steps as unverified.
- **No verify skill, but a `local-stack/` folder** (the project's `AGENTS.md`
  has a "Local stack" section). Run
  `local-stack/stack up --app --stubs --name <branch>` and read the ports from
  `local-stack/stack env --name <branch>`. At the end, also after a failure,
  run `local-stack/stack destroy --name <branch>`.
- **Neither:** there is no isolated way to run the app. Never start the
  project's normal dev setup: it can touch the developer's running app, data,
  or ports. Run the tests, lint, and type checks, then ask. Suggest
  `/create-project-local-stack` in the question.

Before a launch, check only that Docker works (`docker compose version`), then
try. Do not check ports first: the stack picks them from its own registry. A
failed launch or a Doctor refusal is a blocker: report the error and ask.
Never fall back to a shared instance or the developer's default stack.

## When to ask

Ask only when you are blocked:

- the change cannot be proven
- the project has no isolated way to run the app
- a launch fails, or the Doctor check refuses
- the ready gate cannot pass
- the next step is destructive, reaches outside the repository, or touches
  other branches
- the goal is ambiguous in a way that changes the result
- another PR makes this one obsolete

Ask through the harness's question tool, so the thread shows that it is
waiting. Put all the context into the question, and list the options with your
recommendation first.

Decide everything else alone, and list those decisions in the report.

If there is no question tool, or no answer comes back, leave the PR open and
start your final message with the question.
