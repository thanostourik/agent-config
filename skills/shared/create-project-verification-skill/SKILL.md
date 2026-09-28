---
name: create-project-verification-skill
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Generate the project's own verification skills, committed in the repo, so every developer's agent (Claude Code, Codex, Grok, Cursor) can drive the real app and prove its work. Use for /create-project-verification-skill or \"set up verification for this repo\"."
disable-model-invocation: true
---

# Create a project verification skill

Every serious project needs a scripted way to drive the real app and prove behavior: launch it, exercise a feature the way a user would, and capture evidence. This skill generates that as two project skills committed in the repo, so every developer's agent gets them without any global setup. You write the output for the next agent, not for a human: it will be read cold, mid-task, by an agent that has never seen the app.

You write:

```
.agents/skills/verify-<app>/                    the verification skill
  SKILL.md
  features/README.md, features/<feature>.md     the feature map
  bin/                                          only if a helper is needed
  .gitignore                                    evidence/ and run state
.agents/skills/maintain-verify-<app>/SKILL.md   full audit of the map, run by hand
.claude/skills/verify-<app>/SKILL.md            stub for Claude Code
.claude/skills/maintain-verify-<app>/SKILL.md   stub for Claude Code
```

`<app>` is a short lowercase name for the app. Codex, Cursor, Grok and OpenCode read `.agents/skills/`; Claude Code reads only `.claude/skills/`. The stubs exist for Claude Code and are invisible duplicates elsewhere. Never use symlinks: Windows checkouts turn them into plain files.

## 1. Interview the repo, not the user

Answer these from the codebase and only ask the user what you cannot observe:

- **Surface:** what does a user actually touch? A web UI, a CLI/TUI, a desktop app, an API, a mobile app, firmware, a library? A repo can have several; pick the primary one and note the rest.
- **Run:** how does the app start locally? Prefer the repo's own documented dev command (package scripts, Makefile, README quickstart). Note ports, env vars, seed data, auth.
- **Depends on:** what must run next to it: databases, auth servers, other services. Read the README and any docs it links (a `PLATFORM.md` naming sibling repos, compose files). For a service that lives in another repo, learn how to start it from that repo; ask the user where its checkout is if you need to read it.
- **Drive:** how can an agent interact with it from a shell? See step 2.
- **Observe:** what evidence can be captured? Screenshots, accessibility snapshots, terminal transcripts, response bodies, logs, exit codes, DB state.
- **Isolate:** where does data go when a drive writes? See step 2.

If the checkout doesn't build or start as-is, fix that first (or report it precisely) before generating; a skill written against a broken base teaches wrong steps. When an irrelevant missing asset blocks startup, the generated skill may create it, clearly marked as verification scaffolding, and remove it in cleanup.

## 2. Decide once, write one path

Decide these now, with the user where needed, and write only the outcome into the skill. The generated skill has no "if the project has X" branches: the one question it asks at run time is whether a healthy instance is already running.

- **Isolation.** A drive never writes to the developer's persistent data and never disturbs what the developer is running. Pick one:
  1. the project already has a disposable environment (for example a `dev_setup/dev.sh` that runs Docker Compose under a per-branch project name): use it, and let drives write freely;
  2. propose creating one, show the user the files, and create it only if they approve;
  3. drives stay read-only, and the skill lists every control that writes and must not be used.
- **Drive tool.** Every step must be a command an agent runs from a shell, so it works the same in every agent:
  - web UI: Playwright's browser CLI, `npx playwright cli -s=<app> <command>`, from the project's own Playwright (built in since 1.63; add `playwright` as a pinned dev dependency if the project has none). Target elements with role locators such as `"getByRole('button', { name: 'Save' })"`. The CLI writes `.playwright-cli/` in the working directory; gitignore it or name the directory.
  - API: `curl` with the exact method, URL, headers, and body.
  - CLI/TUI: the command itself, or a tmux session for interactive screens.
  - anything else: the tool the repo already uses.

  Reuse an existing harness (a sign-in helper, a seeding script) where it fits. Write a script only where a command cannot do the job, such as a sign-in that needs a library: have it save the browser session (Playwright `storageState`) to the skill's run folder, and load it with `npx playwright cli -s=<app> state-load <file>`. Never write one script per feature: the steps live in the feature files.
- **Launch.** Attach to a healthy instance when doctor finds one; otherwise start it. Only ever stop what this skill started.

## 3. Write `verify-<app>`

`.agents/skills/verify-<app>/SKILL.md` starts with YAML frontmatter: `name: verify-<app>` and a `description` that names the app and the surface, and says to use it after changing that surface, to update the feature map and prove the change works before calling the work done. Without frontmatter the skill never registers. Then these sections, each grounded in what the interview found (no placeholders left):

