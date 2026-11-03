# Fast verification, redesigned

## Problem

Verification costs hours per task and most of that time is agent work, not the app.
Timings from the backend-spring pass on 2026-11-02 (23 features):

| Phase | Time | Who works |
| --- | --- | --- |
| First launch (cold Maven build) | 10 min | bash |
| Recording 18 features with recorders | 51 min | agents |
| Fresh launch + drive of all 23 features | 10 min | bash |
| Conformer, briefs, contract maps, clash checks, Ship, report | ~20 min | agents |

The deterministic part (launch and drive) already fits the budget. The slow, expensive
part is the agent machinery around it: a 738-line `rec.sh`, contract maps, peeks, brief
templates, a conformer, three maintenance modes, every feature run twice (recorded, then
driven again after a fresh launch), and selection rules that turn any shared change into
"every feature".

## Goals

- Every feature of any project type has an end-to-end recipe.
- After a bug fix or a feature, the affected features are driven.
- Full drive of a project: 30 min at most, target 10.
- Full record of a project: 30 min at most.
- An agent spends tokens only on writing or fixing a recipe, never on running one.

## Design

### A recipe is a script

Each feature is one executable bash file, `features/<name>.sh`. It needs no Markdown
parser: the runner just executes it. It uses a small shared library (`lib.sh`) and the
project's own helpers in `bin/`.

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

- `step` runs a command with a deadline (default 30 s) and logs it to the evidence folder.
- `expect` waits until a value matches, with a deadline. No bare `sleep`.
- `cleanup` always runs, through a trap.
- On failure, `lib.sh` saves the state through the project's `bin/observe` (a screenshot,
  the last HTTP response, the terminal output) and exits.
- Every name a recipe creates starts with `$RUN_ID`, so recipes run in parallel without
  colliding.

The driver is whatever the project uses, called from bash: Playwright CLI, `curl`, the
CLI itself, tmux, `adb` or Maestro, a serial port. The library does not care which. This
is how one design covers every project type.

### One runner, no agent

`bin/verify` ships unchanged to every project, about 150 lines:

- `verify up`: starts the run's environment through the project's `bin/up`. It is
  idempotent: a second call reuses the running environment and rebuilds only the app. The
  environment stays up for the whole task, so nothing is launched twice.
- `verify [feature...]`: runs the features in parallel (`--jobs`, default 8), each with a
  whole-feature deadline (default 3 min), and prints one line per feature:
  `pass`, `fail <step>: <reason> <evidence path>` or `blocked <reason>`.
- `verify affected`: runs the features whose `touches:` line names a file changed against
  the base branch. Zero tokens: it is a `grep` of the diff.
- `verify all`: every feature.
- `verify down`: removes everything the run created.

The agent reads only that summary. It opens a log only for a failed feature.

### Selection

The recorder writes `touches:` from the files it actually read to write the recipe. Those
are files, never folders, so a change to one controller selects the features that use that
controller, not the whole module. The agent may add a feature by name when the diff
changes behavior that no `touches:` line names (for example, shared security config). It
says why in one line.

Because a full drive is about 10 minutes of bash and costs no tokens, `verify all` is an
ordinary command, not an escalation. The agent uses it before a PR leaves draft.

### Recording, with a budget

Recording runs only for a new feature, or when a feature's behavior changed so its recipe
no longer matches.

- One recorder agent per feature, 8 at once.
- A recorder reads the feature's source and any test that already covers it. It writes the
  script, runs `verify <feature>`, and fixes it. At most 3 runs or 6 minutes, then it
  reports `blocked` with the failing step.
- There are no contract maps, peeks, brief templates or clash checks. `$RUN_ID` prefixes
  make clashes impossible.
- A full record of 25 features: 4 rounds of 6 minutes, about 25 minutes. The main agent
  starts no new recorder after 25 minutes. It reports the features it did not reach.

A bug fix that keeps a recipe correct needs no recording: the fix is checked by driving the
recipe. When the fix changes expected behavior, the agent edits the recipe by hand and
drives it. A recorder is not needed for that.

### Isolation stays

The run owns its environment and never touches the developer's. When the project has a
local stack (`create-project-local-stack`), `bin/up` and `bin/down` are one line each:
`stack up --app --name "$RUN_ID"` and `stack destroy --name "$RUN_ID"`. Without a stack,
the generator writes `bin/up`, or it offers to create the stack first. The ownership rules in
`lifecycle.md` stay, shortened.

### What the project gets

```
.agents/skills/verify-<app>/
  SKILL.md        # under 4 KB: up, affected, all, fix a failure, add a feature, down
  bin/verify      # shipped runner, never edited
  bin/lib.sh      # shipped library, never edited
  bin/up bin/down bin/observe   # project-specific
  features/<name>.sh
  features/README.md            # one line per feature, written by verify --index
```

There is no `maintain-verify-<app>` skill. The map is kept current by the task that
changes the behavior, like tests.

### What goes

- `rec.sh`, `steps.sh`, the Markdown recipe format and the `drive.sh --check` refusal scan.
  A linter in `bin/verify` refuses only `sleep` and recipes without `cleanup`.
- Contract maps and `## Contract` sections, peeks, `observe.sh`/`find.sh` as recorder tools,
  `reached.tsv`, `last-reviewed`, the known-failure flag.
- The conformer, the recorder and fixer brief templates, the three maintenance modes.
- `maintain-verify.md` and the generated `maintain-verify-<app>` skill.

### The skills in this repository

- `create-project-verification-skill`: rewritten. Steps: find or create the isolated
  environment, write `bin/up`/`bin/down`/`bin/observe`, list the features, record them in
  parallel within budget, run `verify all`, add the AGENTS.md section.
- `maintain-project-verification-skill`: copies the new `bin/verify` and `bin/lib.sh` into a
  project and runs one feature. Nothing else.
- `with-verification`: unchanged in purpose; its steps become `verify up`, `verify affected`,
  fix, `verify down`.
- The AGENTS.md section: run `verify affected` before calling work done, and `verify all`
  before a PR leaves draft.

### Existing projects

A converter (`bin/verify convert`) turns the old Markdown recipes into scripts: it pulls out
the `bash` blocks in order, turns each labeled block into a `step`, and the Clean up block
into `cleanup()`. It is mechanical, so no agent is needed. Features whose conversion fails a
run go to a recorder.

## PRs

1. This repo: `bin/verify`, `lib.sh`, the rewritten generator and spec, the new
   `with-verification` and AGENTS section. The old files are deleted.
2. This repo: the converter and the new `maintain-project-verification-skill`.
3. backend-spring (its own PR): convert its 23 features, measure full record and full drive.

## Proof

On a throwaway project of each kind available here (a web app, an API, a CLI), generate the
skill and time the full record and `verify all`. Then convert backend-spring in a worktree.
Pass: full record under 30 min, `verify all` under 30 min (target 10), `verify affected`
after a one-file change drives only the features that file touches.

## Open decisions

- `touches:` file lists (deterministic, zero tokens) versus agent judgment for selection.
  Recommended: file lists, with the agent adding named features when it says why.
- Default deadlines: 30 s per step, 3 min per feature, 8 jobs.
