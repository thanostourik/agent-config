---
name: with-verification
metadata:
  harness: "claude-code, codex, grok, cursor"
description: Use when the user adds "with verify" or "with verification" to a task as an instruction to verify it with the project's verify skill. Not when verification is only the topic.
---

# with-verification

The user wants this task verified with the project's `verify-<app>` skill
before you call it done. That skill lives either in this repository or in a
**companion repo**: a separate git repo next to the app checkouts that holds
only the agent files, with an `apps` file that lists them.

Find the skill before you change anything, so a missing one shows up early.
Drive nothing until the task has changed code.

## 1. Find the verify skill

If this repository has `.agents/skills/verify-*/SKILL.md`, use that skill as
its own instructions say and skip the rest of this file.

Otherwise look for a companion next to the main checkout. In a worktree, the
main checkout is the original clone, not the worktree's own folder:

```bash
main=$(cd "$(git rev-parse --path-format=absolute --git-common-dir)/.." && pwd -P)
for apps in "$(dirname "$main")"/*/.agents/skills/verify-*/apps; do
  [[ -f "$apps" ]] || continue
  companion=$(cd "$(dirname "$apps")/../../.." && pwd -P)
  while read -r name path; do
    [[ -n "$name" && "$(cd "$companion" && cd "$path" 2>/dev/null && pwd -P)" == "$main" ]] && echo "$name $(dirname "$apps")"
  done < "$apps"
done
```

Each output line is an app name and its skill folder. With no line, or more
than one, ask the user with your question tool which companion and app to
use.

Below, `<skill>` is that skill folder and `APP_<NAME>` is the app name in
upper case with `-` as `_`, such as `APP_OTIS`.

## 2. Verify from the companion

All checkouts of the app share the companion's `.cache/` and its branch, so
two runs at once break each other. When the task's code is done, take the
lock before anything else in the companion:

```bash
mkdir -p <skill>/.cache && mkdir <skill>/.cache/with-verification.lock && git rev-parse --show-toplevel > <skill>/.cache/with-verification.lock/holder
```

If `mkdir` fails, stop and tell the user which checkout `holder` names, and
that they can delete `<skill>/.cache/with-verification.lock` when that run is
gone. Delete the lock yourself as the last step, also when the run fails.

Then read `<skill>/SKILL.md` and follow it. Its paths are relative to
`<skill>`. The change to verify is this checkout's diff against its base.

Give every call of a helper in `<skill>/bin/` this checkout, or it builds and
diffs the main checkout:

```bash
APP_OTIS="$(git rev-parse --show-toplevel)" <skill>/bin/drive.sh search
```

### Map changes

The skill updates its feature map before driving when the change adds,
alters, or removes behavior. In a companion, that map is in another repo. Ask
the user with your question tool:

- **Report only:** leave the map as it is. Drive the selected features the
  map still describes, and list the others as not verified, so the user can
  run `/maintain-verify-<app>` from the companion later.
- **Update now:** with a clean companion, create a branch there, update the
  map as the skill says, and drive. Then commit, push, open a draft PR in the
  companion, and switch the companion back to the branch it was on. A
  companion with uncommitted changes stops this choice: tell the user.

Report as the skill's Report section says, and add the companion PR link when
there is one.
