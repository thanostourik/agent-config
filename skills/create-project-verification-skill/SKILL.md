---
name: create-project-verification-skill
metadata:
  harness: "claude-code, codex, grok, cursor, gemini"
description: "Use for /create-project-verification-skill, its quick and add modes, or when asked to set up verification for a repo or to add a surface, such as a phone app, to a repo's verify skill."
disable-model-invocation: true
---

# Create a project verification skill

This skill gives a project a `verify-<app>` skill. That skill has an isolated environment,
one bash recipe per feature, and the shipped runner `bin/verify`, which drives the recipes
in parallel without an agent. Agents then drive the features a change touches before they
call work done. You write for the next agent, which reads the result in the middle of
another task, with no other context. Planners and recorders are subagents. A planner
splits one area of the app into features, and a recorder writes the recipes of up to 3 of
them.

## Modes

- `/create-project-verification-skill` (default): record every feature.
- `/create-project-verification-skill quick`: write the environment and one recipe, with no
  planners or recorders. Do steps 1 to 3, steps 4.1 and 4.4, the lifecycle checks of step 5, and
  step 6. The one recipe proves that the environment, sign-in, the driver helper and
  cleanup work, and agents copy it. The other recipes grow with the code: `verify affected`
  fails while a change adds a screen, route or action no recipe covers, `verify uncovered`
  lists the rest, and `/verify-<app> full` records them when the user asks.
- `/create-project-verification-skill add <surface>`: add a surface that the project's
  `verify-<app>` skill does not drive yet, such as a phone app beside the web app. It stays
  one skill. When the skill is behind this generator, run
  `/maintain-project-verification-skill` first. Then do what `quick` does, for that surface
  only and inside the existing skill: its driver helpers, its part of the environment
  (`launch.sh`, or `start-<part>.sh` when only its features need it), its screens and
  actions in `entrypoints.sh` and `actions.sh`, its facts in `PROJECT.md`, and one recipe.
  Prove that `bin/verify up` takes as long as before, that a feature of another surface
  still passes, and that `bin/verify down` leaves nothing. End the report with the number
  of entry points and actions `bin/verify uncovered` now lists, and say that
  `/verify-<app> full` records them.

A request with the same meaning picks the same mode. Do not ask which mode to use. Keep
your own context small: write the environment and the first recipe yourself, and leave the
other recipes to recorders.

When you need me to make a choice before you can continue, use your question tool if you
have one, or ask in your reply if you don't. If the question gets no answer, ask again in
your reply and wait. Do not answer it yourself.

If `.agents/skills/verify-*` already exists and the mode is not `add`, stop before writing
anything. Ask whether to replace it (delete and generate again), upgrade it with
`/maintain-project-verification-skill`, or add a surface to it.

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
  bin/brief           copied from <generator>/references/brief, unchanged (needs python3)
  bin/finish          copied from <generator>/references/finish, unchanged
  bin/detach          copied from <generator>/references/detach, unchanged
  bin/pw.sh bin/pw-close   copied from <generator>/references, unchanged, for a web UI; pw-version beside SKILL.md
  bin/maestro.sh      copied from <generator>/references, unchanged, for an Android app; maestro-version beside SKILL.md
  bin/launch.sh bin/cleanup.sh bin/doctor.sh bin/observe.sh bin/server-errors.sh
  bin/env.sh bin/after-feature.sh bin/start-<part>.sh   optional
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

- Ask which app repos the skill covers. Write `.agents/skills/verify-<app>/apps` with one
  line `<name> <repo>` per app. `<repo>` is the repo path the app's git remote ends in,
  such as `client-org/shop`, never a folder.
- `bin/verify` finds each app's main clone next to this repo's main clone, as "Another
  repo" in [`references/lifecycle.md`](references/lifecycle.md) says. It exports the
  clone's folder as `APP_<NAME>` (upper case, `-` as `_`). A value the caller set wins for
  that call, such as a worktree of the app.
- Recipes, `# touches:` lines and helpers name app files as `<name>/<path>` and reach them
  through `$APP_<NAME>`.

Nothing goes into an app checkout: no file, no dependency, no build output. Build from a
copy under `.cache/`, or send build output outside the checkout. Run git against a checkout
with `GIT_OPTIONAL_LOCKS=0`. Report a checkout that does not build; do not fix it.
Playwright, when needed, goes into the companion's own `package.json`.

## 1. Read the repo

