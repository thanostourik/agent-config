# Verification, redesigned for speed and cost

## Goal

The same goal as today's system, for every project of any kind:

- Every feature of the project has an end-to-end recipe that drives the real app.
- During development, only the features a change affects are driven.
- The map of features stays current as the app changes.

What changes is how fast and how cheap that is:

| Operation | Limit | Target |
| --- | --- | --- |
| Drive the affected features after a change | 10 min | 3 min |
| Drive every feature | 30 min | 10 min |
| Record every feature of a project | 30 min | 20 min |
| Maintenance pass | 30 min | 15 min |

Tokens are spent only on writing or fixing a recipe, never on running one.

## Why today's system is slow and expensive

Running the app is not the slow part. Agents do work that bash could do, and they do some
of it twice:

- Every recipe is Markdown that needs a 279-line parser (`steps.sh`) and a 738-line
  recording tool (`rec.sh`) with peeks, contract maps, brief templates and refusal scans.
  Agents spend most of their tokens on this machinery, not on the app.
- Each changed feature runs twice: once while it is recorded, then again after a fresh
  launch.
- Selection rules turn any shared change (launch, sign-in, conventions) into "every
  feature", and every such feature gets a recorder.
- Maintenance runs a conformer, readers over every recipe, recorders, fixers and a long Ship
  step, even when only the generator's wording changed.

One measured example: a 23-feature project took 10 minutes to launch and drive every
feature with bash, but 70 minutes of agent work around it.

## Principles

1. A recipe is an executable script. Running it needs no agent.
2. One shipped runner does launch, selection, parallel driving, deadlines, evidence and
   cleanup. It prints one line per feature. Agents read only that.
3. An agent writes or fixes a recipe. It never orchestrates a run step by step.
4. A feature runs once per check. The environment stays up across checks in one task.
5. Every agent job has a time box. Past it, the job reports `blocked` with the reason
   instead of continuing.

## Recipe format

Each feature is one bash file, `features/<name>.sh`:

```bash
#!/usr/bin/env bash
# search: find notes by title from the top bar
# touches: src/search/SearchBar.tsx src/api/notes.ts src/server/routes/search.ts
. "$VERIFY_LIB"

setup()   { api POST /notes "{\"title\":\"$RUN_ID-alpha\"}"; }
cleanup() { api DELETE "/notes?prefix=$RUN_ID"; }

step "search shows the note" pw fill "getByRole('searchbox')" "$RUN_ID-alpha"
step "result opens the note" pw click "getByRole('link', { name: '$RUN_ID-alpha' })"
expect "note title" pw_text "getByRole('heading', { level: 1 })" "$RUN_ID-alpha"
```

- `step` runs one command with a deadline (default 30 s) and logs it.
- `expect` waits until a value matches, with a deadline. A bare `sleep` is refused.
- `cleanup` always runs, through a trap.
- On failure, the library saves the app's state through the project's `bin/observe`: a
  screenshot, the last HTTP response, or the terminal output.
- Every name a recipe creates starts with `$RUN_ID`, so features run in parallel and never
  collide. A feature that changes global state declares `# alone`, and runs by itself.
- `# touches:` lists the source files the feature uses: files, never folders.

The driver is whatever the project uses, called from bash. Web: the project's Playwright or
Cypress, else Playwright CLI. API: `curl`. CLI: the command. TUI: tmux. Electron: CDP on a
debug port. Mobile: `adb` or Maestro. Firmware: the serial port. The library does not care
which driver runs, so one format covers every project type. The driver rule (the user's
explicit choice of driver over host browser tools) stays.

## The runner

`bin/verify` and `bin/lib.sh` ship unchanged to every project. Projects never edit them.

- `verify up`: starts the run's own environment through the project's `bin/up`. A second
  call reuses it and only rebuilds and restarts the app.
- `verify affected`: drives the features whose `touches:` names a file changed against the
  base branch. It is a `grep`, so selection costs no tokens.
- `verify <feature>...` and `verify all`.
- Parallel with `--jobs` (default 8), `# alone` features one at a time, a deadline per
  feature (default 3 min).
- One summary line per feature: `pass`, `fail <step>: <reason> <evidence>`, or
  `blocked <reason>`. Evidence goes to `.cache/evidence/<feature>/`.
- `verify down`: removes everything the run created, checks only what the run owns, and
  says what remains if it fails.
- `verify uncovered`: lists the project's entry points (routes, screens, commands) that no
  feature's `touches:` names, using the entry-point command the generator wrote into the
  skill. It also lists changed files that no feature touches.
- `verify lint`: refuses `sleep`, missing `cleanup`, and names without `$RUN_ID`.

## Isolation and companion repos

Both stay, with the current rules in `lifecycle.md`, shortened:

- Levels `full`, `shared` and `checks-only`, chosen once by the generator.
- A run owns its environment and never touches the developer's. A project with a local
  stack gets one-line `bin/up` and `bin/down` around `stack up --app --name "$RUN_ID"`.
