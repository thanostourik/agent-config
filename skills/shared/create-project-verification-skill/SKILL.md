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
.agents/skills/maintain-verify-<app>/           map maintenance, optional full audit
  SKILL.md
  agents/openai.yaml
.claude/skills/verify-<app>/SKILL.md            stub for Claude Code
.claude/skills/maintain-verify-<app>/SKILL.md   stub for Claude Code
```

`<app>` is a short lowercase name for the app. Codex, Cursor, Grok and OpenCode read `.agents/skills/`; Claude Code reads only `.claude/skills/`. The stubs exist for Claude Code and are invisible duplicates elsewhere. Never use symlinks: Windows checkouts turn them into plain files.

From initial discovery through the final audit, helper agents may read source in small concurrent batches, grouping related features per reader. They return findings and proposed recipes, never edit files or drive the app. You integrate their findings and own all driving, with only one driver using the environment at a time. An environment already being driven by another session is unavailable; a different browser session or record prefix does not isolate shared data. Do not create one agent per feature by default.

## 1. Interview the repo, not the user

Answer these from the codebase and only ask the user what you cannot observe:

- **Surface:** what does a user actually touch? A web UI, a CLI/TUI, a desktop app, an API, a mobile app, firmware, a library? A repo can have several; pick the primary one and note the rest.
- **Run:** how does the app start locally? Prefer the repo's own documented dev command (package scripts, Makefile, README quickstart). Note ports, env vars, seed data, auth.
- **Depends on:** what must run next to it: databases, auth servers, other services. Read the README and any docs it links (a `PLATFORM.md` naming sibling repos, compose files). For a service that lives in another repo, learn how to start it from that repo; ask the user where its checkout is if you need to read it.
- **Side effects of starting:** inspect startup commands and configuration before launching. Identify files, data, processes and external systems startup may change. After choosing isolation and cleanup in step 2, launch once and compare against the recorded original state. Where the app has a watched page, write into `.agents/skills/verify-<app>/.cache/` while it is open and check that it does not reload; if it does, clean up and ask the user.
- **Observe:** what evidence can be captured? Screenshots, accessibility snapshots, terminal transcripts, response bodies, logs, exit codes, DB state.

If the checkout doesn't build or start as-is, fix that first (or report it precisely) before generating; a skill written against a broken base teaches wrong steps. When an irrelevant missing asset blocks startup, the generated skill may create it, clearly marked as verification scaffolding, and remove it in cleanup.

## 2. Decide once, write one path

Decide these now, with the user where needed, and write the project's concrete path into the skill. At run time, check whether an existing instance is healthy, isolated and safe to reuse; health alone is not enough.

- **Isolation.** A drive never writes to the developer's persistent data and never disturbs what the developer is running. Pick one:
  1. the project already supports disposable environments: use that mechanism, with explicit ownership of the run's resources and data;
  2. propose creating one, show the user the files, and create it only if they approve;
  3. drives stay read-only, and the skill lists every control that writes and must not be used.

  Before startup or the first request, trace where startup and driving can send writes, including dependencies, gateways, storage, email and background jobs. Configure disposable destinations or disable the affected operations, then verify the effective configuration. A local URL, branch name or separate container project does not prove isolation. Check shared ports and resources too; if the environment cannot coexist with another run, require sequential use. Record any success paths made unreachable by isolation.
- **Lifecycle.** Record what exists before the run and how to restore it. Register each resource as it is created, so cleanup also works after partial startup. Every run, including interview probes and ordinary verification, must restore that original state on success, failure or interruption. Remove its temporary data, sessions, files, databases, containers, volumes and networks where applicable; stop its processes; restore changed configuration. Preserve pre-existing resources and data, and keep evidence. Generate exact cleanup commands for this project, with failure handling in lifecycle helpers. Do not use a routine destructive reset before verification. If a previous run was abruptly killed, recover only resources its ownership record proves it left behind; never wipe an environment to hide missing cleanup.
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
- **Launch:** the exact commands that start the app and its dependencies, and how to tell each is ready. Reuse an instance only when doctor confirms health, isolation and exclusive use for driving; record that it pre-existed so cleanup preserves it. Otherwise create the run's disposable resources and baseline without resetting existing ones. Back up files startup rewrites and record resources as they are created, before waiting for readiness. If startup fails, clean up what already started. For a short-lived CLI or TUI, launch means build once, then start each drive in its own isolated session.
- **Doctor:** one read-only check that answers "is this instance worth driving?": process up, right version/build and checkout, expected resource ownership, auth valid, baseline data present, dependencies answering and effective destinations isolated. Run it before the first drive and after a failed drive. A healthy process with the wrong data or configuration is not ready.
- **Drive:** how to use the drive tool on this app: session name, sign-in, viewport, stable handles (roles and accessible names, data attributes, prompt strings, route paths) over coordinates and tab order. One agent owns all driving of the shared environment; source readers never operate it.
- **When a drive fails:** record the action, expected result and its basis (the request, documented contract or established test), actual result, and relevant environment conditions. Diagnose before deciding what to fix:
  - **Driving instructions or helper defect:** a command, locator, wait or helper is wrong. Correct it without changing the expected behavior, then retry the affected steps.
  - **Development-environment defect or missing prerequisite:** setup, seed data or a dependency prevents the check. Report that separately from a product defect. Repair only within the authorized scope; a disabled dependency's error path does not prove its success path.
  - **Product defect:** the real path contradicts supported expected behavior. Fix product code only when it is part of the requested change; otherwise report the mismatch and leave that expectation intact.
  - **Uncertain expectation:** report the observation and the missing decision. Neither current code nor a failed assertion alone establishes what the product should do. Never rewrite an expectation merely to pass.
- **Evidence:** everything a run writes (evidence, CLI files, sessions, pids, logs) goes under `.agents/skills/verify-<app>/.cache/`, gitignored, the same path in every project and never outside the repo; proof for a feature goes to `.cache/evidence/<feature>/`. Proof standards: exercise the real user path, not internal setters or test-only endpoints; capture the action and the resulting state, not just the final screen; verify side effects (files written, rows inserted, messages sent) alongside what's visible; mocks only where a production boundary already isolates the external system. When the safe path is a dry-run or test mode, verify what it actually skips by observing (files, network, git refs) rather than trusting its name.
- **Report:** one line per feature with **pass** (all mapped checks exercised and met), **fail** (an exercised check missed its expected result), **partial** (some checks exercised without failures, others unverified), or **blocked** (no meaningful drive possible). A failure stays failed even when known; also list any checks not exercised. Include the missing prerequisite and attempted route or command for blocked paths. Link the evidence with explicit Markdown links using absolute paths resolved from the current checkout, for example `trash — fail at "empty to trash" — [empty.png](/absolute/checkout/.agents/skills/verify-app/.cache/evidence/trash/empty.png)`. Never rely on a prefix stated elsewhere to complete a link. Check every linked file exists after cleanup; use a screenshot for a UI failure and request/response or terminal evidence for other surfaces. Report cleanup failures separately; a feature pass does not imply successful cleanup.
- **Cleanup:** the exact commands implementing step 2's lifecycle, on completion, failure and interruption. Stop only recorded processes, never by name. Remove all run-owned resources and temporary state, not merely stop containers while retaining volumes. Restore changes to pre-existing resources without deleting them. Keep proof and diagnostic logs needed for the report under `evidence/`; remove disposable sessions and runtime files after cleanup succeeds. Check the original environment is restored and linked evidence survives. If cleanup fails, retain the ownership record, report exactly what remains and how to finish cleanup; do not claim completion.
- **Helpers:** every script in `bin/`, what it does and how to call it. Scripts are bash and executable; on Windows the agent runs inside WSL.

## 4. Map every feature

Create `features/README.md` plus one file per user-facing feature the app has: every screen, route group, command, or endpoint group a user reaches, found from routes, navigation, commands, and docs. `features/README.md` holds the baseline every feature starts from, the driving conventions, the feature file shape below, and the index; follow [`references/feature-map-example/`](references/feature-map-example/).

Each feature file starts with an H1 and one paragraph describing the user-visible behavior, then exactly four H2s in this order:

1. `Sub-features`: short IDs, one line per behavior.
2. `How to get to it (user POV)`: every entry point a user has.
3. `Driving it with <tool>`: `Preconditions:` with exact setup, then labeled bullets that pair each user action with an exact command and its observable result, ending with proof and fixture cleanup.
4. `Gotchas`: traps that waste or invalidate a run.

Keep code paths out of the map: the agent maps a change to features by reasoning, and the audit reads the source. A proof that drives one convenient entry point is incomplete when the file lists others.

Make each recipe runnable from the documented baseline in a fresh session: provide setup for its data instead of relying on another feature having run, and keep variable creation and use in one command block or explicitly persist them under `.cache/`. State any unavoidable ordering. Restore fixtures so a feature can run again; when an operation is irreversible, use a disposable fixture the run can remove. Administrative setup and cleanup are allowed inside that isolated environment, but never substitute them for the user action being proved. The example map is for a fictional app; derive real commands from the project and exercise them.

## 5. Write `maintain-verify-<app>` and the stubs

Copy [`references/maintain-verify.md`](references/maintain-verify.md) to `.agents/skills/maintain-verify-<app>/SKILL.md` and [`references/maintain-verify-openai.yaml`](references/maintain-verify-openai.yaml) to `.agents/skills/maintain-verify-<app>/agents/openai.yaml`, and replace `<app>`. Adjust only what this project needs (for example, how its PRs are opened).

Write the two Claude Code stubs from [`references/claude-stub.md`](references/claude-stub.md). Their `name` and `description` must match the real skills exactly, and the maintain stub also carries `disable-model-invocation: true`.

## 6. Reconcile the project's verification instructions

Write a coherent `## Verification` section in the project's `AGENTS.md`, using [`references/agents-verification.md`](references/agents-verification.md) and replacing `<app>`. Integrate an existing verification section rather than appending a second one. For multiple apps, identify which surface each skill covers. Use links relative to `AGENTS.md`; the section must tell a new agent when to verify, where the map and skills live, which maintenance mode to choose, who manages the environment, and what evidence to report.

