# with-verification skill

## Goal

In an app checkout whose verification skills live in a companion repo, the
user adds "with verify" or "with verification" to a task. The agent then finds
the companion, does the task, and verifies it with the companion's
`verify-<app>` skill before reporting done.

## Design

- New skill `skills/shared/with-verification/SKILL.md`, with
  `harness: "claude-code, codex, grok, cursor"` like the generator, and an
  entry in `config.defaults.json`.
- Trigger: the description says to use it when the user gives "with verify"
  or "with verification" as an instruction to verify the current task, not
  when verification is only the topic. No further guard: a wrong load only
  runs the read-only lookup, because the skill drives nothing until the task
  has changed code.
- Lookup, at the start of the task:
  1. The current repo has `.agents/skills/verify-*/SKILL.md`: use it.
  2. Otherwise find the main checkout from `git rev-parse --git-common-dir`,
     so a worktree such as `~/.t3/worktrees/otis/fix-x` resolves to
     `~/Devel/otis`.
  3. Read `<main checkout's parent>/*/.agents/skills/verify-*/apps`. A
     companion matches when one of its lines resolves to the main checkout;
     that line's name is the app.
  4. No match or several: ask the user with the question tool for the
     companion path. Nothing remembers the answer.
- Running: read the companion's `verify-<app>/SKILL.md` and follow it. Every
  helper call gets `APP_<NAME>=<current checkout>`, so the run drives and
  diffs this checkout, not the main one.
- One run per companion: before anything touches the companion, `mkdir` the lock
  `<companion>/.agents/skills/verify-<app>/.cache/with-verification.lock`
  and write the current checkout path into it; remove it after cleanup. If
  it exists, stop and name the checkout that holds it, and the folder to
  delete when that run is gone. The lock also covers a branch switch in the
  companion. A run started inside the companion does not
  check the lock.
- Map drift: the verify skill updates its map before driving. In a
  companion, ask with the question tool: report only (drive what the map
  still describes, list the rest as not verified, for a later
  `/maintain-verify-<app>` from the companion), or update now (a branch in a
  clean companion, map update, drive, draft PR, then back to the companion's
  previous branch).
- The repo's own `AGENTS.md` keeps steering verification without the
  trigger; this skill changes nothing there.

## Out of scope

- A remembered list of companion paths.
- Parallel runs against one companion.
- A companion mode for `/create-project-local-stack`.

## Verification

- `./sync --home <temp>` installs the skill to the four tools, and the tests
  pass.
- In a scratch app repo, a worktree of it and a sibling companion, the lookup
  finds the companion from both checkouts, and asks when there is none or
  two.
- The lock blocks a second run and names the holder.
- The trigger and a full verified task are proven only in a real session.
