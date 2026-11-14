---
name: create-project-verification-skill
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Use for /create-project-verification-skill, /create-project-verification-skill quick, or when asked to set up verification for a repo."
disable-model-invocation: true
---

# Create a project verification skill

This skill gives a project a `verify-<app>` skill. That skill has an isolated environment,
one bash recipe per feature, and the shipped runner `bin/verify`, which drives the recipes
in parallel without an agent. Agents then drive the features a change touches before they
call work done. You write for the next agent, which reads the result in the middle of
another task, with no other context. Recorders are subagents. Each one writes the recipes
of one area of the app.

## Modes

- `/create-project-verification-skill` (default): record every feature.
- `/create-project-verification-skill quick`: write the environment and one recipe, with no
  recorders. Do steps 1 to 3, steps 4.1 and 4.3, the lifecycle checks of step 5, and
  step 6. The one recipe proves that the environment, sign-in, the browser helper and
  cleanup work, and agents copy it. The other recipes grow with the code: `verify affected`
  fails while a change adds a screen, route or action no recipe covers, `verify uncovered`
  lists the rest, and `/verify-<app> full` records them when the user asks.

A request with the same meaning picks the same mode. Do not ask which mode to use. Keep
your own context small: write the environment and the first recipe yourself, and leave the
other recipes to recorders.

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
  FULL.md             <generator>/references/full.md, with <app> filled in
  RECORDERS.md        copied from <generator>/references/recorders.md, unchanged
  PROJECT.md          this project's facts (step 3)
  bin/verify          copied from <generator>/references/verify, unchanged
  bin/lib.sh          copied from <generator>/references/lib.sh, unchanged
  bin/harvest         copied from <generator>/references/harvest, unchanged
  bin/areas           copied from <generator>/references/areas, unchanged (needs python3)
  bin/reach           copied from <generator>/references/reach, unchanged (needs python3)
  bin/pw.sh bin/pw-close   copied from <generator>/references, unchanged, for a web UI; pw-version beside SKILL.md
  bin/launch.sh bin/cleanup.sh bin/doctor.sh bin/observe.sh bin/server-errors.sh
  bin/env.sh bin/after-feature.sh   optional
  bin/entrypoints.sh bin/actions.sh
  bin/<driver helpers>
  features/<feature>.sh
  .gitignore          holds .cache/
  apps                companion repo only
.claude/skills/verify-<app>/SKILL.md   stub from <generator>/references/claude-stub.md
.claude/settings.json                  "Bash(sudo:*)" merged into permissions.deny
```

`<app>` is a short lowercase name. Codex, Cursor, Grok and OpenCode read `.agents/skills/`.
Claude Code reads only `.claude/skills/`, so the stub exists for it. Never use symlinks.

`SKILL.md`, `FULL.md` and the files marked `unchanged` are the shipped files. An upgrade replaces
them, so never edit them for the project. Everything project-specific goes into
`PROJECT.md`, the other `bin/` helpers and `features/`.

## Companion repo

Some projects must not show that agents work on them. Their skill lives in a companion
repo: a separate git repo next to the app checkouts that holds only agent files.

Run one `git ls-files` here. When it lists no app source, this is a companion:

- Ask for the path of each app checkout. Write `.agents/skills/verify-<app>/apps` with one
  line `<name> <path>` per app, the path relative to this repo's root.
- `bin/verify` exports each path as `APP_<NAME>` (upper case, `-` as `_`). A value the
  caller set wins.
- Recipes, `# touches:` lines and helpers name app files as `<name>/<path>` and reach them
  through `$APP_<NAME>`.

Nothing goes into an app checkout: no file, no dependency, no build output. Build from a
copy under `.cache/`, or send build output outside the checkout. Run git against a checkout
with `GIT_OPTIONAL_LOCKS=0`. Report a checkout that does not build; do not fix it.
Playwright, when needed, goes into the companion's own `package.json`.

## 1. Read the repo

Answer from the codebase. Ask only what you cannot observe.