Answer from the codebase. Ask only what you cannot observe.

- **Surfaces:** web UI, API, CLI or TUI, desktop, mobile, firmware, jobs. Every surface
  gets recipes. This skill ships drivers for a web UI (Playwright), an API (curl) and an
  Android app (Maestro). When a surface needs another driver, ask me whether to write one
  or leave the surface undriven, and write the answer into `PROJECT.md`'s Drivers section.
  Example: a repo with a web app and an Expo app in `apps/mobile` gets recipes for both.
- **Run:** how the app starts locally, its dependencies, ports, seed data and sign-in.
- **Harness:** existing end-to-end specs, sign-in or seed helpers, curl-able endpoints.
- **Entry points:** the files that define routes, screens, commands or endpoints, found
  with one grep. That grep becomes `bin/entrypoints.sh`.
- **Checks:** the focused test, lint and type-check commands.
- **Timers:** the waits a feature would sit through, such as expiries, schedules, retry
  delays and timeouts, and how the run can shorten each: a setting, an environment
  variable, a file the stack reads. When some can't be shortened from outside the app,
  such as a constant compiled into it, list them and ask me once which way to go:
  - a test-only setting in the product, which you add in this branch as a commit of its
    own;
  - a fake clock the run starts the app with, such as `libfaketime` when it is installed
    (a statically linked binary, such as most Go programs, ignores it);
  - leave the behaviors that wait on them undriven.

  Write the answer into `PROJECT.md`'s Timers section.
- **Other repos:** another repo the app needs at run time, such as a backend. Write into
  `PROJECT.md` the repo path its git remote ends in, such as `my-org/backend`. Never write
  a folder for it anywhere, not even in a git-ignored file: the run finds the clone each
  time, as "Another repo" in [`references/lifecycle.md`](references/lifecycle.md) says.

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
  - It starts every process that must outlive it, such as the app or a stub, through
    `bin/detach`, with input and output redirected:
    `bin/detach <command> < /dev/null > "$log" 2>&1 &`. So does every helper that restarts
    one. Agents run in systemd scopes, and a process started in one dies when that agent
    ends. A process that keeps the caller's output open keeps `bin/verify up` waiting.
  - It is idempotent. When the run's environment already exists, a second call restarts the
    app, plus any dependency whose files changed, and recreates nothing when nothing
    changed. A second `bin/verify up` then takes seconds. Example: a sign-in server in
    another repo's stack loads a theme built from this repo. After a theme edit, a second
    `up` restarts that server too, or no feature sees the edit.
- `cleanup.sh` removes only what the run created, after success, failure and interruption,
  and checks that none of it remains. It never checks resources that existed before. With
  no run recorded, it exits 0.
- `env.sh` (optional) exports the run's values that recipes and helpers need, such as base
  URLs, ports and keys. It reads them from the run's record. The runner sources it before
  each recipe.
- `after-feature.sh` (optional) runs after every recipe's `cleanup`, for example to close
  the feature's browser session. A finished feature then holds nothing until
  `bin/verify down`.
- `start-<part>.sh` (optional) starts a part of the environment that only some features use
  and that is slow or heavy to start, such as the phone emulator of a project that also has
  a web app. `launch.sh` does not start that part, so `bin/verify up` and a change to the
  web app never pay for the emulator.
  - Each feature that uses the part carries `# needs: <part>`. The runner calls the script
    before each of them, one call at a time, outside the feature's deadline.
  - The script starts what is missing and returns at once when the part is healthy. It is
    the part's health check too: `doctor.sh` does not check the part.
  - `cleanup.sh` stops the part like everything else the run created.
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
  - It lists every surface that has a driver. When two surfaces can have the same path,
    the entries of the one added later name it: `phone /search` beside `/search`. A surface
    it leaves out gets no recorder, and a new screen there passes `bin/verify affected`
    with no recipe.
  - `bin/verify uncovered` compares its output with the recipes' `# covers:` lines.
- `actions.sh` prints every user action, one per line, as `<name><TAB><file>`: each
  function a screen runs when the user acts (event handlers such as `handleDelete`, form
  submits). For a project without a UI, it prints each handler method behind an entry
  point. It searches the source, like `entrypoints.sh`, in every surface that script lists.
  - Name an inline handler (`onClick={() => remove(id)}`) after its element's label or test
    id, such as `Delete button`. Never use a line number: it changes whenever the file
    shifts.
  - A screen can get a handler from a hook or a parent
    (`const { start } = useDeviceControl()`). List it under the screen's file too. A search
    for `const handle...` alone misses it.
  - `bin/verify uncovered` lists each action that no recipe's `# expects:` line cites by
    its file and name. `bin/verify affected` lists those in changed files.
