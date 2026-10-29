# Companion-mode feedback on the verification generator

The first real companion run (`otis-qa`, quick mode) reported eight places
where the generator's text does not fit a companion repo or a real project.

## Changes

1. **Launch writes nothing into the checkout.** In a companion, launch builds
   from a copy under `.cache/`, or sends the build output outside the
   checkout. A build in place leaves `target/` or `node_modules/` there.
2. **Doctor sees uncommitted app edits.** In a companion, doctor compares the
   launched source with the app checkout's working tree, not only its `HEAD`.
   A task is verified before it is committed.
3. **Git reads take no optional locks.** `export_apps` exports
   `GIT_OPTIONAL_LOCKS=0`, and the companion section tells the generator to
   use it, so `git status` or `git diff` never rewrites an app checkout's
   index or holds `index.lock` while the developer's own git runs.
4. **Claude Code sees `AGENTS.md`.** With no `CLAUDE.md`, step 6 creates one
   holding `@AGENTS.md`. In a companion, each focused command names the
   checkout it runs in.
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
- `python -m unittest discover -s tests -v`.
- The text changes are proven only by the next companion generation run.
