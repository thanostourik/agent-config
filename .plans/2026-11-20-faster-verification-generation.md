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

## Runs 5 and 6: a larger fixture, planners and small recorders

The fixture `desk` (1,000 lines in 8 files, 37 planted behaviors, 2 planted defects, shared
settings, a background worker, a rate limit) gives 10 areas and 39 features.

| | Run 5, generator as of run 2 | Run 6, planners and recorders of at most 2 features |
| --- | --- | --- |
| Total | 20.4 min | 18.1 min |
| Setup | 9.4 min | 9.7 min |
| Recording | 8.0 min | 7.2 min |
| Proof | 2.2 min | 0.8 min, with one full drive instead of two |
| Tokens | 36.5M | 38.8M |
| Features, expects | 39, 293 | 28, 244 |
| Planted behaviors, defects | 37 of 37, 1 of 2 | 34 of 37 in full, 0 of 2 |

Run 6 is not kept. The patch is `.plans/scratch/gen/planner-small-recorders.patch`.

- Recording was the same once a five-minute hang is taken out of each run: about 6.3
  minutes. On this fixture a recorder takes about 4 minutes whatever its features: 6
  features in 3.1 minutes, 3 features in 6.2.
- On collector the time did grow with the features: 38 minutes and 34M tokens for 7
  features, 5 minutes and 1.6M tokens for 1. A feature there costs minutes of drives and
  repairs. The fixture has no such features, so it cannot show this change.
- No feature failed in either proof, so the fixture shows no proof change either.
- Planning apart from recording lost depth: fewer refusal cases, and the planted defect
  that run 5 found by sending odd bodies was not found.
- Every run so far lost five minutes at least once to a `cat` that waited for input, in a
  command that wrote files in the shell. Recorders now write files with their file tool.

## Runs 7 and 8: one area of collector

A fixture cannot show a change to recording, so runs 7 and 8 record only the `operator`
area of collector (4,134 lines of source). They start from a copy of run 2's clone at the
commit right before recording, with the environment up, and the area runs alone. In run 2
the area's drives never waited for room on the machine, so the idle machine explains
little.

| | Run 2, one recorder and a handoff | Run 7, groups of 2 | Run 8, groups of 2, depth rules | Run 9, groups of 4, depth rules |
| --- | --- | --- | --- | --- |
| Time to the first results | 32.5 min, 5 of them a hang | 11.3 min | 12.7 min | 17.2 min |
| Tokens of the area's subagents | 15.6M | 19.5M | 30.5M | 30.5M |
| Recorder cost | about $3.9 | $5.7 | $8.3 | $7.5 |
| Features, expects, steps | 10, 189, 104 | 8, 113, 79 | 11, 241, 132 | 15, 250, 186 |
| Tokens per step | 0.15M | 0.25M | 0.23M | 0.16M |
| Product defects found | 0 | 0 | 2 | 0 |

A planner splits the area into features, in groups of at most 2 or 4, and one recorder
records each group, all at once.

- Run 7's planner merged behaviors into one line, and its recorders checked only what the
  plan listed. Runs 8 and 9 tell the planner never to merge and the recorders to treat
  the plan as the least they cover.
- Both group sizes record the area about twice as fast or faster, with about 30% more
  expects, for twice the tokens.
- The tokens follow the work: groups of 4 cost per step what the old flow cost, and they
  drove 79% more steps. Groups of 2 cost half more per step, because more recorders read
  the same files and find the same traps on their own.
- One run each, and the planner's split varies: 8, 11 and 15 features.
- Not measured: what small recorders do to proof, and a whole project.
- The patches are `.plans/scratch/gen/planner-small-recorders-r8.patch` and the generator
  copies in `.plans/scratch/gen/r8` and `r9`. The change is not in the generator: the
  token cost is a decision.

Run 10 gives each recorder one feature and a shared traps file, `.cache/traps.txt`, that
recorders append to when something costs them a drive and read before each repair.

| | Run 8, groups of 2 | Run 9, groups of 4 | Run 10, one feature each, shared traps |
| --- | --- | --- | --- |
| Time to the first results | 12.7 min | 17.2 min | 12.8 min |
| Tokens of the area's subagents | 30.5M | 30.5M | 38.0M |
| Features, expects, steps | 11, 241, 132 | 15, 250, 186 | 15, 265, 193 |
| Tokens per step | 0.23M | 0.16M | 0.20M |
| Product defects found | 2 | 0 | 1 |