- Both scripts finish in a few seconds: `bin/verify` stops one after 30 s. Time
  `bin/verify uncovered` once before recorders start, because every recorder runs it.
  Matching a whole file with a pattern such as `(.|\n)*` can take minutes.

### Rules for every helper

- A helper also works when an agent calls it by hand, outside `bin/verify`. It sets
  `: "${VERIFY_SKILL:=$(cd "$(dirname "$0")/.." && pwd)}"` and gives the other `VERIFY_*`
  variables it reads a default.
- Under `pipefail`, it never pipes into `grep -q` or `head`: they stop reading at the first
  match, the writer dies of SIGPIPE, and the pipe fails even when it matched. A readiness
  wait built that way never succeeds. Capture the output first:
  `out=$(curl -s "$url"); grep -q ready <<< "$out"`.
- Its waits and error output follow the "Waits and errors" rules in the shipped `SKILL.md`.
  A helper that inserts rows directly follows the fixture rule in that file's Data section.
  `verify lint` checks only recipes, so check helpers yourself.
- A helper that runs a command inside a container passes environment overrides through
  (`bin/cli -e KEY=VALUE <command>`). A recipe can then point one command at its own
  schema, prefix or folder.

### Driver helpers

A driver helper that keeps state keeps it per `$VERIFY_SESSION`.

Each account signs in once per run, through the real sign-in screen. A feature starts from
fresh app state but keeps that login, and only the features about signing in go through the
sign-in screen themselves. Signing in on every feature took half of the cinova app's drive
time. An emulator or a fresh browser is a new device on every run, and a sign-in provider
can ask a new device for more than the password: Clerk emails a code to the account. Before
you build the environment, make sure the test account signs in with only what the run
holds. When it cannot, ask me for an account that can. When the sign-in provider has an API
for users and the checkout already holds its key, the environment creates the test account
itself and derives the password from that key. A new checkout then needs no credential of
its own for that account.

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

For an Android app:

- Copy `maestro.sh` to `bin/` unchanged, and write a Maestro version, such as `2.12.1`,
  into the skill's `maestro-version` file. The header of `maestro.sh` says how to call it
  and what it needs: Java 17 or newer, `socat` and unprivileged user namespaces.
  `doctor.sh` checks the three.
- `launch.sh` starts an ADB server of the run's own (`adb -P <free port> server nodaemon`)
  and a headless emulator from an AVD under `.cache/`. Never use the default ADB server: it
  also takes a phone someone connects. `env.sh` exports `ANDROID_ADB_SERVER_PORT`,
  `ANDROID_SERIAL` (`emulator-<port>`) and `MAESTRO_APP_ID`, which `adb` and `maestro.sh`
  read. The emulator's port is even, from 5554 to 5682, and its `adb` uses the next one.
  The emulator leaves a defunct `adb` child whose environment cannot be read, so the
  ownership check of `cleanup.sh` skips defunct processes.
- `launch.sh` builds the app and installs it once per run. It keeps the built APK under
  `.cache/`, named by a hash of the files the native build reads, so a later run only
  installs it: the wovies build took 4.5 minutes. An app with a development client, such as
  Expo, gets its debug build and its bundler (Metro) on a port of the run, which the
  emulator reaches through `adb reverse`. The client opens the bundle through its own URL
  scheme, `exp+<slug>://expo-development-client/?url=<bundler URL>`, not through the app's
  scheme. `expo prebuild` writes `android/` and edits `package.json`: build in a copy of the
  app, or put `package.json` back after the build.
- In a project with another driven surface, the phone side is a part of its own. What the
  points above give `launch.sh` and `doctor.sh` goes into `bin/start-phone.sh`, with the
  sign-in, and each phone feature carries `# needs: phone`. The run has one emulator, so each also
  carries the same `# shares: phone: <the state>` line and they take turns. The phone side
  of wovies takes 2 minutes to start.
- A recipe step puts its taps and checks into one flow, `maestro.sh flow <name> <<'EOF'`.
  Each `maestro.sh` call takes 5 to 7 s to start, and a check inside a flow about 0.2 s.
