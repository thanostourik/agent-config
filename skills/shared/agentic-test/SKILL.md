---
name: agentic-test
description: Use when the user asks to run the project's agentic end-to-end tests, or invokes this skill with group names or `list`.
disable-model-invocation: true
---

# Agentic test

Run the manually triggered, agent-driven end-to-end tests that a project
defines in markdown under `tests/agentic/`. Nothing about a project lives in
this skill; the project's files hold all of it. Drive the app with the browser
tooling available to you and the shell.

Arguments: `$ARGUMENTS` (the text after the skill name).

## Contract with the project

- `tests/agentic/TEST.md` in the repository root is the entry point. If it is
  missing, say so and stop.
- `TEST.md` is authoritative for: environment URLs and health checks, test
  accounts and seeded data, rules for using and restoring data, the maximum
  number of flows to run without confirmation, and the report and reproduction
  note formats. Read it first and follow it.
- Each `tests/agentic/flows/<group>.md` is one group. It starts with a
  `covers:` list of repo-relative source paths, followed by one or more flows
  written as Given/When/Then steps under `##` headings.
- Run artifacts go under `tests/agentic/runs/<YYYY-MM-DD-HHmm>/`. Create the
  folder; it is git-ignored.

## Arguments

- No argument: select groups from the change set. The change set is the diff
  of the current branch against the default branch plus uncommitted changes.
  A group is selected when any of its `covers:` paths is a prefix of, or equal
  to, a changed file path. Always include a group named `smoke` if one exists.
  If nothing matches, say so and stop.
- One or more group names: run exactly those groups.
- `list`: print every group with its flow names and `covers:` paths, then stop
  without running anything.

## Before running

Print the plan: the selected groups, each flow name, and the total flow count.
If the total exceeds the cap in `TEST.md`, stop and ask which groups to run.

Then perform the environment health checks from `TEST.md`. If any target is
down, report which one and stop. Never start servers or containers yourself.

## Running flows

- Prefer a scripted headless browser if the repo already has one installed
  (for example Playwright in `node_modules`), driven by a throwaway script
  that you delete afterwards. It is cheaper and more reliable than
  screenshot-driven clicking. Fall back to the interactive browser tooling
  available to you. Use plain HTTP calls for API-only steps.
- One flow at a time. Start each flow signed out, in a fresh browser context.
- Follow the steps literally. If a step cannot be performed as written, or a
  `Then` line does not hold, the flow fails at that step. Do not look for
  another route to the outcome, do not retry beyond what the steps say, do not
  fix the app.
- Every `Then` line is checked. Anything else that looks wrong (console
  errors, broken layout, endless spinner) is recorded as a note, not a failure.
- Respect the data rules in `TEST.md`: use seeded data where the flow says so,
  create fresh data only where the flow says so, restore anything the flow
  changed.

## After running

- Write the report in the format `TEST.md` specifies into the run folder and
  print it in full.
- For every failed flow, write the reproduction note `TEST.md` specifies.
- For every failure, judge whether the cause is more likely the app or a stale
  flow expectation, by reading the relevant code the group `covers:`. Label
  each failure `app` or `flow` with a one-line reason. Do not change either the
  app or the flow file; the developer decides.
- End with a one-paragraph summary: flows run, passed, failed, and the labels
  of the failures.