- One feature each is no faster than groups of 2: the slowest single feature took 9.6
  minutes, and the planner 2.6.
- The traps file was used: 22 lines, 9 of them helpers. One recorder overwrote another's
  helper by mistake and said so there.
- A one-feature recorder starts with 33k tokens from the tool itself, before it reads
  anything, reads about 25k, and takes 29 turns on average. Every turn sends the whole
  context again, so the tool's own 33k is about half of a recorder's tokens.

Run 11 is run 8 (groups of 2, depth rules) with three additions:

- a slim agent type, `verify-recorder`: its own short prompt, four tools, no `CLAUDE.md`;
- `bin/brief`, which writes what a recorder reads first into two files, so it reads them
  in one turn: the instructions, `PROJECT.md` and the example, and its plan, behavior lines
  and the source ranges the planner named;
- the shared traps file of run 10.

| | Run 2, old flow | Run 8 | Run 11 |
| --- | --- | --- | --- |
| Time to the first results | 32.5 min | 12.7 min | 13.3 min |
| Tokens of the area's subagents | 15.6M | 30.5M | 14.2M |
| Cost at list prices, relative to run 2 | 1 | 1.9 | 1.15 |
| Turns of all recorders | 108 | 285 | 173 |
| Features, expects, steps | 10, 189, 104 | 11, 241, 132 | 11, 243, 135 |
| Tokens per step | 0.15M | 0.23M | 0.11M |

- A recorder now starts with 5k tokens, not 33k, and has 30k after its first reading.
- Recorders still read source 13 times each: the planner's ranges do not replace that.
- The planner made 4 groups, and the main session sent 2 more features back to them, so
  the last recorder ended at 17.1 minutes.
