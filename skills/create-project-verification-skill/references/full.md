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
3. Start a recorder for each area that holds a failing feature, an uncovered item or a
   not-driven reason that does not hold, all at once ([Recorders](#recorders)). A feature
   belongs to the area its name starts with, else to the area that lists its `# touches:`
   files. Give each recorder the summary lines of its failing features, and those reasons
   with their features. In each area:
   - a failing recipe is repaired, or its product defect marked `# known failure:`;
   - an uncovered item gets a step, or an `# expects:` line marked not driven with its
     reason;
   - a line whose reason does not hold gets a step.
4. When every recorder has written its result file, run `verify all --failed`. Send each
   feature that neither passes nor fails at its known failure back to its recorder, with
   its summary line. Repeat until none is left.
5. Run `verify all` once more, with no `--jobs`, as the final proof (the Done rule). When
   a feature fails there, send it back and go on with `verify all --failed`, until each
   feature passes in a final `verify all` or fails at its known failure. Then run
   `verify uncovered`: nothing is left uncovered, and every not-driven reason holds.
6. Run `verify down`, commit, and report the features added, the features repaired, the
   expectations that now have a step, and each product defect.

## Expectation lists

An area's expectation list holds the behaviors its tests and docs state. Write it with
`bin/harvest '<its words>' <its test files> <its docs> > .cache/expect/<area>.txt`.

- It lists every test name in the test files, and the docs headings that match the words,
  with the lines under them. When no docs heading matches the area, the list holds only its
  tests, and the recorder takes the rest from the source.
- Give each area only its own test files. Then delete from the list the tests that belong
  to another area (from a test file two areas share) and tests of internals (pure
  functions, formatting, chart math).
- Every line left is a behavior that one of the area's recipes must cite in an `# expects:`
  line. `verify uncovered <area>` lists each line none cites, so recorders never search for
  behavior and never skip it.

## Recorders

An area is a line of `.cache/areas.txt`: a screen or a few that share setup, about 1,000
lines of source.

Start one recorder per area, every area at once, heaviest first. Their feature runs wait in
the machine's queue, so they need no limit of their own. In T3 Code use `delegate_task` with
`mode: "async"`. Otherwise use your tool's own background subagent, on its fast model (such
as `sonnet`) when it offers one. When your tool will not start more subagents:

- If your session runs commands without asking, start the rest as headless sessions of your
  own CLI, in the background, from the repository root. Give each the short prompt, and
  send its output to `.cache/recorders/<area>.log`:
  `claude -p "<short prompt>" --model sonnet --permission-mode bypassPermissions` or
  `codex exec -m <model> --full-auto "<short prompt>"`. Each is a process of its own, so run
  `verify room` before starting each one: it returns once the machine has room.
- Otherwise start the next area each time a recorder returns.
- With no subagents and no CLI, record the areas yourself.

Never block on a foreground command while recorders run, or their returns reach you late.
Give each recorder this short prompt, with the paths and area filled in:

```
You are a recorder for verify-<app>. Follow
<absolute path>/.agents/skills/verify-<app>/RECORDERS.md, with the repository root
<absolute path>, the example recipe features/<example>.sh, and the area <area> of
.agents/skills/verify-<app>/.cache/areas.txt.
```

A recorder has returned when its result file `.cache/results/<area>.txt` appears, with or
without the host's completion notice: notices can be lost. Read only that file's lines. Add
their traps to `PROJECT.md`'s Gotchas when they hold for other features.
