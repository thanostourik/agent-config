# Feedback from generating verify-yeet

Generating `verify-yeet` took 2 h 12 min: 30 min of setup, 55 min of recording with 17
recorders, and 47 min of full drives. 75 of its 1,391 `# expects:` lines were marked not
driven, and most of those lines should never have been written.

## What went wrong

- **45 pointer lines.** `verify uncovered` checked an area's expectation list only against
  that area's recipes. When another area's recipe drove the behavior, the recorder wrote
  `not driven: covered by <feature>` to make the warning go away.
- **12 lines for code no input reaches.** The rules ask for every error branch from the
  source, and accept "the app can never receive that input" as a reason.
- **12 lines for timers fixed in the code**, such as a 10-minute login link. Each recorder
  ran into them alone, and the user saw the list only at the end.
- **The report** counted the pointer lines as not driven, listed fixes to the skill's own
  scripts as "problems fixed", and misstated the timings.
- **10 min lost in setup.** The first `verify up` was ready in 3 s, but yeetd kept the
  command's output pipe open, so the command ran until its timeout.
- **15 min outage while recording.** A recorder restarted the shared yeetd, so yeetd lived
  in that recorder's systemd scope, and systemd killed it when the recorder finished.
- **Random failures in 3 full drives.** `cmd | grep -q x` under `pipefail` kills `cmd` with
  SIGPIPE when grep stops reading early.
- **A lost recorder.** The prompt said "the area data", which one recorder read as a phrase.
- **Lanes clashed.** yeetd gives container apps the lowest free port from 7500, so two
  copies of the environment took the same port.
- **The largest areas set the end of recording.** Areas with 7 to 9 recipes took about
  22 min, areas with 12 to 14 about 40. All 17 recorders started at once, with half the
  memory free.

## Changes

1. **One line per behavior, in the recipe that drives it.** `covered by` is no longer a
   reason. `verify uncovered` counts an expectation line covered when any recipe cites it.
   `verify lint` flags a `covered by` line.
2. **No lines for unreachable code.** A branch no input can reach gets no `# expects:` line.
   The recorder reports it as dead code, and the final report lists it.
3. **Timers are decided once, up front.** In step 1 the generator lists the timers features
   would wait on that the run cannot shorten. It asks the user once: a test-only setting in
   the product, a fake clock, or leave them undriven. `PROJECT.md` records the answer, and a
   recipe may cite it as its reason. A recorder that finds an unlisted timer reports it.
4. **A plain final report:** timings measured with `date`, product defects, dead code,
   decisions for the user, and the undriven behaviors in plain words. Fixes to the skill's
   own scripts are not reported.
5. **Upgrade.** The upgrade script deletes `covered by` lines. The maintain skill deletes
   lines for unreachable code and asks about fixed timers.
6. **Runner:** the main copy's `launch.sh` output goes to `.cache/launch-0.log`, as the
   lanes' output already does. A failed launch prints its tail.
7. **`bin/detach` is shipped.** Every process that must outlive the command that starts it
   goes through it, with its input and output redirected.
8. **`lib.sh` gives recipes a `grep` whose `-q` reads all its input.** Recipes never pipe an
   endless stream into it.
9. **The recorder prompt names the area in backticks.**
10. **Lanes need every port from the run.** When the app picks ports itself from a fixed
    range, the skill gets no `lanes` file.
11. **Smaller areas.** A `split:` area and any area much larger than the rest are split by
    user goal, each listing its own entry points. `verify uncovered <area>` then shows only
    the entry points that area lists.

## Verification

- `bash -n` and `python3 -m py_compile` on the changed scripts.
- A scratch project with a small `entrypoints.sh`, `actions.sh` and recipes:
  - `verify uncovered` counts an expectation line cited by another area's recipe;
  - `verify uncovered <area>` on a split file lists only the area's entry points;
  - `verify lint` flags a `covered by` line;
  - `verify up` returns while `launch.sh` leaves a server running, and a failing
    `launch.sh` prints its log;
  - a recipe with `yes | head -c 1000000 | grep -q y` passes, and a failing `grep -q`
    names the recipe's line;
  - `upgrade` copies `detach` and deletes `covered by` lines.
- `./sync` shows only the expected skill files.
