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
  bin/areas           copied from <generator>/references/areas, unchanged (needs python3)
  bin/pw.sh bin/pw-close   copied from <generator>/references, unchanged, for a web UI; pw-version beside SKILL.md
  bin/launch.sh bin/cleanup.sh bin/doctor.sh bin/observe.sh bin/entrypoints.sh bin/actions.sh
  bin/<driver helpers>
  features/<feature>.sh
  .gitignore          holds .cache/
  apps                companion repo only
.claude/skills/verify-<app>/SKILL.md   stub from <generator>/references/claude-stub.md
.claude/settings.json                  "Bash(sudo:*)" merged into permissions.deny
```

`<app>` is a short lowercase name. Codex, Cursor, Grok and OpenCode read `.agents/skills/`;
Claude Code reads only `.claude/skills/`, so the stub exists for it. Never use symlinks.
Never edit `SKILL.md`, `bin/verify`, `bin/lib.sh`, `bin/pw.sh` or `bin/pw-close` for the project: an upgrade replaces them.
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
`checks-only`. A run never listens on the project's default ports (such as 3000, 5432,
8080), even when they are free; check the stack's port choice before the first `up`: the developer's own tools connect there and would write into the run. Take ports
the run picks, or the stack's spare-port option; when the stack has none, add one to it as
part of the repo. Recipes read every URL and port from `env.sh`, never `localhost:<default>`.
A project with `local-stack/stack` uses it: `launch.sh` runs
`local-stack/stack up --app --stubs --name "$VERIFY_RUN_ID"`, plus the `--mode` options the
features need, and `cleanup.sh` runs `local-stack/stack destroy --name "$VERIFY_RUN_ID"` and
removes both registry files, `<stack>-<run id>.json` and `<stack>-<run id>.lock` under
`~/.local/state/local-stacks/`, of that stack and of every stack it started for a
dependency, then checks that neither remains. Ask the user only when `full` is not
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
  router file, so it finds new entry points by itself. When the project's framework is in
  [`references/discovery.md`](references/discovery.md), list them the way it says: some
  frameworks build entry points at run time, from configuration or the database, where no
  source search finds them. List only what a user or client calls: not update or deploy
  hooks, migrations, compose services or schemas. In trials 236 of a Drupal site's 402
  lines were update hooks. `bin/verify uncovered` compares it with the recipes'
  `# covers:` lines.
- `actions.sh`: prints every user action, one per line, as `<name><TAB><file>`: each
  function a screen runs when the user acts (event handlers such as `handleDelete`, form
  submits), or for a project without a UI each handler method behind an entry point. It is
  a search over the source, like `entrypoints.sh`. An inline handler
  (`onClick={() => remove(id)}`) is named after its element's label or test id, such as
  `Delete button`, never a line number: in trials line-numbered names changed whenever the
  file shifted. A handler the screen gets from a hook or a parent
  (`const { start } = useDeviceControl()`) is listed under the screen's file too: in trials
  a search for `const handle...` missed a screen's Start, Pause and Stop buttons. `bin/verify uncovered` lists each action
  that no recipe's `# expects:` line cites by its file and name, and `bin/verify affected`
  lists those in changed files: in trials nothing listed a screen's Delete, no recorder
  wrote a step for it, and a bug planted there went uncaught in two generations.
- Every helper also works when an agent calls it by hand, outside `bin/verify`: it sets
  `: "${VERIFY_SKILL:=$(cd "$(dirname "$0")/.." && pwd)}"` and defaults the other `VERIFY_*`
  variables it reads.
- A helper that runs a command inside a container passes environment overrides through
  (`bin/cli -e KEY=VALUE <command>`), so a recipe can point one command at its own schema,
  prefix or folder.
