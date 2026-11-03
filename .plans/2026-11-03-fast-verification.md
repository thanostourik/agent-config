# Verification, redesigned for speed and cost

## Goal

The same goal as today's system, for every project of any kind:

- Every feature of the project can be driven end to end against the real app.
- After a bug fix or a feature, agents drive the affected features and nothing unrelated.
- When the generator improves, every project picks up the change with one command.

And it is fast and cheap:

| Operation | Limit | Target |
| --- | --- | --- |
| Drive the affected features after a change | 10 min | 3 min |
| Drive every feature | 30 min | 10 min |
| Record every feature of a project (up to about 40) | 30 min | 20 min |
| Pick up a generator change | 30 min | 5 min |

Tokens go only to writing or fixing a recipe, never to running one.

## Why today's system is slow and expensive

Running the app is not the slow part. Agents do work that bash could do, and do some of it
twice:

- Recipes are Markdown that needs a 279-line parser (`steps.sh`) and a 738-line recording
  tool (`rec.sh`) with peeks, contract maps, brief templates and refusal scans.
- Each changed feature runs twice: once while it is recorded, again after a fresh launch.
- A shared change (launch, sign-in, conventions) selects every feature, and every selected
  feature gets a recorder.
- Maintenance runs a conformer, readers over every recipe, recorders, fixers and a long Ship
  step, even when only the generator's wording changed. The generated skill mixes shipped
  rules with project facts, so an upgrade needs an agent to merge them.

One measured example: a 23-feature project took 10 minutes to launch and drive every feature
with bash, and 70 minutes of agent work around it.

## Design

### A recipe is a bash script

`features/<feature>.sh`. The runner executes it through the shipped `lib.sh`, which gives it
`set -euo pipefail`, `step`, `wait_for`, a `cleanup` hook that always runs, `$EVIDENCE`, and a
state capture through the project's `observe.sh` on failure.

```bash
# Create a note from the browser and the CLI, cancel a draft, and confirm the saved note.
# touches: web/src/NoteEditor.tsx web/src/api/notes.ts server/routes/notes.ts cli/create.go
cleanup() { notes delete --title "verify-create-note" || true; }

step "Open editor"
pw.sh click "getByRole('button', { name: 'New note' })"
pw.sh run-code "async page => { await page.getByRole('form', { name: 'Note editor' }).waitFor(); }"

step "CLI entry"
notes create --title verify-create-note --format json | tee "$EVIDENCE/cli.json" | jq -e '.id'
```

- Steps share variables because the recipe is one script.
- `# touches:` names the source files the feature uses, files and not folders.
- `# alone` makes the runner drive the feature by itself, `# deadline: <seconds>` gives it
  more than the default, and `# known failure: <step>` marks a reported product defect, so
  its failure reads `(known failure)` and needs no new diagnosis.
- A blank line ends the header. A feature name is never a runner command (`list`, `all`).
- The driver is whatever the project uses, called from bash: the project's own harness,
  Playwright CLI, `curl`, the CLI itself, tmux, CDP, `adb`, a serial port. So one format
  covers every project type.

### One runner, shipped unchanged

`bin/verify`, copied from the generator and never edited in the project:

- `verify up` / `verify down`: the run's own environment, through the project's
  `launch.sh`, `doctor.sh` and `cleanup.sh`. It stays up across checks in one task, and
  `launch.sh` is idempotent: a second call reuses the environment and restarts only the app.
- `verify affected`: drives the features whose `touches:` names a file changed against the
  default branch, or whose recipe changed, or that call a changed helper directly or through
  another helper. It lists the changed files that no
  feature names, so the agent can add a feature by name and add the file to its `touches:`.
  Selection is a `grep`: no tokens.
- `verify <feature>...`, `verify all`: parallel (`--jobs`, default 8), `# alone` features
  one at a time, a deadline per feature (default 3 min), doctor after a failure.
- One summary line per feature: pass, fail at a step, or timeout, with the log path.
- `verify list`, `verify lint` (no `sleep`, no `waitForTimeout`, `touches:` present and
  pointing at real files), `verify uncovered` (entry-point files from the project's
  `entrypoints.sh` that no feature names).

### What a project holds

```
.agents/skills/verify-<app>/
  SKILL.md          shipped template, only <app> filled in
  PROJECT.md        project facts: drivers, isolation, environment, sign-in, helpers, gotchas
  bin/verify        shipped
  bin/lib.sh        shipped
  bin/launch.sh bin/cleanup.sh bin/doctor.sh bin/observe.sh bin/entrypoints.sh   project
  bin/<driver helpers>                                                            project
  features/<feature>.sh
  apps              companion repo only
.claude/skills/verify-<app>/SKILL.md   Claude Code stub
```

Shipped files and project files never mix. That makes an upgrade a copy, not a merge.
There is no `maintain-verify-<app>` skill, no feature index and no contract map: the recipe
headers are the map, and `verify list` prints it.

### The skills in this repository

- `create-project-verification-skill`: choose isolation, write the project files, list the
  features, record them with up to 8 recorders at once (each at most 5 runs), run
  `verify all` once, add the AGENTS.md section.
- `maintain-project-verification-skill`: run the shipped `upgrade` script, which copies the
  shipped files and converts today's Markdown recipes to scripts mechanically. An agent does
  only what the script lists: write `PROJECT.md` from the old skill once, fill `touches:`,
  make `launch.sh` idempotent. Then `verify all` once, fixers for failures.
- `with-verification`: unchanged in purpose; its commands become `bin/verify`.
- The AGENTS.md section: `verify affected` before calling work done.

Isolation levels, ownership rules (`lifecycle.md`) and companion repos stay as they are.

### What goes

`rec.sh`, `steps.sh`, `drive.sh`, `find.sh`, the Markdown recipe format, `features/README.md`,
contract maps and `## Contract` sections, `last-reviewed`, the `--known-failure` run flag, the
conformer, recorder and fixer brief templates, `maintain-verify.md`, `verify-skill-spec.md`
and the three maintenance modes.

## One PR

All of the above, in this repository. Moving a project is that project's own task, done with
`maintain-project-verification-skill`.

## Proof

- Throwaway projects in `.plans/scratch/`: a web app, an HTTP API with a database, a CLI.
  Generate each one's skill with a fresh agent following the new generator. Time the record
  and `verify all`, and measure tokens with `usage-report`.
- Change one file and check that `verify affected` drives only the features that name it.
- Drive the runner by hand: parallel and `# alone` runs, a deadline that fires, cleanup after
  a failure and after Ctrl-C, lint refusals.
- Run the upgrade on a copy of a project with today's Markdown recipes and drive the
  converted recipes.
- `python -m unittest discover -s tests -v` and `./sync --home <temp>` for the installed
  layout.
