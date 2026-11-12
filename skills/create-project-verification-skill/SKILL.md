---
name: create-project-verification-skill
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Use for /create-project-verification-skill, /create-project-verification-skill quick, or when asked to set up verification for a repo."
disable-model-invocation: true
---

# Create a project verification skill

This skill gives a project a `verify-<app>` skill: an isolated environment, one bash recipe
per feature, and the shipped runner `bin/verify` that drives them in parallel without an
agent. Agents then drive the features a change touches before calling work done. You write
for the next agent, which reads the result in the middle of another task, with no other
context. Recorders are subagents that each write the recipes of one area of the app.

## Modes

- `/create-project-verification-skill` (default): record every feature.
- `/create-project-verification-skill quick`: write the environment and one recipe, with no
  recorders. Do steps 1 to 3, steps 4.1 and 4.2, the lifecycle checks of step 5 except
  `verify uncovered`, and step 6. The one recipe proves that the environment, sign-in, the
  browser helper and cleanup work, and agents copy it. The other recipes grow with the
  code: `verify affected` fails while a change adds a screen, route or action no recipe
  covers, `verify uncovered` lists the rest, and `/verify-<app> full` records them when the
  user asks.

A request with the same meaning picks the same mode; do not ask which mode to use. Keep your
own context small: write the environment and the first recipe yourself, and leave the other
recipes to recorders.

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
  RECORDERS.md        copied from <generator>/references/recorders.md, unchanged
  PROJECT.md          this project's facts (step 3)
  bin/verify          copied from <generator>/references/verify, unchanged
  bin/lib.sh          copied from <generator>/references/lib.sh, unchanged
  bin/harvest         copied from <generator>/references/harvest, unchanged
  bin/areas           copied from <generator>/references/areas, unchanged (needs python3)
  bin/pw.sh bin/pw-close   copied from <generator>/references, unchanged, for a web UI; pw-version beside SKILL.md
  bin/launch.sh bin/cleanup.sh bin/doctor.sh bin/observe.sh bin/server-errors.sh
  bin/entrypoints.sh bin/actions.sh
  bin/<driver helpers>
  features/<feature>.sh
  .gitignore          holds .cache/
  apps                companion repo only
.claude/skills/verify-<app>/SKILL.md   stub from <generator>/references/claude-stub.md
.claude/settings.json                  "Bash(sudo:*)" merged into permissions.deny
```

`<app>` is a short lowercase name. Codex, Cursor, Grok and OpenCode read `.agents/skills/`;
Claude Code reads only `.claude/skills/`, so the stub exists for it. Never use symlinks.
`SKILL.md` and the files marked `unchanged` are the shipped files: an upgrade replaces them,
so never edit them for the project. Everything project-specific goes into `PROJECT.md`, the
other `bin/` helpers and `features/`.

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

Answer from the codebase; ask only what you cannot observe.

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
`checks-only`. It also says which ports a run may use and how to use `local-stack/stack`.
Ask the user only when `full` is not possible. Recipes read every URL and port from
`env.sh`, never `localhost:<default>`.

## 3. Write the environment and `PROJECT.md`

Write and make executable:

- `launch.sh`: creates and starts the run's environment, registering each resource as it is
  created, and waits until it is ready with a bounded deadline. With `VERIFY_APP=dev` it
  runs the app with its developers' own dev command, such as `next dev` or
  `./mvnw spring-boot:run`, as a process the run records, so a code change needs no image
  build. With `VERIFY_APP=build` it runs the production build. The run's environment uses `dev`
  unless its first `bin/verify up` sets `VERIFY_APP=build`; `verify all` and lanes always
  use `build`. `launch.sh` is idempotent: when the
  run's environment already exists, it restarts the app, so a second `bin/verify up` takes
  seconds. `$VERIFY_RUN_ID` names the run and is stable until `bin/verify down`.
- `cleanup.sh`: removes only what the run created, on success, failure and interruption,
  and checks that none of it remains. It never checks resources that existed before. With no
  run recorded, it exits 0.
- `env.sh` (optional): exports the run's values that recipes and helpers need, such as base
  URLs, ports and keys, read from the run's record. The runner sources it before each recipe.
- `after-feature.sh` (optional): runs after every recipe's `cleanup`, such as closing the
  feature's browser session, so a finished feature holds nothing until `bin/verify down`.
- `doctor.sh`: one fast, read-only check that the environment is this run's and healthy:
  processes up, right checkout, ports owned, sign-in works. It never treats a process
  outside the run's record as the run's.
- `observe.sh <path>`: saves the app's current state for a failed step: the snapshot or
  screenshot of the feature's browser session (`$VERIFY_SESSION`), the last HTTP response, or
  the last command output.
- `server-errors.sh <epoch seconds>`, for an app with a server: prints the errors the app's
  server logged since that time, each with its stack trace, and nothing when there are none.
  The summary line shows only the first line, so start each error with the request and the
  exception.
  It reads them where this stack writes them, such as `docker logs --since` for a container,
  the app server's log file, or the output of the dev process the run records, in the copy
  `$VERIFY_RUN_ID` names. On a failure, `lib.sh` calls it with the time the failing step
  began and saves its output as evidence, so a UI timeout caused by a server error explains
  itself. A failed `bin/verify up` calls it too, with the time the launch began, so it also
  works on a run whose app never became ready, such as one that stopped at a migration.
  Check it once by causing a server error, such as a request the app answers with
  HTTP 500.
- `entrypoints.sh`: prints every entry point, one per line, as `<entry point><TAB><file>`:
  a route with its method (`POST /api/notes`), a screen's path, a command (`todo add`), a
  job or message handler. It searches the source, such as route annotations or a router
  file, so it finds new entry points by itself. When the project's framework is in
  [`references/discovery.md`](references/discovery.md), list them the way it says: some
  frameworks build entry points at run time, from configuration or the database, where no
  source search finds them. List only what a user or client calls: not update or deploy
  hooks, migrations, compose services or schemas. `bin/verify uncovered` compares it with
  the recipes' `# covers:` lines.
