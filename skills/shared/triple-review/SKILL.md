---
name: triple-review
description: Use when the user asks for a triple review, or for three independent reviewers of a change.
---

# Triple review

Three independent reviewers on two models look at one change. You check what
they found and give the user one short report.

## Target and intent

- **Target:** what the user named. Otherwise the current branch against its
  base: the PR's base branch, or `origin/main` when there is no PR. Write down
  the head commit; a later re-review starts from it.
- **Intent:** what the change is supposed to do, in two or three sentences.
  Take it from the user's request, the PR description, or the plan in
  `.plans/`. The reviewers judge "simpler" and "over-engineered" against it. If
  you cannot find it, ask the user before you start.

## Reviewers

Start the three reviewers in parallel with T3 Code's `delegate_task` tool: one
call per reviewer, with `mode: "async"` and `role: "review"`. Use exactly these
targets:

| Reviewer | `providerInstanceId` | `model` | `options` |
| --- | --- | --- | --- |
| General | `codex` | `gpt-6.1-sol` | `reasoningEffort: high` |
| Simplify | `claudeAgent` | `claude-opus-5-5` | `effort: high` |
| Over-engineering | `claudeAgent` | `claude-opus-5-5` | `effort: high` |

If `delegate_task` is missing, or `orchestrator_capabilities` does not list one
of these models, tell the user and stop. Do not use another model instead.

Each reviewer's task gets the target, the intent, and one question:

1. **General:** what is wrong? Bugs, regressions, failure paths, security
   holes, and tests that would miss them.
2. **Simplify:** how can the change be shorter or flatter and do the same
   thing?
3. **Over-engineering:** did we over-engineer this? The answer is yes, partly,
   or no. "No" is a valid answer.

Tell every reviewer:

- Read only. No edits, commits, containers, or calls to remote services.
- Do not start subagents of your own.
- For each finding, give the file and line, what goes wrong and when, and a
  suggested fix.
- End with a clear verdict, even when you found nothing.

Do not tell a reviewer about the other two. Their answers stay independent.

Wait until all three finish. If a reviewer fails or ends without a verdict,
start it once more with a new `delegate_task` call. If it fails again, say so in
the report.

## Report

Check each finding against the code before you report it. Drop the ones that
do not hold up.

The first line is `Needs a fix: yes` or `Needs a fix: no`.

Then list the findings, most important first. When two reviewers found the
same thing, list it once and say so. When they disagree, say who says what.
Tag each finding:

- **affects us:** goes wrong in the way this code is used today.
- **edge case:** real, but needs an unusual input or state.
- **nit:** style or taste.

End with which findings you recommend fixing, and why. Do not change any code
until the user tells you to.

## Re-review

When the user says they made fixes and asks for another review, start the
same three reviewers again with new `delegate_task` calls. Do not message the
earlier reviewers' threads. This time the target is only the changes since the
commit you wrote down last time. Give the reviewers the earlier findings too.
The report says which earlier findings are now fixed.
