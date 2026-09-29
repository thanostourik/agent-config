---
name: create-project-verification-skill
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Generate the project's own verification skills, committed in the repo, so every developer's agent (Claude Code, Codex, Grok, Cursor) can drive the real app and prove its work. Use for /create-project-verification-skill or \"set up verification for this repo\"."
disable-model-invocation: true
---

# Create a project verification skill

Every serious project needs a scripted way to drive the real app and prove behavior: launch it, exercise a feature the way a user would, and capture evidence. This skill generates that as two project skills committed in the repo, so every developer's agent gets them without any global setup. You write the output for the next agent, not for a human: it will be read cold, mid-task, by an agent that has never seen the app.

When you post a message anyway, you may add progress lines such as `setup: sign-in works`, `map 3/15: projects.md written`, or `drive 7/16: projects — pass`. Never change how you split, delegate, or order work to produce them, and never add a turn just to report.

You write:

```
.agents/skills/verify-<app>/                    the verification skill
  SKILL.md
  features/README.md, features/<feature>.md     the feature map
  bin/                                          helpers
  .gitignore                                    ignores .cache/
  .cache/                                       everything a run writes
.agents/skills/maintain-verify-<app>/           the full audit, run by hand
  SKILL.md
  agents/openai.yaml
.claude/skills/verify-<app>/SKILL.md            stub for Claude Code
.claude/skills/maintain-verify-<app>/SKILL.md   stub for Claude Code
```

`<app>` is a short lowercase name for the app. Codex, Cursor, Grok and OpenCode read `.agents/skills/`; Claude Code reads only `.claude/skills/`. The stubs exist for Claude Code and are invisible duplicates elsewhere. Never use symlinks: Windows checkouts turn them into plain files.

## 1. Interview the repo, not the user

Answer these from the codebase and only ask the user what you cannot observe:

- **Surface:** what does a user actually touch? A web UI, a CLI/TUI, a desktop app, an API, a mobile app, firmware, a library? A repo can have several; pick the primary one and note the rest.
- **Run:** how does the app start locally? Prefer the repo's own documented dev command (package scripts, Makefile, README quickstart). Note ports, env vars, seed data, auth.
- **Depends on:** what must run next to it: databases, auth servers, other services. Read the README and any docs it links (a `PLATFORM.md` naming sibling repos, compose files). For a service that lives in another repo, learn how to start it from that repo; ask the user where its checkout is if you need to read it.
- **Side effects of starting:** launch the app once, then check `git status` and the developer's config files. Dev tools often rewrite local env files or generate files on start. Also create `.agents/skills/verify-<app>/.cache/`, write a file into it while a page is open, and check that the page does not reload; if it does, stop and ask the user.
- **Observe:** what evidence can be captured? Screenshots, accessibility snapshots, terminal transcripts, response bodies, logs, exit codes, DB state.

If the checkout doesn't build or start as-is, fix that first (or report it precisely) before generating; a skill written against a broken base teaches wrong steps. When an irrelevant missing asset blocks startup, the generated skill may create it, clearly marked as verification scaffolding, and remove it in cleanup.

## 2. Decide once, write one path

Decide these now, with the user where needed, and write only the outcome into the skill. The generated skill has no "if the project has X" branches: the one question it asks at run time is whether a healthy instance is already running.

- **Isolation.** A drive never writes to the developer's persistent data and never disturbs what the developer is running. Pick one:
  1. the project already has a disposable environment (for example a `dev_setup/dev.sh` that runs Docker Compose under a per-branch project name): use it, and let drives write freely;
  2. propose creating one, show the user the files, and create it only if they approve;
  3. drives stay read-only, and the skill lists every control that writes and must not be used.
- **Drive tool.** Every step must be a command an agent runs from a shell, so it works the same in every agent:
  - web UI: Playwright's browser CLI, from the project's own Playwright (built in since 1.63; add `playwright` as a pinned dev dependency if the project has none, or use a pinned `npx playwright@<version>` if the repo forbids new dependencies). Ship `bin/pw.sh`, which runs `npx playwright cli -s=<app> "$@"` with `PLAYWRIGHT_MCP_OUTPUT_DIR` set to the skill's `.cache/cli/`; agents' shells don't keep environment variables between commands, so the wrapper sets it every time. Target elements with role locators such as `"getByRole('button', { name: 'Save' })"`.
  - API: `curl` with the exact method, URL, headers, and body.
  - CLI/TUI: the command itself, or a tmux session for interactive screens.
  - anything else: the tool the repo already uses.

  Reuse an existing harness (a sign-in helper, a seeding script) where it fits. Write a script only where a command cannot do the job, such as a sign-in that needs a library: have it save the browser session (Playwright `storageState`) under `.cache/`, and load it with `.agents/skills/verify-<app>/bin/pw.sh state-load <file>`. Never write one script per feature: the steps live in the feature files.

## 3. Write `verify-<app>`

`.agents/skills/verify-<app>/SKILL.md` starts with YAML frontmatter: `name: verify-<app>` and a `description` that names the app and the surface, and says to use it after changing that surface, to update the feature map and prove the change works before calling the work done. Without frontmatter the skill never registers. Then these sections, in this order, each grounded in what the interview found (no placeholders left):

