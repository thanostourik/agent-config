---
name: create-project-verification-skill
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Generate the project's own verification skills, committed in the repo, so every developer's agent (Claude Code, Codex, Grok, Cursor) can drive the real app and prove its work. Use for /create-project-verification-skill, /create-project-verification-skill quick, or \"set up verification for this repo\"."
disable-model-invocation: true
---

# Create a project verification skill

Every serious project needs a scripted way to drive the real app and prove behavior: launch it, exercise a feature the way a user would, and capture evidence. This skill generates that as two project skills committed in the repo, so every developer's agent gets them without any global setup. You write the output for the next agent, not for a human. It will be read cold, mid-task, by an agent that has never seen the app.

When you need me to make a choice before you can continue, use your question tool if you have one, or ask in your reply if you don't. If the question gets no answer, ask again in your reply and wait. Do not answer it yourself.

## Modes

- `/create-project-verification-skill` (default): record every feature against the live app, then prove the whole map from a fresh environment (step 7).
- `/create-project-verification-skill quick`: record only one feature per surface, drive each of them once as a smoke proof, and stop. `/maintain-verify-<app>` finds the other features in the source and adds them later.

Honor an equivalent request. Do not ask which mode to use.

If `.agents/skills/verify-*` or `.agents/skills/maintain-verify-*` already exists, stop before writing anything. Ask the user whether to replace those skills (delete them and generate again) or to upgrade them with `/maintain-project-verification-skill`. Never overwrite them silently.

Messages you post anyway may carry progress lines such as `map 3/15: projects.md written`. Never change how you split, delegate or order work to produce them, and never add a turn just to report.

## What you write

```
.agents/skills/verify-<app>/                    the verification skill
  SKILL.md
  features/README.md, features/<feature>.md     the feature map
  bin/                                          helpers, including drive.sh and doctor.sh
  .gitignore                                    ignores .cache/
  .cache/                                       everything a run writes
.agents/skills/maintain-verify-<app>/           map maintenance with three drive modes
  SKILL.md
  agents/openai.yaml
.claude/skills/verify-<app>/SKILL.md            stub for Claude Code
.claude/skills/maintain-verify-<app>/SKILL.md   stub for Claude Code
```

`<app>` is a short lowercase name. Codex, Cursor, Grok and OpenCode read `.agents/skills/`. Claude Code reads only `.claude/skills/`, so the stubs exist for it. Never use symlinks: Windows checkouts turn them into plain files.

Helper agents build and repair the recipes, so your own context stays small. A **recorder** records one feature's recipe against the live app with `bin/rec.sh` (step 4). A **fixer** repairs one recipe that failed a drive (step 7). Both are described under Helpers in [`references/maintain-verify.md`](references/maintain-verify.md), with their briefs under Helper briefs; paste the briefs with `<app>` and `<driver>` replaced. Read only what helpers return, never the feature files they wrote.

## 1. Interview the repo, not the user

Answer these from the codebase. Ask the user only what you cannot observe.

- **Surface:** what the project exposes to people or other software: web UI, CLI/TUI, desktop app, API, mobile app, firmware, library. Pick the primary one and note the rest.
- **Verification triggers:** the changes that could affect that behavior, named from this repo. Include internal components and configuration, not only screens. Examples: endpoints, services, migrations, routing and authentication for a backend; command handling, output and file effects for a CLI. Observable behavior includes responses, permissions, stored data, background jobs and external side effects.
- **Run:** how the app starts locally. Prefer the repo's documented dev command. Note ports, env vars, seed data and auth.
- **Depends on:** what must run next to it: databases, auth servers, other services. Read the README and the docs it links (a `PLATFORM.md` naming sibling repos, compose files). For a service in another repo, learn how to start it there. Ask the user where that checkout is if you need to read it.
- **Existing harness:** specs, helper scripts, sign-in or seed tools, curl-able endpoints, a debug port. Reuse them.
- **Side effects of starting:** what startup may change: files, data, processes, external systems. Check what is already running (`ps`, `ss -ltn`), such as an installed copy of the app holding a port, a global hotkey or a single-instance lock, and record it as original state. See [`references/lifecycle.md`](references/lifecycle.md).
- **Observe:** the evidence you can capture: screenshots, accessibility snapshots, terminal transcripts, response bodies, logs, exit codes, database state.

If the checkout does not build or start as-is, fix that first, or report it precisely, before generating. A skill written against a broken base teaches wrong steps. When an irrelevant missing asset blocks startup, the generated skill may create it, marked as verification scaffolding, and remove it in cleanup.

## 2. Decide once, write one path

Decide these now, with the user where needed, and write the concrete choice into the skill.

- **Isolation.** Verification must never touch what the developer uses. Choose the isolation level (`full`, `shared` or `checks-only`), the ownership markers and the lifecycle commands, following [`references/lifecycle.md`](references/lifecycle.md). Ask the user only when `full` is not possible.
- **Drive tool.** Reuse the repo's own harness first. Otherwise use the defaults in [`references/verify-skill-spec.md`](references/verify-skill-spec.md). Every step is a shell command.

