# Gemini reviewer (Antigravity)

Runs Gemini models through Antigravity.
Defaults: model `{{defaults.gemini_model}}`, effort `{{defaults.gemini_effort}}`.

## Target

Antigravity has no built-in `/review` command. Build the task using the custom
prompt format from [SKILL.md](../SKILL.md):

- Uncommitted changes: `git diff HEAD` plus untracked files.
- A branch against a base: `git diff <base>...<branch>`.
- A commit: `git show <sha>`.
- A plan, selected files, or a specific question (such as an evidence check):
  the paths and question.

For a blind branch review, pass only the absolute repository
path, the target, the `git diff <base>...<branch>` command, and the read-only
review instructions—no author intent or prior findings.

## Run

1. **In T3 Code** (when `delegate_task` is available):
   - Call `orchestrator_capabilities` and confirm provider `antigravity` offers
     the selected model and `thought_level` value.
   - Call `delegate_task` with `mode: "async"`, `role: "review"`,
     `target: {providerInstanceId: "antigravity", model: <model>,
     options: {thought_level: <effort>}}`, and the task text.
   - Because the delegate has no read-only sandbox, compare
     `git status --short` and `git rev-parse HEAD` after it finishes against
     the recorded values. Report any unexpected change and never treat its
     files or commits as part of the reviewed work.
2. **Outside T3 Code, when already running inside Antigravity:**
   - Start a fresh native subagent when the inherited model and effort match
     the requested ones, giving it the same read-only task.
3. **Otherwise:**
   - Antigravity has no standalone headless CLI for external callers. Explain
     that `gemini` requires T3 Code's `antigravity` provider (or running inside
     Antigravity) and stop. Do not silently switch providers, models, or effort.

## Read result

Read the delegate or subagent summary. A report that does not show the reviewer
read the target is incomplete: report it as failed, never as clean.