- A session helper starts each feature. It stops the app, deletes the app's own data but
  not its login, and starts the app. React Native apps keep AsyncStorage in `databases`,
  MMKV in `files/mmkv`, and caches in `cache` and `app_webview`. `react-native-keychain` and
  `expo-secure-store` keep the login elsewhere in `files` and in `shared_prefs`: check with
  `adb shell run-as <app> find .` after one sign-in. Never use `pm clear` for this: it also
  deletes the app's Keystore keys, so the kept login can no longer be read. `pm clear` also
  forgot the permission prompts a feature refused, and Android shows another button on the
  second refusal, so the helper forgets them itself:
  `pm clear-permission-flags <app> <permission> user-set user-fixed`. When the app shows its
  sign-in screen anyway, the helper signs in through it. A development client shows the
  intro of its menu on its first start (Continue, then Close), and the helper gets past it.
  Its `signed-out` variant runs `pm clear`, for the features about signing in.

### `PROJECT.md`

Write `PROJECT.md`, about 10 KB, with these sections:

- **Drivers:** the tools that drive the app, such as `Playwright CLI and curl` or `Maestro`,
  and why.
- **Isolation:** `Isolation level: <level>`, one line on why, what the run owns and its
  markers, and the success paths the isolation cannot reach (such as a real payment that a
  stub replaces).
- **Environment:** what `launch.sh`, `cleanup.sh` and `doctor.sh` do, how long a first
  and a second `bin/verify up` take, and which dependencies a second `up` restarts, with
  the files whose change triggers each restart.
- **Sign-in and data:** the test accounts and baseline data a recipe can count on, each
  checked with one command against the running environment.
- **Timers:** each timer the features wait on, and how the run shortens it, or that I chose
  to leave it undriven (step 1).
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
  - State set in one `run-code` call, such as a route or a variable, is gone in the next.
    Keep it on `window` inside the page.
  - `page.clock.pauseAt` left active when a `run-code` call ends makes every later call
    hang. Pause, act and resume inside one call
    (`try { ... } finally { await page.clock.resume() }`), or keep the clock running and
    move it with `page.clock.runFor`.
  - Under a paused fake clock `waitForFunction` hangs, because it polls on animation
    frames: pass `{ polling: 100 }`.
  - `verify lint` refuses `waitForTimeout`. To prove that an action changed nothing, wait
    for two animation frames or one round trip to the server, then check.
  - Text that a list repeats matches twice, and `getByText` then fails: scope the locator
    to its container, or pass `exact: true`.
  - `pw.sh snapshot --filename` needs an absolute path.
  - `pw.sh` closes a session opened by hand that sat idle for 120 s: run `pw.sh open` again
    before the next call.

  For Maestro:
  - A field the keyboard covers is not found: `hideKeyboard` after `inputText`.
  - `tapOn` waits for the screen to settle, 2 to 3 s on an emulator. `assertVisible` and
    `extendedWaitUntil` return as soon as the element is there.
  - A `when:` condition is checked once, not waited for. To get past screens that may or may
    not appear, such as a browser's first-run screens, loop with
    `repeat: { while: { notVisible: ... } }`.
  - `takeScreenshot: <name>` writes `$VERIFY_DIR/<name>.png`. A path outside that folder
    fails.

### Bring it up

1. Copy the shipped files as the tree above shows, and write the Claude stub and
   `.gitignore`.
2. Write `bin/entrypoints.sh` and `bin/actions.sh` first (or delegate both to a parallel
   `verify-recorder` / fast subagent while you write `launch.sh`, `cleanup.sh`, `doctor.sh`,
   `observe.sh`, `server-errors.sh`, driver helpers and `PROJECT.md`). As soon as both
   listing scripts work, do steps 4.1 to 4.3 (`bin/areas`, `bin/brief --harvest`,
   `bin/brief --plan`, and launch all planners) right away: planners read only source, so
   they finish in parallel while you write the rest of the environment and build the stack.
3. Run `VERIFY_APP=build bin/verify up` in the background while finishing any remaining setup
   work before the first recipe.
4. Run `bin/verify up` again, which keeps the production build. Time both calls.

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
  `.cache/run/`, so lanes can run side by side. That includes the ports the app picks for
  itself while it runs, such as a host port per container. When the app picks them from a
  fixed range and has no setting for it, two copies clash: the skill then gets no lanes.