## 3. Write `verify-<app>`

Write `.agents/skills/verify-<app>/SKILL.md` following [`references/verify-skill-spec.md`](references/verify-skill-spec.md). Include the failure rules from [`references/drive-failures.md`](references/drive-failures.md). Copy [`references/drive.sh`](references/drive.sh), [`references/steps.sh`](references/steps.sh) and [`references/rec.sh`](references/rec.sh) to `bin/` unchanged. Write the other helpers in `bin/` and make them executable.

## 4. Map every feature

List the features the project exposes to people or other software: screens, route groups, commands, endpoint groups, library operations, and their data effects and background processing. Take them from routes, navigation, command definitions, endpoints and docs: a list, not a read of every component. Do not map internal functions. In `quick` mode, keep only one feature per surface, the ones step 7 drives. Follow [`references/feature-map-example/`](references/feature-map-example/).

Write `features/README.md` first. It holds the baseline every feature starts from, the driving conventions, the change triggers, the feature file shape and the index. Recorders read only this file and the skill's Drive section, so its driving conventions state the recipe rules below. Under `## Change triggers`, map the verification triggers from step 1 to the features each one affects, using this repo's file and component names; `verify-<app>`'s Pick features step selects from that list. The index gives every feature one line with its name and scope before any recorder starts.

Each feature file starts with an H1 and one paragraph on the observable behavior, then exactly four H2s in this order:

1. `Sub-features`: short IDs, one line per behavior.
2. `How to get to it (user POV)`: every entry point a user has.
3. `Driving it with <tool>`: `Preconditions:` with its setup, then labeled bullets `- **<Label>.**`, each a **step**. Every step states one user action and its observable result in one or two short sentences, followed by a fenced `bash` block. Split a step that proves several results. The block exits non-zero when the result is not met: a command that only prints a value gets a check, such as `test`. Blocks run under `set -euo pipefail`, where `! command` never fails a block, so write negative checks with `test` or `if`. Preconditions get a block too. End with proof, then any known product failures, then a last step labeled `Clean up` that removes the feature's fixtures; `drive.sh` runs it even after a failure. A fixture that is itself a user action worth proving gets its own step. Recorders write this section with `bin/rec.sh`, never by hand.
4. `Gotchas`: traps that waste or invalidate a run.

Keep code paths out of the feature files; only the change triggers name source. The agent maps a change to features by reasoning, and maintenance reads the source. Every behavior the contract sources name for the feature, such as a test case, a README sentence, a plan's acceptance line or an entry point, gets a step. So does every sub-feature line and every entry point the file lists, or it is reported as blocked with the reason.

Each recipe runs from the documented baseline in its own session, possibly while other features run. It sets up its own data instead of relying on another feature having run. Steps of one feature share shell variables and functions, so the Preconditions block can define what later steps use. A feature that changes state other features read, such as global settings, says `Runs alone.` in its Preconditions sentence. Prefer a fresh identity or namespace per recipe over deleting fixtures afterwards. Otherwise restore fixtures so the recipe can run again. For an irreversible operation, use a disposable fixture the run removes. Administrative setup and cleanup are fine inside the isolated environment, but never substitute them for the user action being proved. The example map is a fictional app: derive real commands from this project and run them.

Blocks wait for the observable state with the project's wait helpers or the driver's own waits, never with `sleep` or a fixed timeout in place of a condition. The proof step saves evidence under `.cache/evidence/<feature>/`: a screenshot or accessibility snapshot for a UI, the response body or command output otherwise. `Clean up` ends with a check that the recipe's fixtures and sessions are gone; `|| true` goes only on a command whose failure cannot matter, such as a delete that check covers. When the app does not do what the contract says, the check stays in the recipe as a known product failure: recorded with `rec.sh <feature> step --keep` as the last step before `Clean up`, so every drive reports it and still proves the rest. Its sentence states the contract. It is never weakened, dropped or moved to Gotchas.

Then record the features. At isolation level `checks-only`, skip launching and recording: write each Driving section as step sentences without `bash` blocks, and its steps stay `blocked: no isolation`. Otherwise launch once with `bin/launch.sh` and run `bin/doctor.sh`. Give each feature its own recorder, all on that one environment; Helpers in [`references/maintain-verify.md`](references/maintain-verify.md) says when features may share a recorder. How many recorders run at a time follows step 3 of Update the map there. Until step 7 settles the `--jobs` value that step uses, start with 2. Mark every feature new in the brief, with no changed conventions. Without a subagent tool, do the same work yourself, one feature at a time, still through `bin/rec.sh`.

Read only the reports. Compare their Names lists: when two features create the same account, fixture or resource name, send one of them back to a recorder to rename it. Make the helper changes that reports name as blockers yourself. A missing dependency or setup step that the project documents is yours to fix as well, inside the owned environment. Then send each blocked feature back to a recorder. A prerequisite the project does not document stays blocked: report it. Keep every Difference, with the step that carries it, for the hand-over as a possible product defect; its recipe keeps it as a failing step, never as normal behavior.

