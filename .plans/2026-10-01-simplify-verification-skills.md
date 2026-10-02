# Simplify the project verification skills

## Problem

`create-project-verification-skill` is complete but heavy. Its `SKILL.md` is 23 KB of dense
bullets, and the same rules (fresh environment, never attach, the three maintenance modes)
are repeated in four files. It also prescribes Playwright even where a project already has
Cypress, expect scripts, or a debug port. Projects that cannot create a disposable
environment get a hard "blocked". Generation always ends in a full audit.

The pstack original (Cursor) is shorter and adapts to a repo's existing tools, but has no
isolation, failure handling, or report rules.

## Design

- **Short core.** `SKILL.md` keeps the steps, one or two sentences per rule. Detail moves to
  `references/`: `lifecycle.md` (isolation, ownership, cleanup, shared mode),
  `drive-failures.md` (the four failure kinds), `verify-skill-spec.md` (sections of the
  generated skill). Each rule is stated once.
- **Drive tool.** Reuse the repo's own harness first. Defaults when it has none: Playwright
  CLI wrapper for web, `curl` for APIs, tmux for CLI/TUI, CDP for Electron. The rule "run
  the skill's shell commands, not the host's integrated browser or computer use, unless the
  wrapper fails after a fix attempt or a step needs the user watching" applies to any driver.
- **Isolation by ownership.** Never touch what the developer uses. Environments the
  verification created and recorded as its own (directly, or through the project's own
  disposable-environment script) may be reused and reseeded. Fresh per run is the default.
- **No isolation possible.** The generator asks the user once: build isolation, shared-instance
  mode (one driver, marked fixtures only, reports labeled lower confidence), or focused checks
  only. The answer is written into the generated skill. During a run, a step that must touch
  something not owned asks first and names the resource.
- **Create modes.** Default: map every feature, then full audit. `quick`: map only one feature
  per surface, drive each once, stop. Maintenance already finds features missing from the map
  and drives new feature files, so no per-feature status label is needed.
- **Existing skills.** `create` stops when `verify-*` already exists and asks: replace or upgrade.
- **Gaps.** Add the verification section to `CLAUDE.md` when it does not import `AGENTS.md`.
  One rule for third-party sign-in. Maintenance checks that the Claude stubs match the real
  skills. The controlled startup-failure test runs only when startup creates more than one
  resource.
- **README.** A section on how to call both skills, with their modes, in each tool.

## Verification

- `./sync --check` and `python -m unittest discover -s tests -v`.
- Trial on `~/Devel/workspace/scratch`: delete its generated skills, regenerate, drive.
