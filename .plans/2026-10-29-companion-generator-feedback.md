# Companion-mode feedback on the verification generator

The first real companion run (`otis-qa`, quick mode) reported eight places
where the generator's text does not fit a companion repo or a real project.

## Changes

1. **Launch writes nothing into the checkout.** In a companion, launch builds
   from a copy under `.cache/`, or sends the build output outside the
   checkout. A build in place leaves `target/` or `node_modules/` there.
   That copy sits in the companion's git tree, so a build that reads git
   gets `GIT_DIR` pointing at the checkout.
2. **Doctor sees uncommitted app edits.** In a companion, doctor compares the
   launched source with the app checkout's working tree, not only its `HEAD`.
   A task is verified before it is committed.
3. **Git reads take no optional locks.** `export_apps` exports
   `GIT_OPTIONAL_LOCKS=0`, and the companion section tells the generator to
   use it, so `git status` or `git diff` never rewrites an app checkout's
   index or holds `index.lock` while the developer's own git runs.
4. **Claude Code sees `AGENTS.md`.** With no `CLAUDE.md`, step 6 creates one
   holding `@AGENTS.md`. In a companion, each focused command names its
   checkout and writes nothing into it; one that leaves output, such as
   `mvn test`, runs in launch's build copy.
5. **`last-reviewed` after a full generation.** Step 8 runs
   `bin/rec.sh reviewed` after a live proof in the default mode. Quick mode
   writes none: without it, the first `/maintain-verify-<app>` greps the
   whole app and adds the unmapped features. With it, the grep covers only
   changed files, and those features would never be added.
6. **Contract sources that only mention features.** The "observed behavior"
   report line covers every feature with an empty `## Contract` section, not
   only a README-only project.
7. **Several drivers.** `observe.sh` and `find.sh` look at the driver the last
   step used. The driver block names all drivers in one phrase, because new
   feature files take it as their `## Driving it with` heading.
8. **Size target.** Every generated `SKILL.md` on this machine is 11 to 18 KB.
   The aim moves from about 8 KB to under about 15 KB.

## Verification

- `export_apps` in a scratch companion: `GIT_OPTIONAL_LOCKS` is exported, and
  `git status` through it leaves the app's `.git/index` untouched.
- Two generator runs from this branch, on throwaway copies of the app
  checkouts so any write into them shows:
  - A: `quick` mode on clones of `otis` and `otis-ui`, same commits and brief
    as the first otis-qa run.
  - B: default mode on a small notes app with a web page, a JSON API, a build
    that writes `dist/`, and no `AGENTS.md` or `CLAUDE.md`.
- After both: each checkout's `git status --ignored`, commit and
  `.git/index` time are unchanged; Docker matches its state before.
- Each generated skill is checked for the eight points. Doctor runs live
  before and after an uncommitted edit in each checkout.
- `python -m unittest discover -s tests -v`.

## Second round, from the verification runs

The two verification runs reported more generator gaps. Fixed:

- Quick mode says what a surface is: each UI, CLI, and API with its own
  clients or sign-in.
- The first-run example recipe comes from `.cache/record/first-example.md`,
  which `rec.sh common` reads until a project recipe passes. Step 4 gives the
  command that writes it.
- `rec.sh map` (`contract_map`) splits Python and JUnit tests: a test class
  groups like `describe`, a Python `def test_` function is a section.
- Step 8 removes the working notes under `.cache/record/`, except blocked
  features' folders.
- Driver limits warn that `curl … | grep -q` fails under `pipefail`.
- Helpers call each other by path.
- Lifecycle says to override a hard-coded port or host from outside the app.

Rejected:

- Run ids in Playwright CLI session names: sessions are per folder, so two
  checkouts never share one (checked).
- Forcing `--browser=chromium`: the spec already says to note a system-browser
  fallback, and the system Chrome runs with an in-memory profile.
- Reading recorder-written feature files: the rule keeps the orchestrator's
  context small, and `Runs alone.` covers shared state.
- A Maven cache under `.cache/`, the `setsid` race, stale port lists and git
  identity in `rec.sh reviewed`: implementation details the runs handled.
