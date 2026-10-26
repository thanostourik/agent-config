---
name: create-project-verification-skill
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Generate the project's own verification skills, committed in the repo or in a separate companion repo, so every developer's agent (Claude Code, Codex, Grok, Cursor) can drive the real app and prove its work. Use for /create-project-verification-skill, /create-project-verification-skill quick, or \"set up verification for this repo\"."
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

When you send a message anyway, you may add one progress line, such as `recorded 12/88`, at most once per 6 finished recorders. Never send a message or reorder work just to report.

## Companion repo

Some projects must not show that agents work on them. Their verification skills live in a **companion repo**: a separate git repo next to the app checkouts that holds only agent files. Before anything else, run one `git ls-files` here. When it lists no app source, such as a build file or a source tree, this is a companion: ask the user for the path of each app checkout, then go on. Write them to `.agents/skills/verify-<app>/apps`, one line per app, `<name> <path>`, the path relative to this repo's root, such as `otis ../otis`. `bin/drive.sh` and `bin/rec.sh` export each path as `APP_<NAME>`, upper case with `-` as `_`, and a value the caller already set wins, so a run can drive another checkout: `APP_OTIS=~/wt/otis bin/drive.sh search`. A helper that needs an app checkout starts with `source "$(dirname "$0")/steps.sh" && export_apps "$(dirname "$0")/../apps"`.

In a companion, the steps below read source, docs and tests in the app checkouts and write only to this repo. Nothing goes into an app checkout: no file, no dependency, no ignore entry, no commit. A checkout that does not build or start is reported, not fixed. Each change-trigger glob starts with its app's name, such as `` `otis/src/export/*`: pdf-export ``. Playwright, when the project lacks it, goes into this repo's own `package.json`. The `## Verification` section of step 6 goes into this repo's `AGENTS.md`.

## What you write

```
.agents/skills/verify-<app>/                    the verification skill
  SKILL.md
  features/README.md, features/<feature>.md     the feature map
  bin/                                          helpers, including drive.sh, doctor.sh, observe.sh and find.sh
  .gitignore                                    ignores .cache/
  apps                                          in a companion repo only: the app checkouts
  .cache/                                       everything a run writes
.agents/skills/maintain-verify-<app>/           map maintenance with three drive modes
  SKILL.md
  agents/openai.yaml
.claude/skills/verify-<app>/SKILL.md            stub for Claude Code
.claude/skills/maintain-verify-<app>/SKILL.md   stub for Claude Code
.claude/settings.json                           permissions.deny gets "Bash(sudo:*)", merged in
```

`<app>` is a short lowercase name. Codex, Cursor, Grok and OpenCode read `.agents/skills/`. Claude Code reads only `.claude/skills/`, so the stubs exist for it. Never use symlinks: Windows checkouts turn them into plain files.

Helper agents build and repair the recipes, so your own context stays small. A **recorder** writes one feature's recipe and runs it against the live app with `bin/rec.sh` (step 4). A **fixer** repairs one recipe that failed a drive (step 7). Each gets a brief file, and both briefs send it first to the **common file**, `.cache/record/brief-common.md`, which holds what is the same for every helper. Helpers and Helper briefs in [`references/maintain-verify.md`](references/maintain-verify.md) describe both helpers, their brief files and what you read of their work.

## 1. Interview the repo, not the user

Answer these from the codebase. Ask the user only what you cannot observe.

- **Surface:** what the project exposes to people or other software: web UI, CLI/TUI, desktop app, API, mobile app, firmware, library. Pick the primary one and note the rest.
- **Verification triggers:** the changes that could affect that behavior, named from this repo. Include internal components and configuration, not only screens. Examples: endpoints, services, routing and authentication for a backend; command handling, output and file effects for a CLI. Observable behavior includes responses, permissions, stored data, background jobs and external side effects.
- **Run:** how the app starts locally. Prefer the repo's documented dev command. Note ports, env vars, seed data and auth.
- **Depends on:** what must run next to it: databases, auth servers, other services. Read the README and the docs it links (a `PLATFORM.md` naming sibling repos, compose files). For a service in another repo, learn how to start it there. Ask the user where that checkout is if you need to read it.
- **Contract sources:** the README, docs, plans, tests and specs that say what the features should do. Note when there is nothing beyond a high-level README.
- **Existing harness:** specs, helper scripts, sign-in or seed tools, curl-able endpoints, a debug port. Reuse them.
- **Side effects of starting:** what startup may change: files, data, processes, external systems. Check what is already running (`ps`, `ss -ltn`), such as an installed copy of the app holding a port, a global hotkey or a single-instance lock, and record it as original state. See [`references/lifecycle.md`](references/lifecycle.md).
- **Observe:** the evidence you can capture: screenshots, accessibility snapshots, terminal transcripts, response bodies, logs, exit codes, database state.

