# Verification recipe runner

## Problem

Agents drive feature recipes one command per turn. In the contentcloud repos a
drive command runs in about a second, but the agent spends about 90 seconds
(Codex) or 18 seconds (Claude) between two commands. Verifying three web-react
features of about 20 steps each takes about an hour of agent turns.

ccbot already avoids this. Its steps are bash blocks, and a small runner,
`bin/drive.sh`, runs them unattended: 82 steps across 11 features in about 9
minutes. Codex added that runner on its own. The generator neither asks for it
nor describes it, so other projects don't get it, and web-react's agent built a
throwaway one that was lost with `.cache/`.

## Design

The generator ships one runner that every project copies unchanged. The
runner knows nothing about the app. It only runs the bash blocks of the
feature files. Code takes over the mechanics that prose rules describe today,
and those rules are deleted. Affected sections are rewritten as if the runner
had always existed, not extended.

### Recipe format

Under `Driving it with <tool>`:

- `Preconditions:` keeps its sentence and gets a bash block.
- Each step keeps its sentence (the user action and the expected result) and
  gets a bash block below it. The block exits non-zero when the expected
  result is not met. A step that only prints a value gets a check, for example
  `test "$(pw --raw eval location.pathname)" = '"/en"'`.
- The last step is labeled `Clean up` and removes the feature's fixtures. The
  runner always runs it.
- A feature that changes state other features read (global settings, shared
  templates) has `Runs alone.` in its Preconditions sentence.

### Project helpers the runner relies on

- `bin/recipe.sh`: sourced before every block. It defines the shorthands the
  recipes use (`pw`, `as`, the run's ports). ccbot already has one.
- `bin/doctor.sh`: the Doctor the spec already requires, at a fixed path.
- `VERIFY_SESSION`: set by the runner to the feature name. The project's
  helpers use it to keep parallel features apart: the browser session name
  for a web app, a data folder for a CLI. A project that cannot keep features
  apart runs with `--jobs 1`.

### The runner: `bin/drive.sh [--jobs N] [feature...]`

- No feature names means every feature.
- Steps of one feature run in order. A variable set in one step is visible in
  later steps of the same feature.
- A feature stops at its first failing step. Its `Clean up` step still runs,
  then the runner runs `bin/doctor.sh`. Doctor passes: the runner continues
  with the other features. Doctor fails: the environment is broken, so the
  runner stops everything and lists the rest as not run.
- `--jobs N` drives N features at the same time on the same stack. Features
  marked `Runs alone.` run afterwards, one at a time. Default is 1. The
  generated skill writes the project's proven value into its drive command.
- Each step's command, output and exit code go to
  `.cache/evidence/<feature>/<step>.log`.
- It prints one line per step while it runs, then a summary: each feature as
  pass, or fail at a named step with its log and the steps not run. Exit code
  0 when every feature passed, 1 otherwise.
- Bash and standard tools only, so it works in any project.

### What the agent does

Pick the features, run `drive.sh` once, read the summary. Work step by step
only on a failure: diagnose it with "When a drive fails", fix it, and rerun
that feature with the runner.

### Rules this replaces

Generator `SKILL.md`, `verify-skill-spec.md`, `maintain-verify.md`,
`lifecycle.md`, the feature map example and `maintain-project-verification-skill`:

- "Keep variable creation and use in one command block or persist them under
  `.cache/`": steps share variables through the runner.
- "Type the full command, because no alias from an earlier session exists"
  (example README): `bin/recipe.sh` provides the shorthands.
- "One agent owns all driving", "one driver at a time": the runner drives. The
  `shared` isolation level keeps one driver by using `--jobs 1`.
- The per-step evidence naming and the report and progress lines for drives:
  the runner writes the logs and the summary.
- `maintain-verify`'s step-by-step selection in changed-recipes mode: it selects
  the features whose steps changed and runs them with the runner. Its progress
  table goes; the runner's summary is the record, and an interrupted pass
  reruns the features without a result.
- The Playwright session-name argument in `bin/pw.sh`: it reads
  `VERIFY_SESSION`.

### Files

- `skills/shared/create-project-verification-skill/references/drive.sh`: new,
  the runner.
- `create-project-verification-skill/SKILL.md`: steps 3, 4 and 7 use the
  format and the runner.
- `references/verify-skill-spec.md`: Drive, Evidence, Report and Helpers
  sections.
- `references/maintain-verify.md`: selection, driving and progress sections.
- `references/lifecycle.md`: the shared-level driver line.
- `references/feature-map-example/`: both recipes in the new format, README
  conventions trimmed.
- `maintain-project-verification-skill/SKILL.md`: conforming converts recipes
  to blocks with checks and installs the runner and helpers; selection picks
  features, not steps.

### Not in scope

- Partial relaunch after a source change. Left for later.
- Upgrading the contentcloud repos. Each is a separate
  `/maintain-project-verification-skill` run after this merges: web-react
  (about 150 to 250 of its 1,171 steps need a check), backend-spring, then
  ccbot (switch its `drive.mjs` to the shipped runner).

## Verification

- `./sync --check` and `python -m unittest discover -s tests -v`.
- Exercise `references/drive.sh` on a throwaway feature folder: a passing
  feature, a failing step (later steps not run, `Clean up` still runs), a
  variable carried between steps, a failing doctor that stops the run, and
  `--jobs 2` with one `Runs alone.` feature.
- Upgrade `~/Devel/workspace/scratch` with `/maintain-project-verification-skill`
  and run its features with `drive.sh --jobs 2`.
