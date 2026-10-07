---
name: create-project-verification-skill
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Generate the project's own verification skills, committed in the repo, so every developer's agent (Claude Code, Codex, Grok, Cursor) can drive the real app and prove its work. Use for /create-project-verification-skill, /create-project-verification-skill quick, or \"set up verification for this repo\"."
disable-model-invocation: true
---

# Create a project verification skill

Every serious project needs a scripted way to drive the real app and prove behavior: launch it, exercise a feature the way a user would, and capture evidence. This skill generates that as two project skills committed in the repo, so every developer's agent gets them without any global setup. You write the output for the next agent, not for a human. It will be read cold, mid-task, by an agent that has never seen the app.

## Modes

- `/create-project-verification-skill` (default): write everything, then run a full audit (step 7).
- `/create-project-verification-skill quick`: map only one feature per surface, drive each of them once as a smoke proof, and stop. `/maintain-verify-<app>` finds the other features in the source and adds them later.

Honor an equivalent request, such as "without the audit". Do not ask which mode to use.

If `.agents/skills/verify-*` or `.agents/skills/maintain-verify-*` already exists, stop before writing anything. Ask the user whether to replace those skills (delete them and generate again) or to upgrade them with `/maintain-project-verification-skill`. Never overwrite them silently.

Messages you post anyway may carry progress lines such as `map 3/15: projects.md written` or `drive 7/16: projects — pass`. Never change how you split, delegate or order work to produce them, and never add a turn just to report.

## What you write

```
.agents/skills/verify-<app>/                    the verification skill
  SKILL.md
  features/README.md, features/<feature>.md     the feature map
  bin/                                          helpers
  .gitignore                                    ignores .cache/
  .cache/                                       everything a run writes
.agents/skills/maintain-verify-<app>/           map maintenance with three drive modes
  SKILL.md
  agents/openai.yaml
.claude/skills/verify-<app>/SKILL.md            stub for Claude Code
.claude/skills/maintain-verify-<app>/SKILL.md   stub for Claude Code
```

`<app>` is a short lowercase name. Codex, Cursor, Grok and OpenCode read `.agents/skills/`. Claude Code reads only `.claude/skills/`, so the stubs exist for it. Never use symlinks: Windows checkouts turn them into plain files.

Helper agents may read source in small concurrent batches, with related features grouped per reader. They return findings and proposed recipes. They never edit files or drive the app. You integrate their findings and own all driving, with one driver at a time. Do not create one agent per feature by default.

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

Write `.agents/skills/verify-<app>/SKILL.md` following [`references/verify-skill-spec.md`](references/verify-skill-spec.md). Include the failure rules from [`references/drive-failures.md`](references/drive-failures.md). Write helpers in `bin/` and make them executable.

## 4. Map every feature

Create `features/README.md` and one file per feature the project exposes to people or other software: screens, route groups, commands, endpoint groups, library operations, and their data effects and background processing. Find them from code and docs. Do not map internal functions. In `quick` mode, map only one feature per surface, the ones step 7 drives. Follow [`references/feature-map-example/`](references/feature-map-example/).

`features/README.md` holds the baseline every feature starts from, the driving conventions, the feature file shape and the index.

Each feature file starts with an H1 and one paragraph on the observable behavior, then exactly four H2s in this order:

1. `Sub-features`: short IDs, one line per behavior.
2. `How to get to it (user POV)`: every entry point a user has.
3. `Driving it with <tool>`: `Preconditions:` with exact setup, then labeled bullets that pair a user action with an exact command and its observable result. End with proof and fixture cleanup. Each labeled bullet is a **step**. Preconditions are setup, not steps. A fixture that is itself a user action worth proving gets its own labeled step.
4. `Gotchas`: traps that waste or invalidate a run.

Keep code paths out of the map. The agent maps a change to features by reasoning, and the audit reads the source. A proof that drives one convenient entry point is incomplete when the file lists others.

