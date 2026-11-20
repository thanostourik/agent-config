# Faster verification generation, measured

## Goal

Make `create-project-verification-skill` generate a project's verify skill faster, with no
loss of depth. Measure on three different projects, change the generator, and measure
again, for three runs.

## Projects

| Project | Kind | Features today |
| --- | --- | --- |
| `scratch` | TypeScript web app on yeet: offline sync, keyboard UI, Electron | 28 |
| `contentcloud-insights` (collector) | Python HTTP API, CLI and workers, no UI, with a local stack | 37 |
| `otis` through `otis-qa` | Server-rendered Java on Tomcat plus a separate UI, as a companion QA repo | 60 |

Each run generates all three, one after the other, so they never compete for the machine.

## Method

- Each project runs in fresh clones under `.plans/scratch/gen/r<N>/`, at fixed commits, with
  its old verify skill removed in a local commit. Pushing is disabled in the clones.
- Each run uses a frozen copy of the generator, so a later edit never changes a running run.
- A headless Opus session runs the generator in default mode. Recorders run on Sonnet, as the
  generator says. The brief pre-answers the questions the generator would ask.
- Each session writes phase marks with `date +%s`: setup, recording and proof.

## What is measured

- Time: total, setup, recording, proof; per recorder start, end, drives and drive time.
- Tokens: `usage-report` for the main session and its recorders.
- Depth, so speed never comes from doing less: features, steps, `# expects:` lines,
  not-driven lines, and the final `verify all` result.

## Runs

1. Baseline: the generator on main.
2. Changes picked from run 1's data. Candidates: prove each area while recording continues,
   split areas by feature count, write each behavior once.
3. Changes picked from run 2's data.

## Small loop, after run 2

Runs 1 and 2 cost 100 minutes and 250M tokens per large project, too much to iterate on.
From run 3 on, each change is measured on a tiny fixture first:

- `tickets`: a help desk in one Node file with no dependencies, with sign-in, tickets,
  user management and a JSON API. It holds 17 planted behaviors and one planted defect,
  listed outside the clone, so quality has a known answer: how many of them the recipes
  drive.
- Run 3: the generator as of run 2, plus three changes that had not run yet.
- Run 4: recorders start reading before the environment exists and wait for
  `.cache/ready`; finished recorders' features are driven together while the others
  still record; `verify all` replaces the `verify all --failed` round.
- The machine limit for many recorders shows only at scale. It waits for a large run,
  which happens only when the small runs show a clear gain.

Changes that hold go to the generator, `maintain-project-verification-skill` and the docs in
this branch's PR.

## Verification

- The three runs themselves, compared phase by phase.
- `python -m unittest discover -s tests -v` and `./sync --home <temp>`.