- **Surfaces:** web UI, API, CLI or TUI, desktop, mobile, firmware, jobs.
- **Run:** how the app starts locally, its dependencies, ports, seed data and sign-in.
- **Harness:** existing end-to-end specs, sign-in or seed helpers, curl-able endpoints.
- **Entry points:** the files that define routes, screens, commands or endpoints, found
  with one grep. That grep becomes `bin/entrypoints.sh`.
- **Checks:** the focused test, lint and type-check commands.
- **Sibling repos:** another repo the app needs at run time, such as a backend. Use the path
  its docs name, else `../<name>`, and write it into `PROJECT.md`.

If the app does not build or start as it is, fix that or report it before going on.

## 2. Isolation

Choose the isolation level once, following
[`references/lifecycle.md`](references/lifecycle.md): `full` (default), `shared` or
`checks-only`. That file also says which ports a run may use and how to use
`local-stack/stack`. Ask the user only when `full` is not possible. Recipes read every URL
and port from `env.sh`, never `localhost:<default>`.

## 3. Write the environment and `PROJECT.md`

At level `checks-only` the app cannot run, so there is no environment to write. Do only
this, then go to step 6: write `PROJECT.md` with the focused checks, copy the shipped files
as the tree above shows, and write the Claude stub and `.gitignore`. Write no environment
scripts and no recipes, and launch nothing.

At the other levels, write the scripts below into `bin/` and make each one executable.

### Environment scripts

- `launch.sh` creates and starts the run's environment. It registers each resource as it
  creates it, and waits until the environment is ready, with a deadline.
  - `$VERIFY_RUN_ID` names the run and stays the same until `bin/verify down`.
  - With `VERIFY_APP=dev` it runs the app with the developers' own dev command, such as
    `next dev` or `./mvnw spring-boot:run`, as a process the run records. A code change
    then needs no image build.
  - With `VERIFY_APP=build` it runs the production build.
  - A run uses `dev` unless its first `bin/verify up` sets `VERIFY_APP=build`. `verify all`
    and lanes always use `build`.
  - It is idempotent. When the run's environment already exists, it restarts the app, so a
    second `bin/verify up` takes seconds.
- `cleanup.sh` removes only what the run created, after success, failure and interruption,
  and checks that none of it remains. It never checks resources that existed before. With
  no run recorded, it exits 0.
- `env.sh` (optional) exports the run's values that recipes and helpers need, such as base
  URLs, ports and keys. It reads them from the run's record. The runner sources it before
  each recipe.
- `after-feature.sh` (optional) runs after every recipe's `cleanup`, for example to close
  the feature's browser session. A finished feature then holds nothing until
  `bin/verify down`.
- `doctor.sh` is one fast, read-only check that the environment belongs to this run and is
  healthy: processes up, right checkout, ports owned, sign-in works. It never treats a
  process outside the run's record as the run's.
- `observe.sh <path>` saves the app's current state for a failed step: the snapshot or
  screenshot of the feature's browser session (`$VERIFY_SESSION`), the last HTTP response,
  or the last command output.
- `server-errors.sh <epoch seconds>`, for an app with a server, prints the errors the
  server logged since that time, each with its stack trace. It prints nothing when there
  are none.
  - It reads the errors where this stack writes them, such as `docker logs --since` for a
    container, the app server's log file, or the output of the dev process the run
    records. It reads the copy that `$VERIFY_RUN_ID` names.
  - The summary line shows only the first line, so start each error with the request and
    the exception.
  - When a step fails, `lib.sh` calls it with the time the step began and saves its output
    as evidence. A UI timeout caused by a server error then explains itself.
  - A failed `bin/verify up` calls it too, with the time the launch began. So it must also
    work on a run whose app never became ready, such as one that stopped at a migration.
  - Check it once by causing a server error, such as a request the app answers with
    HTTP 500.

### Scripts that list what to cover

- `entrypoints.sh` prints every entry point, one per line, as `<entry point><TAB><file>`:
  a route with its method (`POST /api/notes`), a screen's path, a command (`todo add`), a
  job or message handler.
  - It searches the source, such as route annotations or a router file, so it finds new
    entry points by itself.
  - Some frameworks build entry points at run time, from configuration or the database,
    where no source search finds them. When the project's framework is in
    [`references/discovery.md`](references/discovery.md), list them the way it says.
  - List only what a user or client calls: not update or deploy hooks, migrations, compose
    services or schemas.
  - `bin/verify uncovered` compares its output with the recipes' `# covers:` lines.