- Driver helpers, keyed on `$VERIFY_SESSION` when they keep state. For a web UI without its
  own harness, copy `<generator>/references/pw.sh` and `<generator>/references/pw-close` to
  `bin/` unchanged, and write into the skill's `pw-version` file a Playwright version whose
  browser build is installed (`ls ~/.cache/ms-playwright`); `pw.sh` installs it under
  `.cache/` on first use. `pw.sh` runs the Playwright CLI in the session
  `$VERIFY_RUN_ID-$VERIFY_SESSION`, attaches every session as a context of its own to one
  browser per run, waits in the machine-wide queue before a session opened by hand, closes
  hand sessions idle for 2 minutes, logs each call's duration in `$VERIFY_DIR/pw-calls.log`,
  and ends every `run-code` with a hidden same-origin frame load, because the CLI otherwise
  waits up to 5 s for requests Chrome never reports finished. Its header says how to call
  it. `after-feature.sh` runs `bin/pw-close feature` and `cleanup.sh` runs
  `bin/pw-close run`; no recorder calls it, because other drives share the run's browser.
  In trials writing this helper by hand took minutes of every generation, and one
  generation's version left two browser servers running after cleanup. Then write:
  - a sign-in helper that saves each account's storage state once per run and loads it in
    one call, signing each account into a browser session of its own: a second account in
    the same session is signed in as the first through the sign-in provider's cookie;
  - creating or deleting an account also removes that account's cached state and token;
  - a cached file (token, storage state) written through a temporary file of its own
    (`mktemp` in the same folder) and `mv`: features sign in at once, and a shared
    temporary name makes one feature's `mv` fail.
  For an API, an `api` helper wraps `curl` with the base URL, auth, `--max-time`, and saves
  the last response for `observe.sh`.