If the checkout does not build or start as-is, fix that first, or report it precisely, before generating. A skill written against a broken base teaches wrong steps. When an irrelevant missing asset blocks startup, the generated skill may create it, marked as verification scaffolding, and remove it in cleanup.

## 2. Decide once, write one path

Decide these now, with the user where needed, and write the concrete choice into the skill.

- **Isolation.** Verification must never touch what the developer uses. Choose the isolation level (`full`, `shared` or `checks-only`), the ownership markers and the lifecycle commands, following [`references/lifecycle.md`](references/lifecycle.md). Ask the user only when `full` is not possible.
- **Drive tool.** Reuse the repo's own harness first. Otherwise use the defaults in [`references/verify-skill-spec.md`](references/verify-skill-spec.md). Every step is a shell command.

## 3. Write `verify-<app>`

Write `.agents/skills/verify-<app>/SKILL.md` following [`references/verify-skill-spec.md`](references/verify-skill-spec.md). Include the failure rules from [`references/drive-failures.md`](references/drive-failures.md). Copy [`references/drive.sh`](references/drive.sh), [`references/steps.sh`](references/steps.sh) and [`references/rec.sh`](references/rec.sh) to `bin/` unchanged. Write the other helpers in `bin/` and make them executable, among them `observe.sh` and `find.sh` for this project's driver, as the spec's Helpers item describes: `rec.sh` looks at the app only through them. Each line of the Helpers section shows one real call of its helper, as the spec's Helpers item describes.

## 4. Map every feature

List the features the project exposes to people or other software: screens, route groups, commands, endpoint groups, library operations, and their data effects and background processing. One grep over routes, navigation, command definitions and endpoints lists them, next to the docs read in step 1: a list, not a read of every component. Do not map internal functions. In `quick` mode, keep only one feature per surface, the ones step 7 drives. Follow [`references/feature-map-example/`](references/feature-map-example/).

Write `features/README.md` first. It holds the baseline every feature starts from, the driving conventions, the gotchas, the change triggers, the feature file shape and the index. `## Gotchas` lists the traps that hit every feature, one line each with its fix; it may start empty, and step 8 adds what recorders found. The common file carries this file's Baseline, Driving conventions, Feature file shape and Gotchas sections, next to the skill's Helpers section, and the recorder reads no skill file. So the Driving conventions state each recipe rule of this step once, tersely, and add `Driver limits`: the traps of this project's drivers, one line each with its fix. Examples:

- Playwright CLI: `pw.sh click` and `fill` do not wait for the element, so wait for it first. No command prints a confirm dialog's text, and every command fails while one is open; wrap `window.confirm` in `run-code`. A multi-line string breaks `run-code`; join its lines. A locator containing `"` goes inside `run-code`, not on the command line. `locator.ariaSnapshot()` drops generic names; read attributes instead. A role name matches as a case-insensitive substring; pass `exact: true` when another name contains yours.
- HTTP: check the status before the body, because an error response can carry a body that matches. A list endpoint returns one page; follow its pagination before counting. An auth token can expire during a recipe; get a fresh one in Preconditions.
- CLI: check the exit code before stdout, because a failing command can still print the expected text. Errors go to stderr, which `$(...)` does not capture; check it separately.

 The recorder's brief carries its own index line, the other features' names, the scope rule and what to do past about 15 steps, so the conventions leave those out. Under `## Change triggers`, each line holds step 1's verification trigger paths as backticked globs, `*` spanning `/` and `?` one character, then `: ` and the comma-separated features they affect; `verify-<app>`'s Pick features step and maintenance select from those lines. The index gives every feature one line with its name and scope before any recorder starts. No behavior falls in two scopes.

Each feature file starts with an H1 and one paragraph on the observable behavior, then exactly five H2s in this order:

1. `Sub-features`: short IDs, one line per behavior.
2. `How to get to it (user POV)`: every entry point a user has.
3. `Driving it with <tools>`, naming every driver the recipe uses: `Preconditions:` with its setup, then labeled bullets `- **<Label>.**`, each a **step**. Every step states one user action and its observable result in one or two short sentences, followed by a fenced `bash` block. Split a step that proves several results. The block exits non-zero when the result is not met: a command that only prints a value gets a check, such as `test`. Blocks run under `set -euo pipefail`, where `! command` never fails a block, so write negative checks with `test` or `if`. Preconditions get a block too. End with proof, then the known-failure step described below, if any, then a last step labeled `Clean up` that removes the feature's fixtures; `drive.sh` runs it even after a failure. A fixture that is itself a user action worth proving gets its own step. The section holds at most about 15 steps, `Clean up` included, because a recorder's cost and context grow with every step it writes and repairs. A feature that needs more is several features, split by groups of sub-features, each with its own file, index line and change triggers.
4. `Contract`: one line per mapped `section`, `- <file>:<heading> → <step labels>` or `- <file>:<heading> → not driven: <reason>`. `rec.sh run` and `drive.sh --check` refuse a file that skips one.
5. `Gotchas`: traps that waste or invalidate a run.

Keep code paths out of the feature files; only the change triggers name source. Every behavior the contract sources name for the feature, such as a test case, a README sentence, a plan's acceptance line or an entry point, gets a step. So does every sub-feature line and every entry point the file lists, or it is reported as blocked with the reason. A test case names a behavior to drive through the app; a recipe never runs the project's own tests or build. The feature's index line bounds it: a step belongs to the feature whose index line names the behavior. A behavior another feature's index line names is not tested again here. When the recipe needs it, it is setup, done in the fewest commands and with no check beyond what the recipe's own steps need. A behavior that fits no index line is reported under Split or Blocked, never tested in passing.

Each recipe runs from the documented baseline in its own session, possibly while other features run. It sets up its own data instead of relying on another feature having run. Steps of one feature share shell variables and functions, so the Preconditions block can define what later steps use. A feature you saw change state other features read, such as global settings, says `Runs alone.` in its Preconditions sentence; nothing else runs features one at a time. Prefer a fresh identity or namespace per recipe over deleting fixtures afterwards. Otherwise restore fixtures so the recipe can run again. For an irreversible operation, use a disposable fixture the run removes. Administrative setup and cleanup are fine inside the isolated environment, but never substitute them for the user action being proved. The example map is a fictional app: derive real commands from this project and run them.

Blocks wait for the observable state with the project's wait helpers or the driver's own waits, never with `sleep` or a fixed timeout in place of a condition. A contract that states a time, such as "expires after 2.5 s" or "autosaves about 400 ms after the last keystroke", is checked with a wait bounded to that time plus a small margin, never with a helper's default deadline. The proof step saves evidence under `.cache/evidence/<feature>/`: a screenshot or accessibility snapshot for a UI, the response body or command output otherwise. `Clean up` removes what the recipe created and closes its sessions; when the project has a way to check that, it ends with that check. `|| true` goes only on a command whose failure cannot matter, such as a delete that the check after it covers. When the app does not do what the contract says, that behavior is a **known failure**, and its check stays in the recipe. The check goes into the **known-failure step**, run with `rec.sh <feature> run --known-failure '<Label>'`, so every drive reports it and still proves the rest. `drive.sh` stops at the first failing step, so that one step carries all of the feature's known failures, in one block that runs every check and fails at the end. Any setup it needs happens inside that step. Its sentence states the contract. It is never weakened, dropped or moved to Gotchas.

Then record the features. At isolation level `checks-only`, skip launching and recording: write each Driving section as step sentences without `bash` blocks, and its steps stay `blocked: no isolation`. Otherwise write `maintain-verify-<app>` first, as step 5 describes, because `rec.sh` reads its brief templates from it. Then record every feature as that skill's Update the map step 3 does, from the launch to `bin/rec.sh install`. Only these things differ on a first run:

- Every feature is new: none has a file in `features/` yet. In the once-per-run command the mode is `full` and `refused` is empty, so `convert.txt` stays empty.
- There is no `features/last-reviewed` and no starting record, so no brief lists changes or changed conventions, and `rec.sh sendback` prints nothing.
- The project has no recipe yet, so `rec.sh common` writes no example recipe until a staged copy of at least five steps has passed `rec.sh run`. Until then, every call that runs `rec.sh common` also appends to the common file the Preconditions and first two steps of [`references/feature-map-example/create-note.md`](references/feature-map-example/create-note.md), under the heading `## Example recipe, from a fictional app; take its shape, not its commands`.

## 5. Write `maintain-verify-<app>` and the stubs