- `actions.sh` prints every user action, one per line, as `<name><TAB><file>`: each
  function a screen runs when the user acts (event handlers such as `handleDelete`, form
  submits). For a project without a UI, it prints each handler method behind an entry
  point. It searches the source, like `entrypoints.sh`.
  - Name an inline handler (`onClick={() => remove(id)}`) after its element's label or test
    id, such as `Delete button`. Never use a line number: it changes whenever the file
    shifts.
  - A screen can get a handler from a hook or a parent
    (`const { start } = useDeviceControl()`). List it under the screen's file too. A search
    for `const handle...` alone misses it.
  - `bin/verify uncovered` lists each action that no recipe's `# expects:` line cites by
    its file and name. `bin/verify affected` lists those in changed files.

### Rules for every helper

- A helper also works when an agent calls it by hand, outside `bin/verify`. It sets
  `: "${VERIFY_SKILL:=$(cd "$(dirname "$0")/.." && pwd)}"` and gives the other `VERIFY_*`
  variables it reads a default.
- Its waits and error output follow the "Waits and errors" rules in the shipped `SKILL.md`.
  A helper that inserts rows directly follows the fixture rule in that file's Data section.
  `verify lint` checks only recipes, so check helpers yourself.
- A helper that runs a command inside a container passes environment overrides through
  (`bin/cli -e KEY=VALUE <command>`). A recipe can then point one command at its own
  schema, prefix or folder.

### Driver helpers

A driver helper that keeps state keeps it per `$VERIFY_SESSION`.

For a web UI without its own harness:

- Copy `pw.sh` and `pw-close` to `bin/` unchanged. The header of `pw.sh` says how to call
  it.
- Write into the skill's `pw-version` file a Playwright version whose browser build is
  installed (`ls ~/.cache/ms-playwright`). `pw.sh` installs that version under `.cache/` on
  first use.
- `after-feature.sh` runs `bin/pw-close feature`, and `cleanup.sh` runs `bin/pw-close run`.
  No recorder calls `pw-close`, because other drives share the run's browser.

Then write:

- A sign-in helper. It saves each account's storage state once per run and loads it in one
  call. It signs each account into a browser session of its own: a second account in the
  same session is signed in as the first, through the sign-in provider's cookie.
- Account helpers. Creating or deleting an account also removes that account's cached state
  and token.
- Every cached file (token, storage state) through a temporary file of its own (`mktemp` in
  the same folder) and `mv`. Features sign in at the same time, and a shared temporary name
  makes one feature's `mv` fail.

For an API, an `api` helper wraps `curl` with the base URL, auth and `--max-time`, and
saves the last response for `observe.sh`.

### `PROJECT.md`

Write `PROJECT.md`, about 10 KB, with these sections:

- **Drivers:** the tools that drive the app, such as `Playwright CLI and curl`, and why.
- **Isolation:** `Isolation level: <level>`, one line on why, what the run owns and its
  markers, and the success paths the isolation cannot reach (such as a real payment that a
  stub replaces).
- **Environment:** what `launch.sh`, `cleanup.sh` and `doctor.sh` do, and how long a first
  and a second `bin/verify up` take.
- **Sign-in and data:** the test accounts and baseline data a recipe can count on, each
  checked with one command against the running environment.
- **Stubs:** for each stub or fake service in the run, what it returns and stores and what
  it cannot do (such as an ML stub that stores nothing, or a collector that returns no
  data), each checked with one call. Recorders read this instead of finding it out in
  failed runs.
- **Helpers:** one line per helper with one real call as a recipe writes it, what it checks
  or returns, and its deadline when it waits.
