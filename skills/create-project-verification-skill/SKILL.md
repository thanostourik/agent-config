---
name: create-project-verification-skill
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Generate the project's verify skill, committed in the repo or in a separate companion repo, so every developer's agent (Claude Code, Codex, Grok, Cursor) can drive every feature of the real app end to end and prove its work. Use for /create-project-verification-skill or \"set up verification for this repo\"."
disable-model-invocation: true
---

# Create a project verification skill

This skill gives a project a `verify-<app>` skill: an isolated environment, one bash recipe
per feature, and the shipped runner `bin/verify` that drives them in parallel with no agent.
Agents then drive the features a change touches before calling work done. You write for the
next agent, which reads the result cold, mid-task.

Budget: a whole project is recorded in about 30 minutes. Keep your own context small: you
write the environment and the first recipe, and recorders write the rest.

When you need me to make a choice before you can continue, use your question tool if you
have one, or ask in your reply if you don't. If the question gets no answer, ask again in
your reply and wait. Do not answer it yourself.

If `.agents/skills/verify-*` already exists, stop before writing anything. Ask whether to
replace it (delete and generate again) or upgrade it with
`/maintain-project-verification-skill`.

`<generator>` below is this skill's folder.

## What you write

```
.agents/skills/verify-<app>/
  SKILL.md            <generator>/references/verify-skill.md, with <app> filled in
  PROJECT.md          this project's facts (step 3)
  bin/verify          copied from <generator>/references/verify, unchanged
  bin/lib.sh          copied from <generator>/references/lib.sh, unchanged
  bin/harvest         copied from <generator>/references/harvest, unchanged
  bin/launch.sh bin/cleanup.sh bin/doctor.sh bin/observe.sh bin/entrypoints.sh
  bin/<driver helpers>
  features/<feature>.sh
  .gitignore          holds .cache/
  apps                companion repo only
.claude/skills/verify-<app>/SKILL.md   stub from <generator>/references/claude-stub.md
.claude/settings.json                  "Bash(sudo:*)" merged into permissions.deny
```

`<app>` is a short lowercase name. Codex, Cursor, Grok and OpenCode read `.agents/skills/`;
Claude Code reads only `.claude/skills/`, so the stub exists for it. Never use symlinks.
Never edit `SKILL.md`, `bin/verify` or `bin/lib.sh` for the project: an upgrade replaces them.
Everything project-specific goes into `PROJECT.md`, `bin/` helpers and `features/`.

## Companion repo

Some projects must not show that agents work on them. Their skill lives in a companion repo:
a separate git repo next to the app checkouts that holds only agent files. Run one
`git ls-files` here. When it lists no app source, this is a companion: ask for the path of
each app checkout and write `.agents/skills/verify-<app>/apps`, one line `<name> <path>` per
app, the path relative to this repo's root. `bin/verify` exports each as `APP_<NAME>` (upper
case, `-` as `_`), and a value the caller set wins. Recipes, `# touches:` and helpers name app
files as `<name>/<path>` and reach them through `$APP_<NAME>`.

Nothing goes into an app checkout: no file, no dependency, no build output. Build from a copy
under `.cache/` or send build output outside the checkout. Run git against a checkout with
`GIT_OPTIONAL_LOCKS=0`. A checkout that does not build is reported, not fixed. Playwright,
when needed, goes into the companion's own `package.json`.

## 1. Read the repo

Answer from the codebase; ask only what you cannot observe. Spend minutes, not an hour.

- **Surfaces:** web UI, API, CLI or TUI, desktop, mobile, firmware, jobs.
- **Run:** how the app starts locally, its dependencies, ports, seed data and sign-in.
- **Harness:** existing end-to-end specs, sign-in or seed helpers, curl-able endpoints.
- **Entry points:** the files that define routes, screens, commands or endpoints, found
  with one grep. That grep becomes `bin/entrypoints.sh`.
- **Checks:** the focused test, lint and type-check commands.
- **Sibling repos:** another repo the app needs at run time, such as a backend. Use the path
  its docs name, else `../<name>`, and write it into `PROJECT.md`.

If the app does not build or start as-is, fix that or report it before going on.

## 2. Isolation

Choose the isolation level once, following
[`references/lifecycle.md`](references/lifecycle.md): `full` (default), `shared` or
`checks-only`. A project with `local-stack/stack` uses it: `launch.sh` runs
`local-stack/stack up --app --stubs --name "$VERIFY_RUN_ID"`, plus the `--mode` options the
features need, and `cleanup.sh` runs `local-stack/stack destroy --name "$VERIFY_RUN_ID"` and
removes the lock files under `~/.local/state/local-stacks/` of that stack and of every stack
it started for a dependency. Ask the user only when `full` is not
possible.

