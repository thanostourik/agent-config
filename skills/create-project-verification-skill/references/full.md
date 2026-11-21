# Full mode and recorders

This file is shipped by `create-project-verification-skill` and is replaced on upgrade. Read
it for `/verify-<app> full`, and before you start a recorder. It builds on `SKILL.md` in
this folder: `verify`, the paths, and the Header and Done rules are the ones that file
gives.

## Full

1. Run `bin/areas > .cache/areas.txt`. When the recipes of an area start with another name
   than the file gives that area, because the area was renamed when the skill was
   generated, give the area that name in the file. Then write the expectation list of each
   area that has none, or whose tests or docs changed
   ([Expectation lists](#expectation-lists)).
2. Run `verify all`, which brings the run up on the production build. Then run
   `verify uncovered`. Check each not-driven reason it prints against the Header rules:
   recipes keep reasons that were written under older rules.
3. Start repair recorders, all at once ([Recorders](#recorders)), for the features that
   fail, the uncovered items, and the not-driven reasons that do not hold. No recorder gets
   more than 3 features, so the slowest repair ends close to the others. A feature belongs
   to the area its name starts with, else to the area that lists its `# touches:` files.
   An uncovered item goes with the feature of its area that shares its file, and an area
   that has no recipe at all gets a planner first. Give each recorder the summary lines of
   its failing features, and its items and reasons with their features. In each area:
   - a failing recipe is repaired, or its product defect marked `# known failure:`;
   - an uncovered item gets a step, or an `# expects:` line marked not driven with its
     reason;
   - a line whose reason does not hold gets a step.
4. When every recorder has written its result file, run `verify all --failed`. Send each
   feature that neither passes nor fails at its known failure back to its recorder, with
   its summary line. Repeat until none is left.
5. Run `verify all` once more, with no `--jobs`, as the final proof (the Done rule). A
   feature that fails there almost always fails only under full load. Send it back to its
   recorder to fix and run `bin/finish`. When every repair is back, drive all repaired
   features together with 15 to 20 other features once to confirm they hold under load, then
   run the next final `verify all`, until each feature passes in a final `verify all` or
   fails at its known failure. Then run `verify uncovered`: nothing is left uncovered, and
   every not-driven reason holds.
6. Run `verify down`, commit, and report the features added, the features repaired, the
   expectations that now have a step, each product defect, and the dead code the recorders
   found.

## Expectation lists

An area's expectation list holds the behaviors its tests and docs state. Write it with
`bin/harvest '<its words>' <its test files> <its docs> > .cache/expect/<area>.txt`.

- It lists every test name in the test files, and the docs headings that match the words,
  with the lines under them. When no docs heading matches the area, the list holds only its
  tests, and the recorder takes the rest from the source.
- Give each area only its own test files. Then delete from the list the tests that belong
  to another area (from a test file two areas share) and tests of internals (pure
  functions, formatting, chart math).
- Every line left is a behavior that a recipe must cite in an `# expects:` line, usually
  one of the area's, else the recipe of another area that drives it. `verify uncovered
  <area>` lists each line no recipe cites, so recorders never search for behavior and never
  skip it.

## Recorders

An area is a line of `.cache/areas.txt`: a screen or a few that share setup, about 1,000
lines of source. Two kinds of subagent record it, and `RECORDERS.md` holds the steps of
both:

- A planner reads one area's deterministic code inventory (`.cache/brief/<area>.plan.md`)
  and maps its entry points, functions and expectations into features in
  `.cache/plan/<area>.map.txt`. It needs no environment.
- `bin/brief` validates each feature map, packs features deterministically into balanced
  groups of at most 3 (`.cache/plan/<area>.<n>.txt`) and writes one brief per group.
- A recorder records one group, or repairs up to 3 features. A recorder's time and its
  tokens per feature both grow with its features, and every later step waits for the
  slowest recorder, so none gets more.

First run `bin/brief --plan` (or `bin/brief --plan <area>` for one area) to generate the
plan briefs in one call. Then start one planner per area, every area at once. When every
planner has written its result file `.cache/results/<area>.plan.txt`, run
`bin/brief --all <example feature>` (or `bin/brief <area> <example feature>` for one area)
in one call: it validates each map, writes `.cache/brief/common.md` and one brief per group
file, and prints the groups heaviest first. When the environment is up, start one recorder
per group file, every group at once, in that heaviest-first order. Their feature runs wait
in the machine's queue, so they need no limit of their own. In T3 Code use `delegate_task`
with `mode: "async"`. Otherwise use your tool's own background subagent: the agent type
`verify-recorder` when your tool lists it, else its fast model (such as `sonnet`) when it
offers one. When your tool will not start more subagents:

- If your session runs commands without asking, start the rest as headless sessions of your
  own CLI, in the background, from the repository root. Give each the short prompt, and
  send its output to `.cache/recorders/<area>.<n>.log`:
  `claude -p "<short prompt>" --model sonnet --permission-mode bypassPermissions` or
  `codex exec -m <model> --full-auto "<short prompt>"`. Each is a process of its own, so run
  `verify room` before starting each one: it returns once the machine has room.
- Otherwise start the next one each time a planner or recorder returns. Claude Code runs
  at most 20 subagents at once: start the heaviest groups first (the order `bin/brief`
  prints), since one that starts late ends late.
- With no subagents and no CLI, plan and record the areas yourself.

Never block on a foreground command while planners or recorders run, or their returns
reach you late. To wait for a result file in the background, name it by its absolute path
and set a limit: `timeout 900 bash -c 'until [[ -f <absolute path> ]]; do sleep 5; done'`.
A watch on a path that never appears runs until its limit, and one still running keeps a
headless session from ending: stop every watch once the last recorder has returned. Give each one its short prompt, with the paths filled in.

A planner:

```
You are a planner for verify-<app>, with the repository root <absolute path>. Read
<absolute path>/.agents/skills/verify-<app>/.cache/brief/<area>.plan.md and follow "Plan an
area" for `<area>`.
```

When a recipe is already written or being written for the area, such as the generator's
first recipe, add the line `The recipe features/<feature>.sh is being written for this
area.`

A recorder:

```
You are a recorder for verify-<app>, with the repository root <absolute path>. Read
<absolute path>/.agents/skills/verify-<app>/.cache/brief/common.md and
<absolute path>/.agents/skills/verify-<app>/.cache/brief/<area>.<n>.md in one turn, then
follow "Record a group" from the first file for your group, <area>.<n>.
```

A repair uses the recorder's prompt with `"Repair features"` in place of
`"Record a group"`, and adds the features with their summary lines, items or reasons. Send a repair to the recorder that recorded the feature when your tool can
still reach it: it knows the recipe.

Before you start a recorder, or send work back to one, delete its result file
`.cache/results/<area>.<n>.txt`. A file left from an earlier round looks like a recorder
that already finished.

A planner or recorder has returned when its result file appears, with or without the host's
completion notice: notices can be lost. Read only that file's lines (batching several
completed result files in one turn when they finish close together). For a recorder:

- `bin/finish` already lints and flags invalid not-driven reasons before a recorder returns.
  Run `verify uncovered <area>` once all groups of `<area>` have returned (not after every
  group). Send back each not-driven reason that still does not hold under the Header rules
  and each item still uncovered to the recorder whose recipe it fits into. A behavior that
  needs a recipe of its own goes to a new recorder instead: add it to the area's map, run
  `bin/brief` for it and start the recorder. Held until the first `verify all`, these start
  a rework round that every other step then waits for.
- Add its traps to `PROJECT.md`'s Gotchas when they hold for other features.
- Keep its dead code lines for the report.
- A timer that `PROJECT.md`'s Timers section does not list: ask the user how the run should
  treat it: a test-only setting in the product, a fake clock the run starts the app with,
  or leaving its behaviors undriven. Write the answer there, then send the timer back to
  the recorder.