- Shorten every timer the features wait on, in the run's own configuration: job intervals,
  retry delays, grace periods, expiries, polling.
  - When the project's stack fixes the environment and offers no way to override it, add
    one to the stack as part of the repo, such as a compose override file it reads. A
    timer inside the app's own code follows my answer from step 1.
  - Write each override and the recipes that rely on it into `PROJECT.md`.
  - Before shortening a job for all features, check which recipes set up the state that job
    consumes.
- Keep each copy small so lanes fit in memory. Cap worker counts and heap sizes: a JVM
  without `-Xmx` takes a quarter of the machine. Start the project's own JVM apps with
  `-XX:TieredStopAtLevel=1 -XX:+UseSerialGC`, which shortens startup.
- Give every service of the run a memory limit (`mem_limit` for a container), third-party
  ones included. Step 4.4 sizes it, once the example recipe passes.
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
   folders and the project files they import. One planner splits one area into features.
   Review the file:
   - Split a line marked `split:`, and any area much larger than the rest, by user goal
     into several areas. Each new line keeps the shared files and lists only its own entry
     points. All planners run at once, so the largest area sets when planning ends.
   - Rename an area whose name does not say what the user calls the screen, such as one
     named `area2-<name>`.
   - Move a file the lines miss, such as a component two screens share, to the area that
     uses it most.
   - Make sure no area name equals another or starts with another followed by `-`. Features
     are named `<area>-<goal>`, and `bin/verify uncovered <area>` finds an area's features
     by that prefix.

   Do not name features. Each planner lists every behavior of its area from the source and
   splits that list into features itself.
2. Run `bin/brief --harvest` to generate each area's expectation list in one call (see the
   Expectation lists section of the copied `FULL.md`), then `bin/brief --plan`.
3. Start the planners now (if not already started in step 3), as the Recorders section of
   the copied `FULL.md` says: one per area, every area at once. They read only source, so
   they work while the environment builds and while you do the next step. Name the first
   recipe of the next step `<area>-<goal>` before you start them, and tell its area's
   planner.
4. Write the first recipe yourself, for the simplest feature. Follow the Recipes section of
   the copied `SKILL.md`. The recorder of its group completes it. Run `bin/verify <feature>`
   until it passes. Every recorder copies this recipe as its example, so make it clean.
   Then:
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
5. Run `bin/verify up --lanes 1`, or `bin/verify up` when two copies clash on ports
   (step 3). A feature marked `# alone` waits until its copy is free
   of other features, so on a single copy every other drive stops meanwhile. With the extra
   copy, every drive runs its `# alone` features there instead. Then, when every planner
   has returned, start the recorders as the Recorders section of the copied `FULL.md`
   says: one per group, every group at once, the heaviest areas first.
6. Read only their result files, as the Recorders section of `FULL.md` says.

## 5. Prove it

Keep the recording environment running (it is already on `VERIFY_APP=build`, and every
feature already ran on it during recording). Run steps 2 to 4 of Full in the copied
`FULL.md` directly on that hot environment: the first `verify all` immediately tests full
load and repeatability without a cold restart wait. Send failing features, uncovered lines
or invalid not-driven reasons to fresh slim repair recorders (`bin/brief --repair`), at
most 3 features each, and repeat `verify all --failed` until clean.

Then run `bin/verify down` once and run step 5's final `verify all` (with no `--jobs`),
which starts a fresh production environment from scratch and proves every feature passes on
a clean boot under full load.

The runner starts up to as many features at once as the machine has cores, each only when
the machine-wide queue has room. Write a `jobs` file only when the project needs a lower
limit, such as a service with few connections. When `# alone` features remain and two
copies do not clash on ports, write into the skill's `lanes` file the most extra copies a
drive may start: about their total time divided by the longest parallel feature.

Then check the lifecycle once:

- Run `bin/verify lint`. Fix every `# expects:` line it lists as citing code the checkouts
  do not have: `bin/verify affected` can never select a feature through such a line.
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
Commit following the repo's conventions.

Report what I need to know, in plain words:

- the isolation level;
- how long setup, recording and the final `bin/verify all` took, from times you took with
  `date` when each began and ended, never estimated;
- one line per area: features passing, failing with the failure kind, or blocked with what
  was tried;
- each product defect, and each piece of dead code the recorders found;
- the decisions left to me;
- the behaviors no step drives, grouped by reason, each with what would make it drivable.

Fixes to the skill's own scripts while you built it are part of building it: leave them
out.