- `actions.sh`: prints every user action, one per line, as `<name><TAB><file>`: each
  function a screen runs when the user acts (event handlers such as `handleDelete`, form
  submits), or, for a project without a UI, each handler method behind an entry point. It
  searches the source, like `entrypoints.sh`. Name an inline handler
  (`onClick={() => remove(id)}`) after its element's label or test id, such as
  `Delete button`, never a line number, which changes whenever the file shifts. List a
  handler the screen gets from a hook or a parent (`const { start } = useDeviceControl()`)
  under the screen's file too: a search for `const handle...` alone misses it.
  `bin/verify uncovered` lists each action that no recipe's `# expects:` line cites by its
  file and name, and `bin/verify affected` lists those in changed files.
- Every helper also works when an agent calls it by hand, outside `bin/verify`: it sets
  `: "${VERIFY_SKILL:=$(cd "$(dirname "$0")/.." && pwd)}"` and defaults the other `VERIFY_*`
  variables it reads.
- A helper's waits and error output follow the "Waits and errors" rules in the shipped
  `SKILL.md`, and a helper that inserts rows directly follows its fixture rule in Data.
  `verify lint` checks only recipes, so check helpers yourself.
- A helper that runs a command inside a container passes environment overrides through
  (`bin/cli -e KEY=VALUE <command>`), so a recipe can point one command at its own schema,
  prefix or folder.
- Driver helpers, keyed on `$VERIFY_SESSION` when they keep state. For a web UI without its
  own harness, copy `pw.sh` and `pw-close` to `bin/` unchanged, and write into the skill's
  `pw-version` file a Playwright version whose browser build is installed
  (`ls ~/.cache/ms-playwright`). `pw.sh` installs that version under `.cache/` on first use,
  and its header says how to call it. `after-feature.sh` runs `bin/pw-close feature` and
  `cleanup.sh` runs `bin/pw-close run`. No recorder calls `pw-close`, because other drives
  share the run's browser. Then write:
  - a sign-in helper that saves each account's storage state once per run and loads it in
    one call, signing each account into a browser session of its own: a second account in
    the same session is signed in as the first through the sign-in provider's cookie;
  - account helpers: creating or deleting an account also removes that account's cached
    state and token;
  - every cached file (token, storage state) written through a temporary file of its own
    (`mktemp` in the same folder) and `mv`: features sign in at once, and a shared
    temporary name makes one feature's `mv` fail.

  For an API, an `api` helper wraps `curl` with the base URL, auth and `--max-time`, and
  saves the last response for `observe.sh`.

Then write `PROJECT.md`, about 10 KB, with these sections:

- **Drivers:** the driver phrase, such as `Playwright CLI and curl`, and why.
- **Isolation:** `Isolation level: <level>`, one line on why, what the run owns and its
  markers, and the success paths the isolation cannot reach (such as a real payment that a
  stub replaces).
- **Environment:** what `launch.sh`, `cleanup.sh` and `doctor.sh` do, how long a first and
  a second `bin/verify up` take.
- **Sign-in and data:** the test accounts and baseline data a recipe can count on, each
  checked with one command against the running environment.