## 3. Write the environment and `PROJECT.md`

Write and make executable:

- `launch.sh`: creates and starts the run's environment, registering each resource as it is
  created, and waits until it is ready with a bounded deadline. It is idempotent: when the
  run's environment already exists, it rebuilds and restarts only the app, so a second
  `bin/verify up` takes seconds or a short rebuild, not a fresh start. `$VERIFY_RUN_ID` names
  the run and is stable until `bin/verify down`.
- `cleanup.sh`: removes only what the run created, on success, failure and interruption,
  and checks that none of it remains. It never checks resources that existed before. With no
  run recorded, it exits 0.
- `env.sh` (optional): exports the run's values that recipes and helpers need, such as base
  URLs, ports and keys, read from the run's record. The runner sources it before each recipe.
- `after-feature.sh` (optional): runs after every recipe's `cleanup`, such as closing the
  feature's browser session, so a finished feature holds nothing until `bin/verify down`.
- `doctor.sh`: one fast, read-only check that the environment is this run's and healthy:
  processes up, right checkout, ports owned, sign-in works. It never adopts a process outside
  the run's record.
- `observe.sh <path>`: saves the app's current state for a failed step: the snapshot or
  screenshot of the feature's browser session (`$VERIFY_SESSION`), the last HTTP response, or
  the last command output.
- `entrypoints.sh`: prints every entry point, one per line, as `<entry point><TAB><file>`:
  a route with its method (`POST /api/notes`), a screen's path, a command (`todo add`), a
  job or message handler. It is a search over the source, such as route annotations or a
  router file, so it finds new entry points by itself. `bin/verify uncovered` compares it
  with the recipes' `# covers:` lines.
- Every helper also works when an agent calls it by hand, outside `bin/verify`: it sets
  `: "${VERIFY_SKILL:=$(cd "$(dirname "$0")/.." && pwd)}"` and defaults the other `VERIFY_*`
  variables it reads.
- Driver helpers, keyed on `$VERIFY_SESSION` when they keep state. For a web UI without its
  own harness, `pw.sh` runs the Playwright CLI (`playwright cli`) with:
  - a pinned Playwright version whose browser build is installed (`ls ~/.cache/ms-playwright`),
    installed under `.cache/` (`npm install --prefix .cache/pw playwright@<version>`) when the
    project has none, and called through its installed binary, not `npx` on every call;
  - the session `-s="$VERIFY_RUN_ID-$VERIFY_SESSION"`, so runs of other projects and
    checkouts never share a browser session (`playwright cli list` shows every session on the
    machine, so cleanup matches its own names exactly), and its output under `.cache/`;
  - `--raw` to silence page snapshots, and the output of `open` sent to a file; with `--raw`,
    errors arrive on stdout as `### Error`, so never send that output to `/dev/null`;
  - `after-feature.sh` closing the feature's session, and cleanup closing every session the
    run opened and removing its `<session>.err` files under `~/.cache/ms-playwright/daemon/`.
  For an API, an `api` helper wraps `curl` with the base URL, auth, `--max-time`, and saves
  the last response for `observe.sh`.

Then write `PROJECT.md`, under about 10 KB, with these sections:

- **Drivers:** the driver phrase, such as `Playwright CLI and curl`, and why.
- **Isolation:** `Isolation level: <level>`, one line on why, what the run owns and its
  markers, and the success paths isolation makes unreachable.
- **Environment:** what `launch.sh`, `cleanup.sh` and `doctor.sh` do, how long a first and
  a second `bin/verify up` take.
- **Sign-in and data:** the test accounts and baseline data a recipe can count on, each
  checked with one command against the running environment.
- **Helpers:** one line per helper with one real call as a recipe writes it, what it checks
  or returns, and its deadline when it waits.
- **Focused checks:** the test, lint and type-check commands.
- **Gotchas:** traps that hold for several features, one line each with the fix. A trap of
  one feature stays in that recipe's header. Start with the driver's.
  Playwright CLI: `click` and `fill` do not wait for the element, so wait in `run-code`
  first; a `confirm()` dialog blocks every command until it is handled; a role name matches
  as a substring unless `exact: true`.

Copy `references/verify-skill.md` to `SKILL.md` with `<app>` filled in, `references/verify`,
`references/lib.sh` and `references/harvest` to `bin/`, and write the Claude stub and `.gitignore`. Then run
`bin/verify up`, then `bin/verify up` again and time both.

For a CLI or a library there is no process to restart: `launch.sh` prepares the run's data
folder and builds once, and `doctor.sh` checks that the folder is the run's and the build is
current.

Build the environment for speed, because every recipe pays for it on every run:

- Key every per-run file and port on `$VERIFY_RUN_ID`, never a fixed path such as
  `.cache/run/`, so lanes (extra copies of the environment, `bin/verify up --lanes N`) can
  run side by side.
