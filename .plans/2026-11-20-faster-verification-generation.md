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

## Runs 3 and 4, and what the logs say

A tiny fixture, `tickets` (one Node file, 17 planted behaviors and one planted defect, kept
outside the clone), makes a run cost 12 minutes and 15M tokens.

- Run 3, the generator as of run 2: 12.3 minutes, all 17 behaviors and the defect found.
- Run 4 started recorders before the environment, drove finished recorders' features while
  the others recorded, and dropped the `verify all --failed` round: 16.2 minutes, same
  quality. Reverted.

Run 2's logs, with idle waiting between rounds left out:

- Setup is one session writing: 90% of it is model time, 35k to 104k output tokens at
  about 90 tokens a second. No step stands out.
- Recorders: reading and listing is 10% of their time. Model time is 60% of their work on
  scratch and collector and 40% on otis; the rest is tools, mostly drives (35 s each on
  collector, 52 s on otis, 2.3 drives per feature).
- 63% of recipes pass their first drive on scratch and collector, 35% on otis.
- Proof is rounds of one full run plus the slowest repair. Collector's first round took 32
  minutes because of one recorder's 12 drives.

So the time is tokens written divided by writing speed, plus drive time on large projects.
The fixture is too small to show recording and proof changes: its setup is 55% of the run.

Changes that hold go to the generator, `maintain-project-verification-skill` and the docs in
this branch's PR.

## Verification

- The three runs themselves, compared phase by phase.
- `python -m unittest discover -s tests -v` and `./sync --home <temp>`.