- Claude Code runs at most 20 subagents at once (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`).
  A whole project with groups of 2 needs more, so the main session must start the next
  recorder when one returns.

Run 12 is run 11 with four more changes, because a recorder's tokens are its turns times
its context, and it makes one call a turn whatever its prompt says:

- `bin/brief` cuts out the functions the behavior lines cite, in place of ranges the
  planner guessed;
- `bin/finish` does a recorder's closing checks in one call: lint, a drive next to three
  other features, and the uncovered list;
- a failing feature's line comes with the end of its log and its evidence file names;
- a behavior found late that needs a recipe of its own goes to a new recorder.

| | Run 2, old flow | Run 11 | Run 12 |
| --- | --- | --- | --- |
| Time to the first results | 32.5 min | 13.3 min | 10.9 min |
| Tokens of the area's subagents | 15.6M | 14.2M | 9.5M |
| Cost at list prices, relative to run 2 | 1 | 1.15 | 0.87 |
| Turns of all recorders | 108 | 158 | 118 |
| Source reads per recorder | | 13.5 | 7.8 |
| Features, expects, steps | 10, 189, 104 | 11, 243, 135 | 10, 201, 119 |

- The planner listed 152 behaviors in run 12 and 181 in run 11, so the depth of one run
  varies by about a fifth.
- Run 12 marked no known failure: its recorder saw the RSS 1.0 defect that runs 8, 10 and
  11 marked, was unsure, and left it out.

## Run 13: two more areas with run 12's flow

Both ran at the same time, each from run 2's clone at the commit right before recording.

| | `jobs` in collector, run 2 | run 13 | `sync` in scratch (browser), run 2 | run 13 |
| --- | --- | --- | --- | --- |
| Time to the first results | 26.4 min | 10.9 min | 19.0 min | 28.4 min |
| Time until all was recorded | 26.4 min | 21.9 min | 19.0 min | 28.6 min |
| Tokens of the area's subagents | 11.5M | 10.4M | 8.1M | 10.7M |
| Cost at list prices, relative to run 2 | 1 | 1.09 | 1 | 1.95 |
| Features, expects, steps | 8, 70, 78 | 10, 123, 103 | 6, 46, 38 | 7, 82, 79 |

- Depth grew in all three areas tested: 6%, 76% and 78% more expects than run 2.
- Speed did not hold: 3 times faster on `operator`, 1.2 times on `jobs`, 1.5 times slower
  on `sync`.
- `jobs`: the planner took a minute and cited none of the area's 24 expectation lines.
  The recorders covered 21 on the way. For the other 3 the main session started a fifth
  recorder after the first wave, which cost 11 minutes. A script can list what a plan
  does not cite before any recorder starts.
- `sync`: one recorder took 27 minutes, 17 of them in commands that hung on Playwright's
  fake clock, four times for 150 to 200 seconds, before it drove anything. Two recorders
  each built a helper that holds the sync socket's messages. The old flow's single
  recorder built one.
- So the slowest recorder still sets the time, and a split does not shorten a recorder
  that is stuck. Recording a whole project ends with its slowest recorder, so only a
  whole-project run shows the total.

## Run 14: the same two areas with four fixes

- The planner runs `bin/brief <area>` on its own plan. It lists each expectation line,
  entry point and action the behaviors file does not cite, and the planner adds them.
- No forced limit on by-hand commands: Claude Code skips a project agent's hooks in an
  unattended run of a folder it was not told to trust, and a command that reaches its
  limit moves to the background. The recorder agent's prompt sets a two-minute limit and
  forbids chaining a command behind one that can hang.
- Seven generic traps of the browser driver go into the project notes, the fake-clock hang
  first.
- A recorder announces a helper in the traps file before it builds it.

| | `jobs`, run 2 | run 13 | run 14 | `sync`, run 2 | run 13 | run 14 |
| --- | --- | --- | --- | --- | --- | --- |
| Time until all was recorded | 26.4 min | 21.9 min | 19.9 min | 19.0 min | 28.6 min | 14.9 min |
| Tokens of the area's subagents | 11.5M | 10.4M | 10.4M | 8.1M | 10.7M | 14.2M |
| Cost at list prices, relative to run 2 | 1 | 1.09 | 1.08 | 1 | 1.95 | 2.6 |
| Behavior lines in the plan | | 56 | 111 | | 73 | 149 |
| Features, expects, steps | 8, 70, 78 | 10, 123, 103 | 9, 117, 101 | 6, 46, 38 | 7, 82, 79 | 12, 149, 120 |

- `sync`: no command hung and no helper was built twice. The plan doubled, so the area
  costs 2.6 times run 2 for 3.2 times its expects.
- `jobs`: the plan was complete, and the first results came at 11.9 minutes. Two recorders
  had marked six behaviors not driven for reasons the rules do not allow, such as the
  SQLite store. The main session sent them back, which took until 19.9 minutes. In run 2
  the same reasons were sent back only in proof.
- With `operator` (run 12): 3 times, 1.3 times and 1.3 times faster than run 2, for 0.87,
  1.08 and 2.6 times its cost, and 6%, 67% and 224% more expects.

## Run 15: the same two areas with rules against unwanted checks

Read one by one, run 14's 149 `sync` expects were about 85 real ones, 45 that belong to
other areas (the plan check had offered the actions of a shared file), 10 duplicates (a
test line and a source line for one behavior) and 9 internals. Run 15 adds:

- the plan check leaves out actions in files another area lists too, and `bin/finish`
  shows them apart;
- one line per behavior, citing the test and the function together;
- only what a user or client can observe is a behavior;
- the planner stays inside its area in a shared file;
- before a recorder marks a line not driven for missing tooling, it asks in the traps file
  and builds the tooling when no one has it.

| | `jobs`, run 2 | run 14 | run 15 | `sync`, run 2 | run 14 | run 15 |
| --- | --- | --- | --- | --- | --- | --- |
| Time until all was recorded | 26.4 min | 19.9 min | 18.4 min | 19.0 min | 14.9 min | 13.3 min |
| Cost at list prices, relative to run 2 | 1 | 1.08 | 0.86 | 1 | 2.6 | 1.12 |
| Behavior lines in the plan | | 111 | 63 | | 149 | 44 |
| Features, expects, steps | 8, 70, 78 | 9, 117, 101 | 8, 72, 70 | 6, 46, 38 | 12, 149, 120 | 6, 44, 45 |

- The unwanted checks are gone, and no recorder marked a line not driven without reason.
- The rules cut real checks too: run 15 has the depth of run 2, not run 14's. `sync`
  lost behaviors run 2 had, such as the "Session ended" message, whose code is in a
  shared file.
- Recording was 1.4 times faster than run 2 in both areas at about its cost. The speed
  held at every depth: the plan's size sets the cost, not the time.
- The planner's rules swing the plan widely: 73, 149 and 44 behaviors for `sync`. With
  the same rules it still varies by a fifth (152 and 181 for `operator`).

## Runs 16 and 17: how much a plan varies, and a review step

Planning alone, three times per area with the same rules (run 15's without "only what a
user can observe", and with a shared file's rule changed to "take what your area's work
shows or causes there"), then a reviewer that reads the source again and appends what the
plan missed:

| Area | Behavior lines in three plans | After the review |
| --- | --- | --- |
| `sync` | 65, 59, 93 | 95, 92, 114 |
| `jobs` | 112, 80, 93 | 145, 97, 117 |
| `operator` | 192, 152, 220 | 265, 177, 254 |

- The same rules give plans that differ by about 30%. Nearly every function of the
  area's own files is cited in every plan: the plans differ in how finely they split a
  function into behaviors.
- The review raises the smallest plan and does not make the plans equal.
- Two checks tried on these files and dropped: requiring each error message of a cited
  function in the plan (planners name codes, not messages, and a shared dispatcher holds
  other areas' messages), and requiring each function of the area's own files (the plans
  already cite them).

Recording with planner, review and recorders of at most 2 features:

| | `jobs`, run 2 | run 16 | `operator`, run 2 | run 17 | `sync`, run 2 | run 16 |
| --- | --- | --- | --- | --- | --- | --- |
| Time until all was recorded | 26.4 min | 16.0 min | 32.5 min | 15.7 min | 19.0 min | 20.2 min |
| Cost at list prices, relative to run 2 | 1 | 1.14 | 1 | 1.34 | 1 | 4.2 |
| Behavior lines in the plan | | 110 | | 262 | | 186 |
| Features, expects, steps | 8, 70, 78 | 12, 137, 104 | 10, 189, 104 | 16, 284, 166 | 6, 46, 38 | 18, 193, 166 |

- `jobs` and `operator`: faster and deeper for 14% and 34% more cost.
- `sync`: the plan came out at 186 lines, twice the plan-only runs. Four times the expects
  for four times the cost, no faster, and 2 of its 18 features failed when driven together.
- `operator` marked no defect. Its plan describes the RSS 1.0 defect, which runs 8, 10 and
  11 marked, as intended behavior.
- Recipes still hold two lines for one behavior, one citing the test and one the function.
- So the depth of a run is not under control: for `sync` the plan was 44 to 186 lines
  across runs, and the cost follows the plan. The review step makes that worse.

## Runs 18 and 19: the version that went into the generator

Planner without a review step, recorders of at most 2 features, the plan check without
shared-file actions, one line per behavior, the slim agent, `bin/brief`, `bin/finish`, the
failure excerpt and the shared traps file. The proof steps are the old ones: no run
measured proof.

| | `jobs`, run 2 | run 18 | `operator`, run 2 | run 19 | `sync`, run 2 | run 18 |
| --- | --- | --- | --- | --- | --- | --- |
| Time until all was recorded | 26.4 min | 28.3 min | 32.5 min | 14.5 min | 19.0 min | 13.4 min |
| Cost at list prices, relative to run 2 | 1 | 1.28 | 1 | 1.08 | 1 | 1.34 |
| Behavior lines in the plan | | 74 | | 171 | | 48 |
| Features, expects, steps | 8, 70, 78 | 11, 101, 87 | 10, 189, 104 | 10, 216, 113 | 6, 46, 38 | 6, 51, 50 |

- `sync` and `operator`: 1.4 and 2.2 times faster, 11% and 14% more expects, 34% and 8%
  more cost. `sync` holds the two behaviors run 15 lost.
- `jobs`: slower than run 2. One recorder took 26 minutes: its features submit jobs to the
  shared collector, which runs one job at a time, so recorders that work at once wait for
  each other there. One of its commands waited 284 seconds for that queue. Across the five
  runs of this area with the new flow the time was 16 to 28 minutes.
- No run was cheaper in total at more expects. A recorder turn costs about 5 cents in the
  old flow and the new one: every turn sends the context again, and about half of what a
  recorder writes is its own reasoning. The new flow needs as many turns for a check as
  the old one. It is faster because recorders work at the same time.
- After run 19's last recorder returned, its session stayed open for 6 minutes on a
  background watch for result files. `FULL.md` says again to stop such a watch.
- Not measured: a whole generation, proof, and more than 20 recorders at once.

Changes that hold go to the generator, `maintain-project-verification-skill` and the docs in
this branch's PR.

## Verification

- The three runs themselves, compared phase by phase.
- `python -m unittest discover -s tests -v` and `./sync --home <temp>`.