- Shorten every timer the features wait on in the run's own configuration: job intervals,
  retry delays, grace periods, expiries, polling. Write each override and the recipes that
  rely on it into `PROJECT.md`; before shortening a job for all features, check which
  recipes set up the state that job consumes.
- Keep each copy small so lanes fit in memory: cap worker counts and heap sizes (a JVM
  without `-Xmx` takes a quarter of the machine). Start JVM apps with
  `-XX:TieredStopAtLevel=1 -XX:+UseSerialGC`; it cut startup by 15 to 20% in trials.
- A stub or helper that starts a process stops any leftover of the same feature first, so an
  interrupted run never blocks the next one.

At level `checks-only`, skip launching and recording: write no recipes, put the focused
checks in `PROJECT.md`, and go to step 6.

## 4. Record every feature

1. Group the output of `bin/entrypoints.sh` into features: one user-facing capability
   each, with a one-line scope and its entry points. Every entry point belongs to exactly
   one feature. For each feature, write its expectation list with
   `bin/harvest '<its words>' <its test files> <its docs> > .cache/expect/<feature>.txt`:
   the test names and the docs lines that state its behavior. Every listed test becomes an
   `# expects:` line, so recorders never search for behavior. A feature's name is its file name and never a `verify` command
   (`list`, `all`, ...). Keep the list in `.cache/features.txt`, not in a file of the skill.
2. Write the first recipe yourself, for the simplest feature, following the Recipes section
   of the skill you copied. Run `bin/verify <feature>` until it passes. It becomes the
   example every recorder copies, so make it clean. Then drive the main create path by
   hand once: create the same record twice, and read it as a second tenant or user. Write
   what that shows about ids, uniqueness and shared data into `PROJECT.md`'s Gotchas before
   any recorder starts, so no recorder pays for the same trap.
3. Start recorders with the prompt in the skill's Recorders section, with the repository's
   absolute path filled in, up to 8 at once. When the host refuses one, start it when
   another returns; with no helper agents at all, record the rest yourself. Size the groups
   so all features fit in about four rounds of the recorders you can actually run: 2 or 3
   related features each, heaviest groups first. Start recorders on the host's fast model
   (such as `sonnet`) when it offers one: in trials it was 3 times faster at the same depth.
   Start them in the background and start a new one as each returns. Give a feature its own
   namespace (schema, prefix, account, data folder) before marking it `# alone`; when some
   stay `# alone`, run `bin/verify up --lanes 1` first, so they record alongside the
   others. After 25
   minutes, start no new recorder and list the features not reached; sending a failing
   feature back in step 5 is still allowed.
4. Read only their result lines. Fold their traps into `PROJECT.md`'s Gotchas.

## 5. Prove it

Run `bin/verify down`, `bin/verify up` and `bin/verify all`, so every recipe runs once more
from a fresh environment while the others run in parallel. Then run `bin/verify all` again
on the same environment: a recipe that fails the second time is not repeatable. Send each failing feature back to
a recorder with its summary line. Write the `--jobs` value that worked into `PROJECT.md`
when it is not the default. When `# alone` features remain, write the lane count that keeps
the full drive shortest into the skill's `lanes` file: about their total time divided by the
longest parallel feature, as far as memory allows. Then check the lifecycle once:

- `bin/verify lint` and `bin/verify uncovered`. Map an uncovered entry point or say why not.
- Commit, change one file a feature touches, and check that
  `bin/verify affected --dry --base HEAD` selects it. Without `--base HEAD` on this branch,
  every new recipe counts as changed. Undo the change. In a companion, change a copy of the
  app checkout instead and point `APP_<NAME>` at it.
- Check that `bin/verify down` leaves nothing of the run outside `.cache/`: no process, port,
  container, browser session or file.

## 6. Instructions and hand-over

Write one `## Verification` section in the project's `AGENTS.md` (the companion's, in a
companion repo; create the file when there is none) from [`references/agents-verification.md`](references/agents-verification.md),
with `<app>` and the focused check commands filled in. Integrate an existing verification
section instead of adding a second one; a section that points at a verify skill this run
replaces is rewritten. If there is no `CLAUDE.md`, create one holding only
`@AGENTS.md`; if one exists without that import, put the same section there too. Replace
agent instructions for launching the app by hand with a pointer to the skill; leave the
README's instructions for people. Report an older verification
system instead of deleting it.

Merge `Bash(sudo:*)` into `permissions.deny` of `.claude/settings.json`, keeping the rest.
Commit following the repo's conventions. Report: the isolation level, how long recording and
`bin/verify all` took, one line per feature (pass, fail with its kind, or blocked with what
was tried), product defects found, and the features not reached.