## 5. Write `maintain-verify-<app>` and the stubs

Copy [`references/maintain-verify.md`](references/maintain-verify.md) to `.agents/skills/maintain-verify-<app>/SKILL.md` and [`references/maintain-verify-openai.yaml`](references/maintain-verify-openai.yaml) to `.agents/skills/maintain-verify-<app>/agents/openai.yaml`. Replace `<app>`, and replace `<driver>` with the driver named in `verify-<app>`'s driver block. Adjust only what this project needs, for example how its PRs are opened. When editing a tracked file disturbs the running app, write into its recording step that this project records one feature at a time, and why.

Write the two Claude Code stubs from [`references/claude-stub.md`](references/claude-stub.md). Their `name` and `description` must match the real skills exactly. The maintain stub also carries `disable-model-invocation: true`.

## 6. Reconcile the project's verification instructions

Write one coherent `## Verification` section in the project's `AGENTS.md`, from [`references/agents-verification.md`](references/agents-verification.md). Replace `<app>` and `<work-scope>` with the app name and a concrete scope, such as "backend work" or "command-line tool changes". Integrate an existing verification section instead of appending a second one. With several apps, say which surface each skill covers. Use links relative to `AGENTS.md`.

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If the project has a `CLAUDE.md` that does not import `AGENTS.md` (`@AGENTS.md`), put the same section in `CLAUDE.md` too.

Read the rest of those files and anything they import for conflicting verification guidance. Replace superseded manual launch and cleanup recipes with references to the skill. Reconcile stale startup restrictions with the user's instructions and existing authorization. Do not invent a new approval requirement or silently remove a deliberate restriction. If a conflict cannot be resolved from those instructions, ask about that one conflict. Keep ports, resource names and lifecycle commands only in the skill, so there is one maintained procedure.

Keep the project's test, lint and type-check guidance, and add the exact focused commands from the repo where missing. Do not turn every verification into a full build. If an older verification system exists, report what it overlaps and conflicts with. Do not delete it without explicit authorization. Leave unrelated instructions alone.

## 7. Prove it

The selected features are every mapped feature; in `quick` mode, the recorded ones. Drive them in parallel, check that parallel features stayed apart, and write the `--jobs` value that worked into the skill's Drive section.

Drive from a fresh environment, not from the state the recorders left: run `bin/cleanup.sh`, launch again with `bin/launch.sh` and run `bin/doctor.sh`. Then drive all selected features in one `bin/drive.sh` call. Send each failing feature to a fresh fixer with the feature name, the failing step and its log path, and read only the line it returns. A feature that fails only at a known product failure, a step that a recorder's Differences or a fixer's line names, needs no fixer. Run one fixer at a time and never beside your own drive: two `drive.sh` runs share `.cache/drive/`, and the fixer drives its feature twice after a repair. When the fixers are done, drive all selected features once more without relaunching. That proves each `Clean up` step leaves the app ready for the next run. This second summary and the fixers' lines are the record of the pass. A feature that fails the second drive at any other step goes back to a fixer, and then the second drive is repeated.

- **Default:** the fresh launch already showed that recipes run in a newly created environment with no reset step. When startup creates more than one resource, also force a startup failure after one resource exists and check that cleanup removes it. Check that pre-existing resources are unchanged and evidence survives. Test the wait helpers with a short completion and a timeout. Re-run only the affected checks after a correction.
- **`quick`:** skip the second drive and the failure test: the first summary and the fixers' lines are the record. Then clean up and check that evidence survives.

A feature that is partial, blocked or failing is reported as such. Writing the map does not complete the proof. A generated skill without live proof is a draft, even if a PR is already open.

## 8. Hand over

Commit everything following the repo's branch and commit conventions. Report per the generated Report section, plus the isolation level, the lifecycle checks and the known product failures as possible product defects: each with its feature, the step that carries it and the contract it misses. When you break something on purpose to test a helper and the helper correctly stops, write "stopped it, as expected", not "failed". Example: "Doctor: I stopped a container, and Doctor correctly refused to continue." In `quick` mode, say that the map is partial. Say that keeping the map in step with the app from now on is `/maintain-verify-<app>`'s job, and explain the maintenance calls:

- `/maintain-verify-<app>` updates the map, adds features missing from it, and drives the features with new or changed steps.
- `/maintain-verify-<app> map only` updates the map without feature drives.
- `/maintain-verify-<app> full audit` drives every feature.
- `/maintain-project-verification-skill` brings the project's skills up to date when this generator changes. It accepts the same three modes and runs focused checks for changed helpers in every mode.

When `usage-report` is on `PATH`, end the report with the output of `usage-report --cwd <repository> --since <today>`, with the repository's absolute path and today's date as `YYYY-MM-DD`.