- **Stubs:** for each stub or fake service in the run, what it returns and stores and what it
  cannot do (such as an ML stub that stores nothing, or a collector that returns no data),
  each checked with one call. Recorders read this instead of finding it out in failed runs.
- **Helpers:** one line per helper with one real call as a recipe writes it, what it checks
  or returns, and its deadline when it waits.
- **Focused checks:** the test, lint and type-check commands.
- **Gotchas:** traps that hold for several features, one line each with the fix. A trap of
  one feature goes in that recipe's header instead. Start with the driver's traps. For the
  Playwright CLI: after a click that navigates, wait for the new URL or state before the
  next check. After `goto` or `reload`, wait for an element only the client renders before
  the first click: a click before the page is interactive does nothing. A `confirm()`
  dialog blocks every command until it is handled. A role name matches as a substring
  unless `exact: true`. The `run-code` function runs in a bare sandbox: Node and browser
  globals such as `URL`, `require` and `console` are not there, so parse URLs and log
  inside `page.evaluate`, or return the value.

Copy the shipped files as the tree above shows, and write the Claude stub and `.gitignore`.
Then run `VERIFY_APP=build bin/verify up` in the background, and do step 4.1 while it builds.
Then run `bin/verify up` again, which keeps the production build, and time both.
Generation uses the production build: a dev server holds far more memory, and with many
features at once it loses clicks that land before a page is ready. The first `up` measures
how much memory and time one copy of the environment takes, which the runner needs to decide
on lanes (extra copies of the environment for `# alone` features). Before recorders start,
run `bin/verify up --lanes 1`. A feature marked `# alone` waits until its copy is free of
other features, so on a single copy every other drive stops meanwhile; the extra copy lets
every drive run its `# alone` features there instead. When
the build bakes ports into an image (such as `NEXT_PUBLIC_*` URLs), each lane builds its own.

For a CLI or a library there is no process to restart: `launch.sh` prepares the run's data
folder and builds once, and `doctor.sh` checks that the folder is the run's and the build is
current.

Build the environment for speed, because every recipe pays for it on every run:

- Key every per-run file and port on `$VERIFY_RUN_ID`, never a fixed path such as
  `.cache/run/`, so lanes can run side by side.
- Shorten every timer the features wait on in the run's own configuration: job intervals,
  retry delays, grace periods, expiries, polling. When the project's stack fixes the
  environment and has no override hook, add one to the stack as part of the repo (such as a
  compose override file it reads), or note the gap and start the job once per recipe. Write
  each override and the recipes that rely on it into `PROJECT.md`. Before shortening a job
  for all features, check which recipes set up the state that job consumes.
- Keep each copy small so lanes fit in memory: cap worker counts and heap sizes (a JVM
  without `-Xmx` takes a quarter of the machine). Start the project's own JVM apps with
  `-XX:TieredStopAtLevel=1 -XX:+UseSerialGC`, which shortens startup.