- Companion repos keep the skill outside the app's repo, and `with-verification` finds it
  from an app checkout. The runner reads the app checkouts from the companion's `apps` file.

## The three skills

### Generator: `create-project-verification-skill`

1. Find or choose the isolated environment, and write `bin/up`, `bin/down`, `bin/observe`.
   Launch once.
2. List the features with one entry-point command (routes, navigation, commands). Write
   that command into the skill for `verify uncovered`. Write `features/README.md`, one line
   per feature.
3. Record: one recorder per feature, 8 at once. A recorder reads the feature's source and any
   existing test of it, writes the script and runs `verify <feature>`. It stops after
   3 runs or 6 minutes and reports `blocked` with the failing step. The main agent starts no
   new recorder after 25 minutes and lists the features it did not reach.
4. `verify all` once, as the proof.
5. Write `verify-<app>/SKILL.md` (under 4 KB), `maintain-verify-<app>/SKILL.md`, and the
   AGENTS.md section.

### Verify skill: `verify-<app>`, used during development

1. `verify up` when the code is ready to check.
2. New behavior: write or edit the recipe by hand, with `touches:`. No recorder. A recorder
   is needed only for a whole new feature.
3. `verify affected`. Add a feature by name only when the diff changes behavior no
   `touches:` names, such as shared security config, with one line saying why.
4. A failure: read that feature's log, fix the code or the recipe, rerun that feature only.
5. `verify down`, then report the summary lines and evidence links.

`verify all` is an ordinary command, used before a PR leaves draft.

### Maintainer

`maintain-verify-<app>` keeps a project's map current when the app changed outside verified
tasks:

1. `verify up`, then `verify all`.
2. Each failing feature goes to a fixer, 8 at once, each with the same time box as a
   recorder. The fixer decides: the recipe drifted (fix it) or the app is wrong (report it
   as a product defect and leave the recipe failing).
3. `verify uncovered`: each uncovered entry point goes to a recorder. Changed files that no
   feature touches are added to the `touches:` of the feature that uses them, or reported.
4. `verify down`, one commit, one PR, a report of pass, fixed, defect, new, and blocked.

`maintain-project-verification-skill` upgrades a project to the current generator:

1. Copy the current `bin/verify` and `bin/lib.sh`.
2. If the recipe format version changed, run `verify convert`, which converts recipes
   mechanically. The first conversion turns today's Markdown recipes into scripts: the
   `bash` blocks in order, each labeled block a `step`, the Clean up block `cleanup()`.
3. Rewrite `verify-<app>/SKILL.md` and `maintain-verify-<app>/SKILL.md` from the current
   templates, keeping the project's commands, isolation and gotchas.
4. `verify all` once. Converted features that fail go to fixers.

There are no modes: no "map only", no "full audit", no conformer, no readers.

### `with-verification` and the AGENTS.md section

`with-verification` keeps its job: find the verify skill, also in a companion repo, and
follow it. The AGENTS.md section says: run `verify affected` before calling work done, and
`verify all` before a PR leaves draft.

## What goes

- `rec.sh`, `steps.sh`, `drive.sh` and the Markdown recipe format.
- Contract maps and `## Contract` sections, peeks, `find.sh`, `reached.tsv`,
  `last-reviewed`, the known-failure flag, fixture-clash checks.
- The conformer, recorder and fixer brief templates, `brief-common.md`, `maintain-verify.md`
  and its three modes.

## PRs, all in this repository

1. The runner, the library, the recipe format, the generator and the verify skill template,
   `with-verification` and the AGENTS.md section. The old files are deleted.
2. The maintainer (both skills) and `verify convert`.

Moving each project to the new system is that project's own task, done with
`maintain-project-verification-skill` after PR 2.

## Proof

Throwaway projects in `.plans/scratch/`: a web app, an HTTP API with a database, and a
CLI/TUI, each with about 10 features.

- Generate the skill for each. Time the full record and `verify all`, and measure tokens with
  `usage-report`.
- Change one file in each and check that `verify affected` drives only the features that
  file touches.
- Break one behavior and add one route, then run `maintain-verify-<app>`. Expect one fixer
  that reports the defect and one recorder for the new route.
- Run `maintain-project-verification-skill` on a copy of a project with today's Markdown
  recipes. Expect every recipe converted and `verify all` to run.
- Drive the runner by hand on those projects: parallel and `# alone` runs, a deadline that
  fires, cleanup after an interrupt, and lint refusals.

Pass: every operation within the limits in the Goal table.

## Open decisions

- Selection: `touches:` file lists, plus a named feature with a one-line reason. The other
  option is agent judgment over the feature list, which costs tokens on every check.
- Defaults: 30 s per step, 3 min per feature, 8 jobs, 6 min and 3 runs per recorder.