Copy [`references/maintain-verify.md`](references/maintain-verify.md) to `.agents/skills/maintain-verify-<app>/SKILL.md` and [`references/maintain-verify-openai.yaml`](references/maintain-verify-openai.yaml) to `.agents/skills/maintain-verify-<app>/agents/openai.yaml`. Replace `<app>`, and replace `<driver>` with the driver named in `verify-<app>`'s driver block. Step 4 does this before the first recorder starts. Write this project's main-screen snapshot command into Update the map step 3, and 6 in place of `<n>` in `Recorders at once: <n>`, which `rec.sh next` reads. Merge `Bash(sudo:*)` into `permissions.deny` of `.claude/settings.json`, keeping what the file holds, so no recorder on Claude Code runs `sudo`. Adjust only what this project needs besides, for example how its PRs are opened.

Write the two Claude Code stubs from [`references/claude-stub.md`](references/claude-stub.md). Their `name` and `description` must match the real skills exactly. The maintain stub also carries `disable-model-invocation: true`.

## 6. Reconcile the project's verification instructions

Write one coherent `## Verification` section in the project's `AGENTS.md`, from [`references/agents-verification.md`](references/agents-verification.md). Replace `<app>` and `<work-scope>` with the app name and a concrete scope, such as "backend work" or "command-line tool changes". Integrate an existing verification section instead of appending a second one. With several apps, say which surface each skill covers. Use links relative to `AGENTS.md`.

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If the project has a `CLAUDE.md` that does not import `AGENTS.md` (`@AGENTS.md`), put the same section in `CLAUDE.md` too.

Read the rest of those files and anything they import for conflicting verification guidance. Replace superseded manual launch and cleanup recipes with references to the skill. Reconcile stale startup restrictions with the user's instructions and existing authorization. Do not invent a new approval requirement or silently remove a deliberate restriction. If a conflict cannot be resolved from those instructions, ask about that one conflict. Keep ports, resource names and lifecycle commands only in the skill, so there is one maintained procedure.

Keep the project's test, lint and type-check guidance, and add the exact focused commands from the repo where missing. Do not turn every verification into a full build. If an older verification system exists, report what it overlaps and conflicts with. Do not delete it without explicit authorization. Leave unrelated instructions alone.

## 7. Prove it

At isolation level `checks-only` there is no launch and no `drive.sh` call: the proof is the focused checks that [`references/lifecycle.md`](references/lifecycle.md) names, and every feature is reported `blocked: no isolation`. The rest of this step applies to the other levels.

The selected features are every mapped feature; in `quick` mode, the recorded ones. Drive them in parallel, check that parallel features stayed apart, and write the `--jobs` value that worked into the skill's Drive section. Drive them from a fresh environment, not from the state the recorders left, and fix the failing ones, as `maintain-verify-<app>`'s Drive the selected features section says.

- **Default:** every recipe passed `rec.sh run` on the recording environment, ending with its `Clean up` step, and then ran in this newly created environment with no reset step, so each feature has been run, cleaned up and run again. When startup creates more than one resource, also force a startup failure after one resource exists and check that cleanup removes it. Check that pre-existing resources are unchanged and evidence survives. Test the wait helpers with a short completion and a timeout. Re-run only the affected checks after a correction.
- **`quick`:** skip the failure test. Then clean up and check that evidence survives.

A feature that is partial, blocked or failing is reported as such. Writing the map does not complete the proof. A generated skill without live proof is a draft, even if a PR is already open.

## 8. Hand over

When `.cache/record/traps.md` has lines, read it once and fold the lines that still hold into the `## Gotchas` list of `features/README.md` in one edit. Keep the `.cache/record/<feature>/` folder of each blocked feature, so a later pass starts from its staged copy, and name it in the report. Commit everything following the repo's branch and commit conventions. Report per the generated Report section, plus the isolation level, the lifecycle checks and the known failures as possible product defects: each with its feature, the step that carries it and the contract it misses. When you break something on purpose to test a helper and the helper correctly stops, write "stopped it, as expected", not "failed". Example: "Doctor: I stopped a container, and Doctor correctly refused to continue." In `quick` mode, say that the map is partial. When the project had no contract sources beyond a high-level README, say that every expectation in the map is the behavior observed on this date, to be questioned by whoever changes that area, because nothing in the run could tell a bug from an intention. Say that keeping the map in step with the app from now on is `/maintain-verify-<app>`'s job, and explain the maintenance calls:

- `/maintain-verify-<app>` updates the map where source changed since its last pass, adds missing features and drives those with new or changed steps.
- `/maintain-verify-<app> map only` updates the map without feature drives.
- `/maintain-verify-<app> full audit` drives every feature.
- `/maintain-project-verification-skill` brings the project's skills up to date when this generator changes. It accepts the same three modes and runs focused checks for changed helpers in every mode.