- **Focused checks:** the test, lint and type-check commands.
- **Gotchas:** traps that hold for several features, one line each with the fix. A trap of
  one feature goes in that recipe's header instead. Start with the driver's traps. For the
  Playwright CLI:
  - After a click that navigates, wait for the new URL or state before the next check.
  - After `goto` or `reload`, wait for an element only the client renders before the first
    click. A click before the page is interactive does nothing.
  - A `confirm()` dialog blocks every command until it is handled.
  - A role name matches as a substring unless `exact: true`.
  - The `run-code` function runs in a bare sandbox. Node and browser globals such as `URL`,
    `require` and `console` are not there, so parse URLs and log inside `page.evaluate`, or
    return the value.

### Bring it up

1. Copy the shipped files as the tree above shows, and write the Claude stub and
   `.gitignore`.
2. Run `VERIFY_APP=build bin/verify up` in the background. While it builds, do the parts of
   step 4 that come before the first recipe.
3. Run `bin/verify up` again, which keeps the production build. Time both calls.

Generation uses the production build. A dev server holds far more memory, and with many
features at once it loses clicks that land before a page is ready. The first `up` also
measures how much memory and time one copy of the environment takes. The runner needs both
to decide on lanes (extra copies of the environment for `# alone` features).

For a CLI or a library there is no process to restart. `launch.sh` prepares the run's data
folder and builds once, and `doctor.sh` checks that the folder is the run's and the build is
current.

### Build the environment for speed

Every recipe waits on the environment in every run.

- Derive every per-run file name and port from `$VERIFY_RUN_ID`, never a fixed path such as
  `.cache/run/`, so lanes can run side by side.
- Shorten every timer the features wait on, in the run's own configuration: job intervals,
  retry delays, grace periods, expiries, polling.
  - When the project's stack fixes the environment and offers no way to override it, add
    one to the stack as part of the repo, such as a compose override file it reads. Or note
    the gap and start the job once per recipe.
  - Write each override and the recipes that rely on it into `PROJECT.md`.
  - Before shortening a job for all features, check which recipes set up the state that job
    consumes.
- Keep each copy small so lanes fit in memory. Cap worker counts and heap sizes: a JVM
  without `-Xmx` takes a quarter of the machine. Start the project's own JVM apps with
  `-XX:TieredStopAtLevel=1 -XX:+UseSerialGC`, which shortens startup.
- Give every service of the run a memory limit (`mem_limit` for a container), third-party
  ones included. Step 4.3 sizes it, once the example recipe passes.
  - A runtime that sizes its heap from the container, such as a JVM, then stays inside it.
  - Change only the limit of a third-party service, never its startup flags. Keycloak's
    start script picks a garbage collector that clashes with `UseSerialGC`, and then
    Keycloak does not start.
  - When the services come from the project's local stack, the limit goes into that stack
    (`create-project-local-stack`), not into the run.
- A stub or helper that starts a process first stops any leftover of the same feature, so
  an interrupted run never blocks the next one.
- Lanes share one build. Build images or artifacts once, under a lock, and let every lane
  start from them. Only when the build bakes ports into an image (such as `NEXT_PUBLIC_*`
  URLs) does each lane build its own.
- `launch.sh` and every helper that restarts the app, such as for a clock shift, wait until
  a real page answers, signed in where the app has sign-in, as "Waits and errors" says.
  They poll every half second and never run the whole doctor.
- `cleanup.sh` stops throwaway containers without a grace period
  (`docker compose down -t 1`).
- `doctor.sh` retries each probe a few times with a 30 s limit, so a loaded machine never
  stops a drive with a false failure.

## 4. Record every feature

1. Run `bin/areas > .cache/areas.txt`. It groups the entry points into areas of about 1,000
   lines of source, one line per area:
   `<area>: <n> lines; entry points: <...>; files: <...>`. The files are the entry points'
   folders and the project files they import. One recorder records one area. Review the
   file:
   - Leave a line marked `split:` as it is. It is one file over the size, and its recorder
     takes longer.
   - Rename an area whose name does not say what the user calls the screen, such as one
     named `area2-<name>`.
   - Move a file the lines miss, such as a component two screens share, to the area that
     uses it most.
   - Make sure no area name equals another or starts with another followed by `-`. Features
     are named `<area>-<goal>`, and `bin/verify uncovered <area>` finds an area's features
     by that prefix.

   Do not name features. Each recorder lists every behavior of its area from the source and
   splits that list into features itself.