Each recipe runs from the documented baseline in a fresh session. It sets up its own data instead of relying on another feature having run, and it keeps variable creation and use in one command block or persists them under `.cache/`. State any unavoidable ordering. Prefer a fresh identity or namespace per recipe over deleting fixtures afterwards. Otherwise restore fixtures so the recipe can run again. For an irreversible operation, use a disposable fixture the run removes. Administrative setup and cleanup are fine inside the isolated environment, but never substitute them for the user action being proved. The example map is a fictional app: derive real commands from this project and run them.

## 5. Write `maintain-verify-<app>` and the stubs

Copy [`references/maintain-verify.md`](references/maintain-verify.md) to `.agents/skills/maintain-verify-<app>/SKILL.md` and [`references/maintain-verify-openai.yaml`](references/maintain-verify-openai.yaml) to `.agents/skills/maintain-verify-<app>/agents/openai.yaml`. Replace `<app>`, and replace `<driver>` with the driver named in `verify-<app>`'s driver block. Adjust only what this project needs, for example how its PRs are opened.

Write the two Claude Code stubs from [`references/claude-stub.md`](references/claude-stub.md). Their `name` and `description` must match the real skills exactly. The maintain stub also carries `disable-model-invocation: true`.

## 6. Reconcile the project's verification instructions

Write one coherent `## Verification` section in the project's `AGENTS.md`, from [`references/agents-verification.md`](references/agents-verification.md). Replace `<app>` and `<work-scope>` with the app name and a concrete scope, such as "backend work" or "command-line tool changes". Integrate an existing verification section instead of appending a second one. With several apps, say which surface each skill covers. Use links relative to `AGENTS.md`.

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If the project has a `CLAUDE.md` that does not import `AGENTS.md` (`@AGENTS.md`), put the same section in `CLAUDE.md` too.

Read the rest of those files and anything they import for conflicting verification guidance. Replace superseded manual launch and cleanup recipes with references to the skill. Reconcile stale startup restrictions with the user's instructions and existing authorization. Do not invent a new approval requirement or silently remove a deliberate restriction. If a conflict cannot be resolved from those instructions, ask about that one conflict. Keep ports, resource names and lifecycle commands only in the skill, so there is one maintained procedure.

Keep the project's test, lint and type-check guidance, and add the exact focused commands from the repo where missing. Do not turn every verification into a full build. If an older verification system exists, report what it overlaps and conflicts with. Do not delete it without explicit authorization. Leave unrelated instructions alone.

## 7. Prove it

Run `maintain-verify-<app>` on what you wrote. Drive the recipes from a fresh session, not from unrecorded exploratory state.

- **Default:** `full audit`. Every feature file is checked against source and every step is driven live. After the audit, run a representative state-changing feature, clean up, and run it in a newly created environment with no reset step. When startup creates more than one resource, also force a startup failure after one resource exists and check that cleanup removes it. Check that pre-existing resources are unchanged and evidence survives. Test the wait helpers with a short completion and a timeout. Re-run only the affected checks after a correction.
- **`quick`:** drive each mapped feature once from a fresh session, then clean up and check that evidence survives. Skip the audit and the failure test.

A feature that is partial, blocked or failing is reported as such. Writing the map does not complete the proof. A generated skill without live proof is a draft, even if a PR is already open.

## 8. Hand over

Commit everything following the repo's branch and commit conventions. Report per the generated Report section, plus the isolation level and the lifecycle checks. In `quick` mode, say that the map is partial and unaudited. Explain the maintenance calls:

- `/maintain-verify-<app>` updates the map, adds features missing from it, and drives new and changed steps.
- `/maintain-verify-<app> map only` updates the map without feature drives.
- `/maintain-verify-<app> full audit` drives every step of every feature.
- `/maintain-project-verification-skill` brings the project's skills up to date when this generator changes. It accepts the same three modes and runs focused checks for changed helpers in every mode.