Read the rest of `AGENTS.md` and any instructions it imports for conflicting verification guidance. Replace superseded manual launch and cleanup recipes with references to the skill. Reconcile stale startup restrictions with the applicable user instructions and existing authorization; do not invent a new approval requirement or silently remove a deliberate restriction. If a conflict cannot be resolved from those instructions, ask about that specific conflict. Keep exact ports, resource names, dependency configuration and lifecycle commands in the skill, so there is only one maintained procedure.

Preserve relevant test, lint and type-check guidance and add the exact focused commands found in the repo where missing. Do not turn every verification into a full build. If an older verification system exists, identify its overlapping coverage and conflicting instructions; do not delete it without explicit authorization. Keep this reconciliation limited to verification guidance, preserving unrelated project instructions.

## 7. Prove it

Run `maintain-verify-<app>` in **full audit** mode on what you just wrote: every feature file checked against source and driven live under its rules. Generation always requires this mode even though later maintenance defaults to map-only. Drive the written recipes from a fresh session, not from unrecorded exploratory state. A feature that is partial, blocked or failing must be reported as such; writing the map does not complete this proof.

Exercise the lifecycle too: run a representative state-changing feature, clean up, and run it again without a reset-before step. Where helpers start resources, exercise a controlled startup failure after a resource has been created and verify cleanup removes it. Check pre-existing resources remain unchanged and evidence survives. Re-run only affected checks after corrections; do not repeat a complete audit merely because it is the final step. A generated skill without live proof remains a draft, even if a PR is already open.

## 8. Hand over

Commit everything following the repo's own branch and commit conventions. Report per `verify-<app>`'s Report section, plus the isolation choice and lifecycle checks. Explain that `/maintain-verify-<app>` updates the map without driving, `/maintain-verify-<app> full audit` also drives every feature, and `/maintain-project-verification-skill` brings the project's skills up to date when this generator changes, with the same optional full audit.
