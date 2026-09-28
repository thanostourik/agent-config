# Project verification skills for every agent

## Problem

Agents need a way to prove their work in the real app, and to know on their
own when and what to prove. Two attempts exist:

- `agentic-test` (global, manual) runs Given/When/Then flows from a project's
  `tests/agentic/`. It never starts services and never triggers on its own.
- poteto's `create-verification-skill` (pstack, MIT) generates a project skill
  that triggers on its own, with launch, doctor, drive, evidence, cleanup,
  and a user-facing feature map. It writes to `.cursor/skills/` only, and its
  upkeep skill, `maintain-verification-skill`, exists only in my Cursor.

Every developer on a project should get verification, whatever agent they run
(Claude Code, Codex, Grok, Cursor), without installing my agent-config.

## Design

### Two global skills in agent-config

Both live in `skills/shared/`, with
`harness: "claude-code, codex, grok, cursor"`, and each carries a copy of
poteto's MIT notice as `LICENSE` next to `SKILL.md`. The names differ from
pstack's, so they don't collide with the plugin in Cursor.

- `create-project-verification-skill`: a fork of poteto's generator. I run it
  once per project. It interviews the repo (including `PLATFORM.md` or other
  docs that name sibling repos), asks me only what it cannot observe, writes
  the project files below, and proves one feature end to end before handing
  over.
- `maintain-project-verification-skill`: I run it in a project. It does the
  project's full audit and also brings the project's two skills in line with
  what `create-project-verification-skill` would generate today, keeping the
  feature map. This is how generator changes reach projects: edit, `./sync`,
  run it in each project.

Both are manual-only (`disable-model-invocation: true`, plus
`agents/openai.yaml` with `allow_implicit_invocation: false` for Codex, as
`agentic-test` does).

### What the generator writes into a project

```
.agents/skills/verify-<app>/          source of truth, read by Codex, Cursor, Grok, OpenCode
  SKILL.md                            launch, doctor, drive, evidence, cleanup, keep-map-current
  features/README.md                  baseline, conventions, proof rules, feature index
  features/<feature>.md               one per user-facing feature
  bin/                                bash helpers, only where a command is not enough
  .gitignore                          evidence/ and run state
.agents/skills/maintain-verify-<app>/SKILL.md
.claude/skills/verify-<app>/SKILL.md            stub for Claude Code
.claude/skills/maintain-verify-<app>/SKILL.md   stub for Claude Code
```

The stubs repeat `name` and `description`, and their body says "Read and
follow `.agents/skills/<name>/SKILL.md`". No symlinks, so Windows checkouts
work. Tested: Grok and OpenCode keep one skill per name and prefer `.agents`;
Cursor gives both files the same ID; Codex never reads `.claude`.

`verify-<app>` triggers on its own. It follows poteto's generated skill, with
these changes:

- **Selection.** The agent maps its change to the user-facing feature index
  by reasoning. No code paths in the map. Before driving, it names the
  features it picked and why, one line each. The unit is a whole feature file.
- **Driving.** Steps live in the feature files as exact commands. The
  generator picks the tool per surface: Playwright CLI for web apps, `curl`
  for APIs, a terminal for CLIs, whatever fits for anything else. A code
  script only where a command can't do the job, such as a sign-in that needs
  a library.
- **Isolation.** One rule, decided once at setup and written into the skill
  as a single path: verification never writes to the developer's persistent
  data and never disturbs what the developer runs. The generator picks one
  of: use the project's existing disposable environment (like `dev.sh`),
  propose creating one for me to approve, or keep drives read-only.
- **Keeping the map current.** When a change adds or alters a user-facing
  feature, the agent runs `maintain-verify-<app>` for that feature in the
  same branch before calling the work done.
- **Platform.** Helpers are bash. The skill says Windows developers run their
  agent inside WSL.

`maintain-verify-<app>` is poteto's maintain skill, made project-local, with
two modes: one feature (the agent calls it after a change: read that
feature's source, fix its map entry, drive it once) or a full audit (a
developer calls it with no argument). Manual-only is not needed for the
one-feature mode, so it stays model-invocable.

The generator also adds one line to the project's `AGENTS.md`, inside an
existing verification or testing section, or a new `## Verification`
section: "Before calling user-facing work done, verify it with the
`verify-<app>` skill."

### Global instructions

`instructions/common.md`, "Local environment": the app server rule becomes

> - App servers (Next.js, Spring Boot, etc.): follow the project's verification
>   skill for starting and stopping them. Without one, check whether one is
>   already running and reuse it, ask before starting one yourself, and stop
>   anything you started when you're done so I can run it from my IDE.

## Steps

1. Add `create-project-verification-skill` (fork, `LICENSE`, feature map
   example, templates for the stubs and `maintain-verify-<app>`).
2. Add `maintain-project-verification-skill`.
3. Update `instructions/common.md`, `config.example.json`, and `AGENTS.md`.
4. Check sync with a temporary `--home`: both skills reach Claude Code, Codex,
   Grok and Cursor, not OpenCode or `~/.agents/skills/`. Run the sync tests.
5. Pilot in wovies, on a branch there: run the generator, replace
   `.cursor/skills/verify-wovies/`, prove one feature, then make a small UI
   change and check that a fresh agent picks the right feature on its own and
   runs the one-feature maintain. Open a wovies PR.
6. Fix the global skills from what the pilot shows.
7. Delete `skills/shared/agentic-test` and its `config.example.json` entry.
   Web-react's `tests/agentic/` stays until that project gets set up.

## Verification

- Steps 1–4: sync dry run and apply into a temporary home, and the unit tests.
- Step 5 is the real test. Auto-triggering is checked in at least Claude Code
  and Codex. Cursor and Grok are checked only if I can run them without your
  login; otherwise the PR says so.

## Out of scope

- CI.
- Setting up web-react or other projects.
- The stale Postplan rule in the tool instruction files.