- Give every service of the run a memory limit, third-party ones included: a container
  limit (`mem_limit`) about one and a half times what it uses after a busy run (the example
  recipe's flow plus a few hundred sign-ins, 30 at a time), read with `docker stats`, never
  sized from an idle stack. A runtime that sizes its heap from the container, such as a JVM,
  then stays inside it. Change only the limit of a third-party service, never its startup
  flags: Keycloak's start script picks a garbage collector that clashes with `UseSerialGC`,
  and then Keycloak does not start. When the services come from the project's local stack,
  the limit goes into that stack (`create-project-local-stack`), not into the run.
- A stub or helper that starts a process stops any leftover of the same feature first, so an
  interrupted run never blocks the next one.
- Lanes share one build: build images or artifacts once, under a lock, and let every lane
  start from them.
- `launch.sh` and every helper that restarts the app, such as for a clock shift, wait until
  a real page answers, signed in where the app has sign-in, as "Waits and errors" says.
  They poll every half second and never run the whole doctor. `cleanup.sh` stops throwaway
  containers without a grace period (`docker compose down -t 1`).
- `doctor.sh` retries each probe a few times with a 30 s limit, so a loaded machine never
  stops a drive with a false failure.

At level `checks-only`, skip launching and recording: write no recipes, put the focused
checks in `PROJECT.md`, and go to step 6.

## 4. Record every feature

1. Run `bin/areas > .cache/areas.txt`. It groups the entry points into areas of about 1,000
   lines of source, one line per area: `<area>: <n> lines; entry points: <...>; files:
   <...>`, the files being the entry points' folders and the project files they import. One
   recorder records one area. Review the file:
   - Leave a line marked `split:` as it is. It is one file over the size, and its recorder
     takes longer.
   - Rename an area whose name does not say what the user calls the screen, such as one
     named `area2-<name>`.
   - Move a file the lines miss, such as a component two screens share, to the area that
     uses it most.
   - Make sure no area name equals another or starts with another followed by `-`: features
     are named `<area>-<goal>`, and `bin/verify uncovered <area>` finds an area's features
     by that prefix.

   Do not name features: each recorder lists every behavior of its area from the source and
   splits that list into features itself.

   Then write each area's expectation list:
   `bin/harvest '<its words>' <its test files> <its docs> > .cache/expect/<area>.txt`. It
   lists every test name in the test files, and the docs headings that match the words, with
   the lines under them. Give each area only its own test files. Then delete from the list
   the tests that belong to another area (from a test file two areas share) and tests of
   internals (pure functions, formatting, chart math). Every line left is a behavior one of
   the area's recipes must cite in an `# expects:` line, and `bin/verify uncovered <area>`
   lists each one none cites, so recorders never search for behavior and never skip it.
   When the docs have no heading that matches the area, the list holds only its tests; the
   recorder takes the rest from the source.
2. Write the first recipe yourself, for the simplest feature, following the Recipes section
   of the skill you copied, named `<area>-<goal>` after its area; that area's recorder
   keeps it. Run `bin/verify <feature>` until it passes. It becomes the example every
   recorder copies, so make it clean. Then drive the main create path by hand once: create
   the same record twice, and read it as a second tenant or user. Write what that shows
   about ids, uniqueness and shared data into `PROJECT.md`'s Gotchas before any recorder
   starts, so no recorder pays for the same trap. Also write the setup helpers several
   features need, such as signing in as each role, creating an account with a role,
   provisioning a subscription or workspace, adding a member, or reading the run's mail.
   Call each once the way a recipe calls it, after deleting its cached state (such as saved
   sign-ins), so its slow path runs too: a cache can hide a wrong argument until the first
   fresh drive.
3. Start recorders as the Recorders section of the copied `SKILL.md` says: one per area,
   every area at once, heaviest first.
4. Read only their result files. Fold their traps into `PROJECT.md`'s Gotchas.

## 5. Prove it

Run `bin/verify down` and `bin/verify all`, so every recipe runs once more on the production
build, from a fresh environment, with every other feature beside it. Send each failing
feature back to its recorder with its summary line. While they work, drive every feature
that passed once more on the same environment (`bin/verify <feature> ...`): a recipe that
fails the second time is not repeatable, so send it back too. When the recorders return,
run `bin/verify all` again, with no `--jobs` (the Done rule in Recipes says why). Send each
feature that fails there back to its recorder and repeat, until each passes there or fails
at a known failure.

The runner starts up to as many features at once as the machine has cores, each only when
the machine-wide queue has room. Write a `jobs` file only when the project needs a lower
limit, such as a service with few connections. When `# alone` features remain, write into
the skill's `lanes` file the most extra copies a drive may start: about their total time
divided by the longest parallel feature.

Then check the lifecycle once:

- `bin/verify lint` and `bin/verify uncovered`. Send each area with an uncovered entry
  point, action or expectation line back to its recorder; it lists nothing when done.
- Commit, change one file a feature touches, and check that
  `bin/verify affected --dry --base HEAD` selects it. Without `--base HEAD` on this branch,
  every new recipe counts as changed. Undo the change. In a companion, change a copy of the
  app checkout instead and point `APP_<NAME>` at it.
- Check that `bin/verify down` leaves nothing of the run outside `.cache/`: no process, port,
  container, browser session or file.

## 6. Instructions and hand-over

Write one `## Verification` section in the project's `AGENTS.md` (the companion's, in a
companion repo; create the file when there is none) from
[`references/agents-verification.md`](references/agents-verification.md), with `<app>` and
the focused check commands filled in. Integrate an existing verification section instead of
adding a second one; a section that points at a verify skill this run replaces is
rewritten. If there is no `CLAUDE.md`, create one holding only `@AGENTS.md`; if one exists
without that import, put the same section there too. Replace agent instructions for
launching the app by hand with a pointer to the skill; leave the README's instructions for
people. Report an older verification system instead of deleting it.

Merge `Bash(sudo:*)` into `permissions.deny` of `.claude/settings.json`, keeping the rest.
Commit following the repo's conventions. Report: the isolation level, how long recording and
`bin/verify all` took, one line per feature (pass, fail with its kind, or blocked with what
was tried), and product defects found.
