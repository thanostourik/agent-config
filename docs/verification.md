# Verification

The verification skills let an agent run the real app and prove that its change works
before it calls the work done. They install to Claude Code, Codex, Grok, and Cursor, not
to OpenCode.

## Set up a project

Both setup skills are manual. Run them from the project's root, each in a new session.

| Skill | What it writes |
|---|---|
| `create-project-local-stack` | `local-stack/`: one command that starts everything the app needs. Each copy is isolated from the others, and shared services are replaced by fakes. Developers run it next to their IDE. Agents run many copies at once to check their work. |
| `create-project-verification-skill` | The project's own `verify-<app>` skill: one bash recipe per feature, the runner `bin/verify`, and a section in the project's `AGENTS.md`. When `local-stack/` exists, the skill starts the app through it. |

`/create-project-verification-skill quick` writes one recipe instead of one per feature.
The other recipes are added later, as changes touch features that have none.

If the project already has a verification skill, `create-project-verification-skill`
stops and asks whether to replace or upgrade it.

## Use it every day

After setup, the project has its own skill, `verify-<app>`. Agents run it by themselves
before they call work done. You can also ask for it by name. It drives the app through
`bin/verify`:

| Command | What it runs |
|---|---|
| `bin/verify affected` | The features whose recipe the change edited, and the features that check the code it edited: it finds the function each changed line sits in, and the recipes that cite that function. It lists the features that cite a caller of that code or share a changed file, and the agent drives by name the ones the change affects. |
| `bin/verify all` | Every feature. |
| `bin/verify all --failed` | Only the features that did not pass last time, plus the ones whose recipe changed since and the ones that check the code changed since. |

All runs on the machine share one queue. The queue keeps 20% of the memory free.

In any repository, you can add "with verify" to a request. The `with-verification` skill
then finds the project's `verify-<app>` skill and runs it before the agent calls the work
done.

## Keep up with this repository

When the generator here changes, run `./sync --apply`. Then run
`/maintain-project-verification-skill` in each project. A script copies the new shipped
files into the project and converts old recipes. The agent does only what the script
lists.

## Companion QA repository

Some app repositories must not contain agent files, for example a client's repository.
Verification still works there through a companion QA repository. That is a second
repository, next to the app checkout, that holds the verification skill and its recipes.

1. Create a Git repository beside the app checkout, for example `my-app-qa/` beside
   `my-app/`.
2. Open an agent session in `my-app-qa/` and run `/create-project-verification-skill`.
   Give each app checkout's path when it asks.
3. The generator writes the verification skill and the file
   `.agents/skills/verify-<app>/apps`. That file lists each app's name and the path to
   its checkout, relative to the QA repository's root, for example `my-app ../my-app`.
   All agent files stay in the QA repository.
4. In the app repository, add "with verify" to a coding request. The `with-verification`
   skill finds the companion and verifies the checkout you are changing. This works in
   worktrees too. If the app repository has its own `verify-<app>` skill, that one is
   used instead.
5. After the generator here changes, run `/maintain-project-verification-skill` from the
   QA repository.

To also keep attribution off the client's PRs, see
[Hide agent work from clients](configuration.md#hide-agent-work-from-clients).
