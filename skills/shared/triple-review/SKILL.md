---
name: triple-review
description: Use when the user asks for a triple review, or for three independent reviewers of a change.
---

# Triple review

Three independent reviewers look at one change. You check what they found and
give the user one short report.

## Target and intent

- **Target:** what the user named. Otherwise the current branch against its
  base: the PR's base branch, or `origin/main` when there is no PR. Write down
  the head commit; a later re-review starts from it.
- **Intent:** what the change is supposed to do, in two or three sentences.
  Take it from the user's request, the PR description, or the plan this branch
  added in `.plans/`. The reviewers judge "simpler" and "over-engineered"
  against it. If you cannot find it, ask the user before you start.

## Reviewers

Start three independent reviewers in parallel. Use the user's selected
provider, model, and effort for each reviewer; otherwise use these defaults:

- General: `{{defaults.general_provider}}`, `{{defaults.general_model}}`,
  `{{defaults.general_effort}}`.
- Simplify: `{{defaults.simplify_provider}}`, `{{defaults.simplify_model}}`,
  `{{defaults.simplify_effort}}`.
- Over-engineering: `{{defaults.over_engineering_provider}}`,
  `{{defaults.over_engineering_model}}`, `{{defaults.over_engineering_effort}}`.

Choose how to run each reviewer:

1. **T3 delegates**, when `delegate_task` is available. Call
   `orchestrator_capabilities` first. Use one call per reviewer with
   `mode: "async"`, `role: "review"`, and the provider as `providerInstanceId`.
   Set the model and map the effort to its catalog option in `target.options`.
2. **Native subagents**, outside T3, when the harness's subagent tool supports
   the selected provider, model, and effort. An inherited setting is enough
   when it matches. Start one fresh subagent per reviewer.
3. **Command-line tools**, for reviewers native subagents cannot run. Use the
   custom-prompt mode in [codex-review](../codex-review/SKILL.md) for `codex`,
   [claude-review](../claude-review/SKILL.md) for `claudeAgent`, or
   [grok-review](../grok-review/SKILL.md) for `grok`. Follow that skill's setup,
   permissions, execution, and waiting rules, passing this reviewer's model,
   effort, and task below. Do not use its built-in review command: each role
   needs its own question.

Before starting, check the chosen route for all three reviewers. Each must
support its selected provider, model, and effort; command-line tools must be
installed and authenticated. If a route cannot run its reviewer, explain what
is missing and stop. Do not silently change providers, models, or effort.

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
start it once more as a fresh reviewer through the same tool. If it fails
again, say so in the report.

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
same three reviewers again with fresh runs, using the selection rules above.
Do not message the earlier reviewers. This time the target is only the changes
since the commit you wrote down last time. Give the reviewers the earlier
findings too.
The report says which earlier findings are now fixed.