2. Write each area's expectation list, as the Expectation lists section of the copied
   `FULL.md` says.
3. Write the first recipe yourself, for the simplest feature. Follow the Recipes section of
   the copied `SKILL.md`, and name the recipe `<area>-<goal>` after its area. That area's
   recorder keeps it. Run `bin/verify <feature>` until it passes. Every recorder copies
   this recipe as its example, so make it clean. Then:
   - Drive the main create path by hand once: create the same record twice, and read it as
     a second tenant or user. Write what that shows about ids, uniqueness and shared data
     into `PROJECT.md`'s Gotchas before any recorder starts, so no recorder hits the same
     trap.
   - Write the setup helpers several features need, such as signing in as each role,
     creating an account with a role, provisioning a subscription or workspace, adding a
     member, or reading the run's mail.
   - Write the fixture helper for each row several features insert directly, such as a
     user (the Data section's rule for such rows), before any recorder writes that insert
     into a recipe.
   - Call each helper once the way a recipe calls it, after deleting its cached state (such
     as saved sign-ins), so its slow path runs too. A cache can hide a wrong argument until
     the first fresh drive.
   - Size each service's memory limit: about one and a half times what the service uses
     after a busy run. A busy run is the example recipe's flow plus a few hundred sign-ins,
     30 at a time. Read the use with `docker stats`. Never size the limit from an idle
     stack.
4. Run `bin/verify up --lanes 1`. A feature marked `# alone` waits until its copy is free
   of other features, so on a single copy every other drive stops meanwhile. With the extra
   copy, every drive runs its `# alone` features there instead. Then start recorders as the
   Recorders section of the copied `FULL.md` says: one per area, every area at once,
   heaviest first.
5. Read only their result files. Add their traps to `PROJECT.md`'s Gotchas.

## 5. Prove it

Run `bin/verify down`. Then do steps 2 to 5 of Full in the copied `FULL.md`. Its first
`verify all` starts a fresh environment on the production build, so every recipe runs once
more with every other feature beside it. Send a failing feature, an uncovered line or a
not-driven reason that does not hold back to the recorder that recorded its area, instead
of starting a new one. In the final `verify all`, every feature runs on an environment
where it already ran, which also proves each recipe repeats.

The runner starts up to as many features at once as the machine has cores, each only when
the machine-wide queue has room. Write a `jobs` file only when the project needs a lower
limit, such as a service with few connections. When `# alone` features remain, write into
the skill's `lanes` file the most extra copies a drive may start: about their total time
divided by the longest parallel feature.

Then check the lifecycle once:

- Run `bin/verify lint`.
- Commit, change one line in a function that an `# expects:` line cites, and check that
  `bin/verify affected --dry --base HEAD` lists that feature under "Check the edited
  code". Without `--base HEAD` on this branch, every new recipe counts as changed. Undo
  the change. In a companion, change a copy of the app checkout instead and point
  `APP_<NAME>` at it.
- Check that `bin/verify down` leaves nothing of the run outside `.cache/`: no process,
  port, container, browser session or file.

## 6. Instructions and hand-over

Write one `## Verification` section in the project's `AGENTS.md` from
[`references/agents-verification.md`](references/agents-verification.md), with `<app>` and
the focused check commands filled in. In a companion repo it goes in the companion's
`AGENTS.md`. Create the file when there is none.

- Integrate an existing verification section instead of adding a second one. Rewrite a
  section that points at a verify skill this run replaces.
- If there is no `CLAUDE.md`, create one holding only `@AGENTS.md`. If one exists without
  that import, put the same section there too.
- Replace agent instructions for launching the app by hand with a pointer to the skill.
  Leave the README's instructions for people.
- Report an older verification system instead of deleting it.

Merge `Bash(sudo:*)` into `permissions.deny` of `.claude/settings.json`, keeping the rest.
Commit following the repo's conventions. Report: the isolation level, how long recording and
`bin/verify all` took, one line per feature (pass, fail with its kind, or blocked with what
was tried), and product defects found.
