---
name: maintain-project-verification-skill
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Use for /maintain-project-verification-skill, or when asked to update a repo's verify skill to the current generator, including skills from before recipes were scripts."
disable-model-invocation: true
---

# Maintain a project verification skill

`create-project-verification-skill` generated the project's `verify-<app>` skill. The
shipped files (`SKILL.md`, `FULL.md` and the files the generator's "What you write" marks
`unchanged`) come from the generator. Everything project-specific sits in `PROJECT.md`, the
other `bin/` helpers and `features/`. So an upgrade is mostly a copy, and a script does it.
An upgrade does not record what no recipe covers yet: `/verify-<app> full` does that.

When you need me to make a choice before you can continue, use your question tool if you
have one, or ask in your reply if you don't. If the question gets no answer, ask again in
your reply and wait. Do not answer it yourself.

`<generator>` below is `../create-project-verification-skill/` next to this skill's folder.

## 1. Run the upgrade

From the repository root, on a branch as the repo's conventions say:

```bash
<generator>/references/upgrade
```

With several `verify-*` skills, ask which one and pass its folder. The script:

- copies the shipped files;
- converts Markdown recipes into `features/<feature>.sh` scripts;
- removes the old runner, recorder and `maintain-verify-<app>` skill;
- keeps the old files it replaced under `.cache/upgrade/` (gitignored, so they stay local);
- ends with the list of what is left for you.

It is safe to run again. Commit its result before anything else.

## 2. Do what it lists

Do the items the script lists, in the order it lists them, and nothing else. An item with
no entry below is done as its line says. Two more items, marked "every upgrade", are
checked even when the script does not list them. Do them after the `launch.sh` items.

- **`PROJECT.md`**: write it from `.cache/upgrade/SKILL.md` and `.cache/upgrade/README.md`,
  with the sections step 3 of `<generator>/SKILL.md` names.
  - Keep every project fact: isolation, launch and cleanup behavior, sign-in, baseline
    data, helper calls, driving conventions that are specific to this project, gotchas.
  - Drop the rules the shipped `SKILL.md` already states, and everything about the old
    runner, recorders, contract maps and maintenance modes.
- **`launch.sh` idempotent**: when the run's environment is already up, a second call
  rebuilds and restarts only the app, and recreates nothing when the source is unchanged.
  `doctor.sh` accepts the result. Keep the ownership record of `launch.sh` and its recovery
  of an interrupted launch.
- **The project's stack** (every upgrade): the repo may have an environment that
  `<generator>/references/lifecycle.md` would pick as isolated and disposable, such as
  `local-stack/stack`, while `launch.sh` builds its own. Then:
  - Make `launch.sh` and `cleanup.sh` use the stack as `lifecycle.md` says. `launch.sh`
    still starts the app in both modes, `VERIFY_APP=dev` and `VERIFY_APP=build`, as step 3
    of `<generator>/SKILL.md` says.
  - Delete the code the stack replaces: its own Compose project, port picking and source
    copies.
  - Isolation is the stack's job from then on, so a leak found later is fixed in the stack.
  - When the stack cannot start something the recipes need, stop and name it.
- **Helper waits and errors** (every upgrade): read each `bin/` helper.
  - Make its waits and error output follow the "Waits and errors" rules of the new
    `SKILL.md`, including how a helper that restarts the app waits for a real page.
  - Check that a helper that inserts rows directly follows the fixture rule in the new
    `SKILL.md`'s Data section, against the seed data or the dump.
  - `verify lint` checks only recipes, so this is the only check helpers get.
- **References to the removed scripts**: remove them. A helper that reads the old runner's
  files, such as an `observe.sh` reading `.cache/drive/<feature>/steps/`, reads
  `$VERIFY_DIR/log` and `$EVIDENCE` instead.
- **`# touches:`**: start subagents (in T3 Code `delegate_task` with `mode: "async"`,
  otherwise your tool's own subagent), each with up to 6 features and this prompt:

  ```
  For each feature recipe below in .agents/skills/verify-<app>/features/, list the source
  files its behavior lives in: the handlers, controllers, components, services, queries and
  migrations it exercises, as repository paths (<app>/<path> in a companion repo). Read the
  recipe, grep for the routes, commands or screens it drives, and follow them into the
  source. Files only, never folders; leave out files every feature only passes through, but
  keep a file that holds this feature's routes or handlers. Write the list on the recipe's
  one '# touches:' line, space-separated, and change nothing else. Run
  .agents/skills/verify-<app>/bin/verify lint <features> and return its last line.
  Features: <feature> <feature> ...
  ```

- **`entrypoints.sh`** and **`actions.sh`**: write them as step 3 of `<generator>/SKILL.md`
  says.
- **`AGENTS.md`**: write its `## Verification` section (and the one in `CLAUDE.md`) from
  `<generator>/references/agents-verification.md`.
- **Features the script could not convert**: run `bin/areas > .cache/areas.txt`. Then send
  each area that holds such a feature to a recorder, as the Recorders section of the new
  `FULL.md` says, after step 3's `bin/verify up`. The recorder keeps the area's existing
  recipes.

## 3. Prove it

Run `bin/verify lint`, then `bin/verify up` twice: the second call must reuse the
environment. Then drive only what the upgrade can break. Never run `bin/verify all`: an
upgrade mostly changes rules, and a rule change breaks no feature.

- Run `bin/verify affected --base <the commit before step 1's commit>`. It drives every
  converted or changed recipe and every feature that uses a changed helper. Changes to
  `SKILL.md`, `PROJECT.md` and the other rules select nothing.
- When `bin/verify`, `bin/lib.sh`, `launch.sh`, `doctor.sh` or `cleanup.sh` changed, also
  drive a few features by name, as a smoke test of the runner and the environment: one
  plain feature, one marked `# alone`, and one marked `# shares`, each when one exists.
- When neither selects a feature, drive nothing: `bin/verify lint` was the check.

Fix the environment yourself when `doctor.sh` stops the run.

Repair two things before the PR:

- A driven feature that fails.
- An `# expects:` line marked not driven for a reason the new rules do not allow. Recipes
  keep reasons that were written under older rules. `bin/verify uncovered` ends with every
  such reason and its features. Check each against the Header rules in the new
  `SKILL.md`'s Recipes section.

To repair them:

1. Run `bin/areas > .cache/areas.txt` when it is missing.
2. Start one recorder for each area that holds failing features or a reason that does not
   hold, all at once, with their summary lines and those reasons. A recorder repairs the
   recipe, or marks a product defect `# known failure:`, and gives each line whose reason
   does not hold a step.
3. Drive the features the recorders changed, together in one `bin/verify <feature>...`.
   Send each feature that fails there back to a recorder. Repeat until each passes or fails
   at a known failure.

Features the upgrade cannot break are not driven, and their old failures are not this
skill's work. Then run `bin/verify uncovered` and `bin/verify down`.

## 4. Ship and report

Commit and open one PR as the repository's conventions say. Report:

- what the script changed, and what you did from its list;
- each drive with its command, number of features and time;
- the features the recorders repaired, the expectations that now have a step, and each
  known failure.

End the report with exactly one of these lines. When `bin/verify uncovered` listed anything
as not covered, fill in the count: "<n> entry points and actions have no recipe. Run
`/verify-<app> full` to record them." Otherwise: "Recipes are up to date. Nothing else to
run." Mention `full` nowhere else in the report: the user reads any mention as a request to
run it.

Then delete `.cache/upgrade/`. A later upgrade on this machine would otherwise take its old
files for its own and list their work again.