Then write `PROJECT.md`, about 10 KB, with these sections (a trap of one feature goes in
that recipe's header, not here):

- **Drivers:** the driver phrase, such as `Playwright CLI and curl`, and why.
- **Isolation:** `Isolation level: <level>`, one line on why, what the run owns and its
  markers, and the success paths isolation makes unreachable.
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
  one feature stays in that recipe's header. Start with the driver's.
  Playwright CLI: act through `run-code` only. The CLI's `click` and `press` wait 6 to 10 s
  for the network to go quiet and do not wait for the element; a `run-code` click takes
  about a second. After a click that navigates, wait for the new URL or state before the
  next check. After `goto` or `reload`, wait for an element only the client renders before
  the first click: a click before the page is interactive does nothing. A `confirm()`
  dialog blocks every command until it is handled; a role name
  matches as a substring unless `exact: true`. The `run-code` function runs in a bare
  sandbox: Node and browser globals such as `URL`, `require` and `console` are not there,
  so parse URLs and log inside `page.evaluate`, or return the value.

Copy `references/verify-skill.md` to `SKILL.md` with `<app>` filled in, `references/verify`,
`references/lib.sh`, `references/harvest` and `references/areas` to `bin/` (with `pw.sh` and `pw-close` for a web UI), and write the Claude stub and `.gitignore`. Then run
`bin/verify up` in the background and do step 4.1 while it builds; then run
`bin/verify up` again and time both. The first `up` records how much memory and time one
copy of the environment takes, which the runner needs to decide on lanes later. Before
recorders start, run `bin/verify up --lanes 1`, so every drive runs its `# alone` features
on that extra copy. A feature marked `# alone` waits until its copy is free of other
features and then holds it alone, so on a single copy every other drive stopped meanwhile:
in a replay of 214 features in 51 drives at once, one extra copy cut the time from 359 to
236 s. When the build bakes ports into an image (such as
`NEXT_PUBLIC_*` URLs), each lane builds its own.

For a CLI or a library there is no process to restart: `launch.sh` prepares the run's data
folder and builds once, and `doctor.sh` checks that the folder is the run's and the build is
current.

Build the environment for speed, because every recipe pays for it on every run:

- Key every per-run file and port on `$VERIFY_RUN_ID`, never a fixed path such as
  `.cache/run/`, so lanes (extra copies of the environment, `bin/verify up --lanes N`) can
  run side by side.
- Shorten every timer the features wait on in the run's own configuration: job intervals,
  retry delays, grace periods, expiries, polling. When the project's stack fixes the
  environment and has no override hook, add one to the stack as part of the repo (such as a
  compose override file it reads), or note the gap and start the job once per recipe. Write each override and the recipes that
  rely on it into `PROJECT.md`; before shortening a job for all features, check which
  recipes set up the state that job consumes.
- Keep each copy small so lanes fit in memory: cap worker counts and heap sizes (a JVM
  without `-Xmx` takes a quarter of the machine). Start the project's own JVM apps with
  `-XX:TieredStopAtLevel=1 -XX:+UseSerialGC`; it cut startup by 15 to 20% in trials. Give
  every service of the run a memory limit, third-party ones included: a container limit
  (`mem_limit`) about one and a half times what it uses after a busy run (the example
  recipe's flow plus a few hundred sign-ins, 30 at a time), read with `docker stats`, never
  sized from an idle stack. A runtime that sizes its heap from the
  container, such as a JVM, then stays inside it; in trials an uncapped Keycloak grew to
  8 GB in one drive, and a limit of twice its idle use got it killed for memory. Change only the limit of a
  third-party service, never its startup flags: Keycloak's start script picks a collector
  that clashes with `UseSerialGC` and does not start. When the services come from the
  project's local stack, the limit goes into that stack (`create-project-local-stack`),
  not into the run.
- A stub or helper that starts a process stops any leftover of the same feature first, so an
  interrupted run never blocks the next one.
- Lanes share one build: build images or artifacts once, under a lock, and let every lane
  start from them.
- Restarting the app, such as for a clock shift, polls readiness every half second and
  never runs the whole doctor. `cleanup.sh` stops throwaway containers without a grace
  period (`docker compose down -t 1`).
- `doctor.sh` retries each probe a few times with a 30 s limit, so a loaded machine never
  stops a drive with a false failure.

At level `checks-only`, skip launching and recording: write no recipes, put the focused
checks in `PROJECT.md`, and go to step 6.

## 4. Record every feature

1. Run `bin/areas > .cache/areas.txt`. It reads the source in under a second and groups
   the entry points into areas of about 1,000 lines of source each, one line per area:
   `<area>: <n> lines; entry points: <...>; files: <...>`, the files being the entry points'
   folders and the project files they import. It cuts a larger screen into runs of files
   of one folder, each with the screen's entry points. One recorder records one area. Areas
   that size end at about the same time: in trials areas of 500 to 1,000 lines took 3 to 10
   minutes and areas of 1,300 to 2,700 lines took 14 to 25, because a recorder lists and
   checks every behavior it reads, and one recorder of the largest area finished 10 minutes
   after all the others. Then review the file, which takes minutes, not the quarter hour
   that grouping by hand took in trials:
   - a line still marked `split:` is one file over the size: leave it, its recorder takes
     longer;
   - rename an area whose name does not say what the user calls the screen, such as one
     named `area2-<name>`;
   - move a file to the area that uses it most when a line misses it, such as a component
     two screens share.
   No area name equals another or starts with another followed by `-`: features are named
   `<area>-<goal>`, and `bin/verify uncovered <area>` finds an area's features by that
   prefix. A feature's name is its file name and never a `verify` command (`list`,
   `all`, ...). Do not name features: the recorder lists every behavior of its area from
   the source and splits that list into features of 8 to 15 steps by user goal itself. In
   trials a recorder turned one screen into 7 features and 69 to 79 passing steps in 10
   minutes, where a recorder given two named features wrote 13 steps. For each area, write
   its expectation list with
   `bin/harvest '<its words>' <its test files> <its docs> > .cache/expect/<area>.txt`:
   every test name in the test files, and the docs headings that match the words, with the
   lines under them. Give each area only its own test files. Then delete another area's
   tests from a test file two areas share, and tests of internals (pure functions,
   formatting, chart math). Every remaining test and heading in the file is a source one of
   the area's recipes must cite in an `# expects:` line, and `bin/verify uncovered <area>`
   lists each one none cites, so recorders never search for behavior and never skip it.
   When the docs have no heading that matches the area, the file holds its tests only; the
   recorder takes the rest from source.
2. Write the first recipe yourself, for the simplest feature, following the Recipes section
   of the skill you copied, named `<area>-<goal>` after its area; that area's recorder
   keeps it. Run `bin/verify <feature>` until it passes. It becomes the
   example every recorder copies, so make it clean. Then drive the main create path by
   hand once: create the same record twice, and read it as a second tenant or user. Write
   what that shows about ids, uniqueness and shared data into `PROJECT.md`'s Gotchas before
   any recorder starts, so no recorder pays for the same trap. Also write the setup helpers
   several features need, such as signing in as each role, creating an account with a role,
   provisioning a subscription or workspace, adding a member, or reading the run's mail.
   Call each once the way a recipe calls it, after deleting its cached state (such as saved
   sign-ins), so its slow path runs too: in trials, four recorders each spent minutes
   working out the same setup alone, and a sign-in helper whose cache hid a wrong argument
   failed four recipes on the first fresh drive.
3. Start recorders with the short prompt in the skill's Recorders section: one area each,
   every area at once, heaviest first. Each area's line in `.cache/areas.txt` lists its
   source files, so the recorder reads them instead of searching, and the
   short prompt lets you start twenty recorders in seconds instead of minutes. A recorder
   writes all its area's recipes first, then drives and fixes them together, so an area of
   five features takes about as long as one feature. Recorders need no limit of their own:
   a recorder spends most of its time on the model, which costs this machine little, and
   every feature run and browser session waits in one queue for the whole machine, which
   keeps the user's reserve of memory free (see the skill's Commands section). The host's helper limit (Claude Code runs 19 or 20 helper agents at once,
   Codex 3) does not limit recorders either: start the areas beyond it as headless sessions
   of your own CLI, from the repository root, in the background, each with the same short
   prompt, its output in `.cache/recorders/<area>.log`:
   `claude -p "<short prompt>" --model sonnet --permission-mode bypassPermissions` or
   `codex exec -m <model> --full-auto "<short prompt>"`. In trials 30 headless sessions
   started at once with no rate limit. Each headless session is a process of its own, so
   run `bin/verify room` before starting each one: it returns once the machine has room.
   Use headless sessions only when your own session
   runs commands without asking; otherwise queue the areas past the limit and start one
   as each recorder returns. With no helper agents and no CLI, record the rest yourself. Start recorders on the host's fast model
   (such as `sonnet`) when it offers one: in trials it was 3 times faster at the same depth.
   Start them in the background; never block on a
   foreground command while recorders run, or their returns reach you late. Give a feature its own
   namespace (schema, prefix, account, data folder) before marking it `# alone`. A
   recorder's result is the file it writes last, `.cache/results/<area>.txt`, not
   the host's completion notice: notices can be lost. A result file that appears is a
   returned recorder, with or without a notice. After 25
   minutes, start no new recorder and list the areas not reached; sending a failing
   feature back in step 5 is still allowed.
4. Read only their result files. Fold their traps into `PROJECT.md`'s Gotchas.

## 5. Prove it

Run `bin/verify down`, `bin/verify up` and `bin/verify all`, so every recipe runs once more
from a fresh environment while the others run in parallel. Send each failing feature back to
a recorder with its summary line, and at once, while they work, drive every other feature
again on the same environment (`bin/verify $(bin/verify list | cut -d: -f1 | grep -vxF -f <failing>)`): a
recipe that fails the second time is not repeatable. A returned recorder has driven its
feature with others, so drive only the returned features once more at the end, never
everything again: in trials the second full drive waited 4 minutes for the repairs. The runner starts up to as many features at once as the
machine has cores, each only when the machine-wide queue has room; write a `jobs` file only
when the project needs a lower limit, such as a service with few connections. When `# alone`
features remain, write into the skill's `lanes` file the most extra copies a drive may
start: about their total time divided by the longest parallel feature. A drive starts a
copy only when its `# alone` features take at least twice as long as a copy takes to
start, and only while the copy fits beside the reserve; a recorder's drive of a few
features never starts one. Then check the lifecycle once:

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