- **Pick features:** read `features/README.md` and map the change to the user-facing features it affects: existing features it alters and new ones it adds. State each and why in one line. A change with no user-visible effect is not driven; say so instead.
- **Update the map first:** before driving, make the map describe the app as it is after the change. A new feature gets a new feature file in the shape `features/README.md` describes, and an index entry. An altered feature gets its file edited, or a new one if it was never mapped. A removed feature's file and entry are deleted. This is part of the change, like updating tests next to the code, so it is in scope even when the request did not mention it. Then drive each picked feature file once, whole.
- **Launch:** the exact commands that start the app and whatever it depends on, and how to tell it's ready (a log line, a port answering, a prompt). For a short-lived CLI or TUI there is no server to keep alive: launch means build once, then start each drive in its own isolated session.
- **Doctor:** one read-only check that answers "is this instance worth driving?": process up, right version/build, port owned by the expected process, auth valid, dependencies answering. The agent runs it first and whenever anything looks off.
- **Drive:** how to use the drive tool on this app: session name, sign-in, viewport, stable handles (roles and accessible names, data attributes, prompt strings, route paths) over coordinates and tab order.
- **Evidence:** what to capture for a proof and where it goes (`evidence/<feature>/` inside the skill, gitignored). Proof standards: exercise the real user path, not internal setters or test-only endpoints; capture the action and the resulting state, not just the final screen; verify side effects (files written, rows inserted, messages sent) alongside what's visible; mocks only where a production boundary already isolates the external system. When the safe path is a dry-run or test mode, verify what it actually skips by observing (files, network, git refs) rather than trusting its name.
- **Cleanup:** how to tear down what the run started. Never kill by process name; kill what you started. Leave running what was running before. Launch the app once and check `git status` and the developer's config files afterwards: dev tools often rewrite local env files or generate files on start. Launch backs up what gets rewritten and restores it, and cleanup removes what the run generated. Cleanup never deletes evidence.
- **Helpers:** any script the skill ships is bash, executable, and its invocation is shown in the skill body. A helper the reader has to reverse-engineer is not a helper. Say that on Windows the agent must run inside WSL.

## 4. Seed the feature map

Create `features/README.md` plus one file per user-facing feature the app has: every screen, route group, command, or endpoint group a user reaches, found from routes, navigation, commands, and docs. Follow the shape in [`references/feature-map-example/`](references/feature-map-example/): a README index with baseline preconditions, driving conventions, proof rules, and the feature list, then one file per feature. Each file answers, from the user's point of view: what the feature is, how to reach it, how to drive it with exact commands, and what observable end state proves it works. The four H2s are `Sub-features`, `How to get to it (user POV)`, `Driving it with <tool>`, and `Gotchas`. Keep code paths out of the map: the agent maps a change to features by reasoning, and the full audit reads the source. The map is the repo's maintained verification source; a proof that drives one convenient entry point is incomplete when the map lists others.

## 5. Write `maintain-verify-<app>` and the stubs

Copy [`references/maintain-verify.md`](references/maintain-verify.md) to `.agents/skills/maintain-verify-<app>/SKILL.md` and replace `<app>`. Adjust only what this project needs (for example, how its PRs are opened). It is manual-only: copy this skill's own `agents/openai.yaml` next to it, so Codex doesn't start it on its own either.

Write the two Claude Code stubs from [`references/claude-stub.md`](references/claude-stub.md). Their `name` and `description` must match the real skills exactly, and the maintain stub also carries `disable-model-invocation: true`.

## 6. Point the project's instructions at it

Add this line to the project's `AGENTS.md`, inside an existing section about verification or testing, or under a new `## Verification` section:

```
Before calling user-facing work done, update its feature map entry and verify it with the `verify-<app>` skill.
```

If `CLAUDE.md` exists and does not import `AGENTS.md`, add the same line there.

## 7. Prove the generated skill before handing it over

Run the full pass from `maintain-verify-<app>` (its steps 1 to 5) on what you just wrote: every feature file checked against the source and driven live, fixes made under the same rules. Skip its step 6; the handover commits everything together. A feature that can't be reached is reported with its missing prerequisite, like the pass says. After the final cleanup, confirm the evidence still exists at the named location: a cleanup that eats the proof fails this step. Run the generated cleanup after every failed iteration too, so broken attempts don't strand processes and ports. A generated skill that was never executed is a draft, not a deliverable.

## 8. Hand over

Commit the skills, the stubs, and the instruction line following the repo's own branch and commit conventions. Tell the user which features the map covers, which were driven and which were unreachable (and why), what isolation option was chosen, that `/maintain-verify-<app>` is the project's full audit for any developer to run now and then, and that `/maintain-project-verification-skill` brings the project's skills up to date when this generator changes.
