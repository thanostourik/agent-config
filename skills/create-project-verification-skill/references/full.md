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
3. Run `bin/brief --repair-all` in one call: it groups all features in `.cache/all/failed`
   into batches of at most 3, writes `.cache/brief/repair.<n>.md`, clears stale repair
   result files, and prints the dispatch list (for extra uncovered items or invalid
   not-driven reasons, pass their features too or call `bin/brief --repair <id>
   <feature>...`). Start all repair recorders at once ([Recorders](#recorders)). An area
   that has no recipe at all gets a planner first. In each area:
   - a failing recipe is repaired, or its product defect marked `# known failure:`;
   - an uncovered item gets a step, or an `# expects:` line marked not driven with its
     reason;
   - a line whose reason does not hold gets a step.
4. When every repair recorder has written its result file, run `bin/brief --collect` once
   to read all results, then run `verify all --failed`. Repeat `bin/brief --repair-all` and
   fresh repair recorders for any feature that still fails until none is left.
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

An area's expectation list holds the behaviors its tests and docs state. Generate them for
every area in one command with `bin/brief --harvest` (pass `--force` to regenerate
existing lists). It maps each area's test files (by filename, imports and entry points,
splitting shared test files per test) and matching doc headings via `bin/harvest` into
`.cache/expect/<area>.txt`.

- Review the one-line summary it prints; adjust a single area by hand with
  `bin/harvest '<its words>' <its test files> <its docs> > .cache/expect/<area>.txt` only
  when an area's tests or docs live under unusual names it missed.
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

A repair starts a **fresh** `verify-recorder` with a slim brief instead of resuming a
finished recorder (whose old context holds 50k+ tokens and costs more on every turn). Run
`bin/brief --repair-all` (or `bin/brief --repair <id> <feature>...` for at most 3 features
per group) and give each batch this prompt:

```
You are a repair recorder for verify-<app>, with the repository root <absolute path>. Read
<absolute path>/.agents/skills/verify-<app>/.cache/brief/<id>.md, then follow "Repair
features" for <id>: <features with their summary lines, uncovered items or invalid
reasons>. Write your result to
<absolute path>/.agents/skills/verify-<app>/.cache/results/<id>.txt.
```

Before you start a recorder, or send work back to one, delete its result file
`.cache/results/<area>.<n>.txt`. A file left from an earlier round looks like a recorder
that already finished.

A planner or recorder has returned when its result file appears, with or without the host's
completion notice: notices can be lost. Do not open result files one by one: run
`bin/brief --collect` in one call to read all finished results, see `verify uncovered` for
every completed area, and collect traps, product defects, dead code and timers together:

- `bin/finish` already lints and flags invalid not-driven reasons before a recorder returns.
  When `bin/brief --collect` reports uncovered items or invalid not-driven reasons for a
  completed area, batch them into fresh repair recorders (`bin/brief --repair`). A behavior
  that needs a recipe of its own goes to a new recorder: add it to the area's map, run
  `bin/brief` for it and start the recorder. Held until the first `verify all`, these start
  a rework round that every other step then waits for.
- Add its traps to `PROJECT.md`'s Gotchas when they hold for other features.
- Keep its dead code lines for the report.
- A timer that `PROJECT.md`'s Timers section does not list: ask the user how the run should
  treat it: a test-only setting in the product, a fake clock the run starts the app with,
  or leaving its behaviors undriven. Write the answer there, then send the timer back to
  the recorder.