- **Pick features:** read `features/README.md` and map the change to the user-facing features it affects: existing features it alters and new ones it adds. State each and why in one line. A change with no user-visible effect is not driven; say so instead.
- **Update the map first:** before driving, make the map describe the app as it is after the change. A new feature gets a new feature file in the shape `features/README.md` describes, and an index entry. An altered feature gets its file edited, or a new one if it was never mapped. A removed feature's file and entry are deleted. This is part of the change, like updating tests next to the code, so it is in scope even when the request did not mention it. Then drive each picked feature file once, whole.
- **Isolation:** the option chosen in step 2, and what it means for drives. For read-only drives, the list of controls that write and must not be used.
- **Launch:** the exact commands that start the app and whatever it depends on, and how to tell it's ready (a log line, a port answering, a prompt). Attach to a healthy instance when doctor finds one; otherwise start one. Launch backs up any file that starting rewrites and restores it once the app is up; it records any file that starting generates, for cleanup. For a short-lived CLI or TUI there is no server to keep alive: launch means build once, then start each drive in its own isolated session.
- **Doctor:** one read-only check that answers "is this instance worth driving?": process up, right version/build, port owned by the expected process, auth valid, dependencies answering. The agent runs it first and whenever anything looks off.
- **Drive:** how to use the drive tool on this app: session name, sign-in, viewport, stable handles (roles and accessible names, data attributes, prompt strings, route paths) over coordinates and tab order.
- **When a drive fails:** a feature file holds two kinds of content: how to drive (commands, locators, waits) and what should happen (expected results). Fix how to drive only when the user-visible result stays the same, for example an ambiguous locator for an unchanged button, and re-drive that step. Never change an expected result to make a drive pass. For a feature the change touched, the expected results were written from the request before driving, so a failure means the code is wrong: fix the code. For a feature the change did not touch, report the mismatch (the map expects X, the app does Y) and leave the file alone; the full audit settles it.
- **Evidence:** everything a run writes (evidence, CLI files, sessions, pids, logs) goes under `.agents/skills/verify-<app>/.cache/`, gitignored, the same path in every project and never outside the repo; proof for a feature goes to `.cache/evidence/<feature>/`. Proof standards: exercise the real user path, not internal setters or test-only endpoints; capture the action and the resulting state, not just the final screen; verify side effects (files written, rows inserted, messages sent) alongside what's visible; mocks only where a production boundary already isolates the external system. When the safe path is a dry-run or test mode, verify what it actually skips by observing (files, network, git refs) rather than trusting its name.
- **Report:** one line per driven feature: the result and the path of the file that shows it, relative to the repo root; for a failure, the failing step's screenshot. For example `trash — fail at "empty to trash" — .agents/skills/verify-<app>/.cache/evidence/trash/empty.png`. A feature that could not be reached gets its missing prerequisite instead.
- **Cleanup:** tear down what the run started. Never kill by process name; kill what you started, and leave running what was running before. Restore what launch backed up and remove what starting generated. Cleanup never deletes evidence.
- **Helpers:** every script in `bin/`, what it does and how to call it. Scripts are bash and executable; on Windows the agent runs inside WSL.

## 4. Map every feature

Create `features/README.md` plus one file per user-facing feature the app has: every screen, route group, command, or endpoint group a user reaches, found from routes, navigation, commands, and docs. `features/README.md` holds the baseline every feature starts from, the driving conventions, the feature file shape below, and the index; follow [`references/feature-map-example/`](references/feature-map-example/).

Each feature file starts with an H1 and one paragraph describing the user-visible behavior, then exactly four H2s in this order:

1. `Sub-features`: short IDs, one line per behavior.
2. `How to get to it (user POV)`: every entry point a user has.
3. `Driving it with <tool>`: `Preconditions:`, then labeled bullets that pair each user action with an exact command and its observable result, ending with a proof step.
4. `Gotchas`: traps that waste or invalidate a run.

Keep code paths out of the map: the agent maps a change to features by reasoning, and the audit reads the source. A proof that drives one convenient entry point is incomplete when the file lists others.

## 5. Write `maintain-verify-<app>` and the stubs

Copy [`references/maintain-verify.md`](references/maintain-verify.md) to `.agents/skills/maintain-verify-<app>/SKILL.md` and [`references/maintain-verify-openai.yaml`](references/maintain-verify-openai.yaml) to `.agents/skills/maintain-verify-<app>/agents/openai.yaml`, and replace `<app>`. Adjust only what this project needs (for example, how its PRs are opened).

Write the two Claude Code stubs from [`references/claude-stub.md`](references/claude-stub.md). Their `name` and `description` must match the real skills exactly, and the maintain stub also carries `disable-model-invocation: true`.

## 6. Point the project's instructions at it

Add this line to the project's `AGENTS.md`, inside an existing section about verification or testing, or under a new `## Verification` section:

```
Before calling user-facing work done, update its feature map entry and verify it with the `verify-<app>` skill.
```

## 7. Prove it

Run the Pass from `maintain-verify-<app>` on what you just wrote: every feature file checked against the source and driven live, under the Pass's rules. A generated skill that was never executed is a draft, not a deliverable.

## 8. Hand over

Commit everything following the repo's own branch and commit conventions. Report per `verify-<app>`'s Report section, plus what isolation option was chosen, that `/maintain-verify-<app>` is the project's full audit for any developer to run now and then, and that `/maintain-project-verification-skill` brings the project's skills up to date when this generator changes.
