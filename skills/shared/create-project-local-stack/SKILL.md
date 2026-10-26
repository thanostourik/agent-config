---
name: create-project-local-stack
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Generate the project's isolated local stack, committed in the repo as local-stack/. Developers run it next to the app in their IDE. Agents run it with the app included, many at once and across the project's repos, to check their work. Use for /create-project-local-stack or \"set up a local stack for this repo\"."
disable-model-invocation: true
---

# Create a project local stack

You build `local-stack/` in this repo: one command, `local-stack/stack`, that starts everything the app needs on this machine, isolated from every other stack. Two kinds of users run it:

- **Developers** run `local-stack/stack up`, which starts everything the app needs, then run the app from their IDE or terminal.
- **Agents** run `local-stack/stack up --app --stubs --name <unique name>`, which also runs the app in a container and replaces every shared service with a stub. Any number of these run at once, from one or several repos.

The script [`references/stack`](references/stack) already handles stack names, ports, modes, dependency stacks and cleanup. Copy it unchanged. Your work is the project-specific part: what runs, how it is configured, and what replaces each outside service. [`references/stack-spec.md`](references/stack-spec.md) defines every file you write.

## Words

- **Stack:** one running copy of `local-stack/`, identified by its name. The name defaults to the current branch.
- **Default stack:** the stack named after the branch. It belongs to the developer; agents never use it.
- **Proof stack:** a stack you start in step 6 under a name like `lsproof-a`, and destroy by name at the end.
- **Switch:** an entry in `stack.json` for one thing the stack can run in different ways, such as the app itself or a payment API.
- **Mode:** one value of a switch, such as `real`, `stub`, `host` or `container`.
- **Shared service:** an outside service an agent must not call without permission, because other people use it, or because a call costs money, sends messages, changes data others see or uses up a limit. `--stubs` replaces it.
- **Stub:** something in the stack that answers in place of an outside service: a local emulator of it, or a small server you write. In questions to the user, call it a "fake".
- **Dependency stack:** another repo's stack that this stack starts, through a mode with a `"stack"` key.
- **Stack file:** `local-stack/.stack-<name>.env`, the `KEY=value` file `up` writes and `down` deletes. `local-stack/.stack.env` links to the checked-out branch's stack file, and an app running on the host reads it.
- **Claim:** a stack's record in the machine's registry: its checkout, ports, modes, values and dependency stacks.

## Ask, never guess

- **A fact** is something the code or the user can tell you, such as the port the app listens on or whether colleagues use a service. Every fact the stack depends on needs a source: a file and line in this repo or a repo it depends on, or the user's answer. When neither exists, ask. Never use a default, a convention or what similar projects do.
- **A choice** is something you decide for the stack. Ask about a choice only when more than one option would work. When the facts leave one option, take it and name the fact in the design. Example: `pom.xml:30` uses the PostgreSQL driver, so the stack runs PostgreSQL; no question.
- Ask with your harness's question tool, such as `AskUserQuestion` in Claude Code, or in your reply when it has none, and wait for the answer. [`references/questions.md`](references/questions.md) says which questions to ask and how.
- When the user does not know an answer, the part that depends on it is blocked. Leave it out, build the rest, and report it.

## 1. Start

- Check that `docker compose version` reports v2 or later and that `python3` exists. Report anything missing, and stop. The script is tested on Linux with Docker Engine; on another platform, such as Docker Desktop or Podman, tell the user it is untested there.
- If `local-stack/` exists, ask the user which of three to do, and never change it silently:
  - **Update:** bring the stack up to the current skill, as "Update an existing stack" below says.
  - **Recreate:** build it again from step 2. Its README's `## Decisions` section holds the user's earlier answers; take them as answered questions.
  - **Stop:** change nothing.
- Build the stack next to whatever the repo already has for running locally. Never edit or remove that.
- If the project already runs locally through a tool that manages its whole environment, such as DDEV, Lando, Laravel Sail, a devcontainer, Tilt or a dev compose file, show the user what that tool already provides and ask whether to build a stack anyway or to stop.
- Keep facts in `local-stack/.facts.md`, one line each: the fact, then its source, such as `config/mail.php:12` or `user, <date>`. Step 7 deletes it.

## Update an existing stack

1. Copy [`references/stack`](references/stack) to `local-stack/stack` unchanged.
2. Read the skill version the README names; a README without one was built with version 1. Read the newer entries in [`references/changelog.md`](references/changelog.md). List every place where `local-stack/`, the app's local configuration change or the `AGENTS.md` section does not match those entries, [`references/stack-spec.md`](references/stack-spec.md) or this skill. Also list every README sentence those changes make wrong.
3. Fix each one and keep the services, switches and Decisions. A fix that changes what the stack runs, a default or a Decision is a question for the user first. When a rule conflicts with a recorded Decision and both would work, ask which to keep; a kept Decision names the rule it departs from. When the rule plainly does not fit this stack, keep what works and report the rule as a skill bug.
4. Rerun the whole proof of step 6 when the update changes which services run, how the app is configured, or a stack this one starts. Otherwise run the checks the changelog items name. Always end with cleanup.
5. Set the README's skill version to the newest changelog entry, add the answers the user gave during this update to Decisions, commit, and report what changed and which checks ran.

## 2. Discover

Read the whole repo: code, configuration, build files, docs, CI pipelines, test setups, and any scripts or container files already there. Use existing files only as sources of facts; the stack follows `stack-spec.md`, not their structure. Discovery only reads; it runs nothing. Find:

- **The processes:** each process this repo runs, such as an API, a worker, a scheduled job, a CLI or a web front end: its build command, its entry point, the port it listens on if any, and how it reads configuration. Read the build files (`pom.xml`, `package.json`, `pyproject.toml`, `go.mod`, `composer.json`, …), any Dockerfile, and the run scripts they define. A library runs no process; its stack holds what its tests need.
- **Its configuration:** every profile and environment file, every environment variable the code reads, which of them a local run uses, and which local files are git-ignored overrides, such as `.env`, `.env.local`, `application-local.yml` or `settings_local.py`.
- **Everything it talks to:** every host, URL, port, connection string, SDK client and queue in the configuration and the code: databases, caches, object storage, mail, message brokers, auth servers, search, AI services, webhooks, other APIs. For each, note what the app sends and what it expects back, from the client code.
- **What talks to it:** proxies, gateways, workers, browsers, devices or other repos that call it, and through which address.
- **Its data:** schemas, migrations, seed or fixture data, and how an account or tenant comes to exist.
- **Other repos of the project:** docs that describe the project and this repo's job in it, such as a README or `ARCHITECTURE.md`, and clients for services this repo does not contain.

Then sort each thing the app talks to into one of three kinds, and write the kind into the fact file:

- **Runs in the stack:** only this app uses it, such as its own database. Build it as a service.
- **Outside service:** something outside this project, such as a payment API or a shared AI service. It gets a switch with `real` and `stub` modes.
- **Another repo of this project:** it gets a switch with a mode that starts that repo's stack, and a `stub` mode if the user wants one.

When the code does not settle the kind, ask.

## 3. Ask

Ask every open question from step 2, following [`references/questions.md`](references/questions.md). New facts can open new questions; ask those too. Write each answer into the fact file.

For another repo:

- Ask where its checkout is.
- If that checkout has no `local-stack/stack`, tell the user to run `/create-project-local-stack` there first, and stop until they have, unless they choose a `stub` mode for it. Never build another repo's stack inside this one.
- Use only what that repo's `local-stack/README.md` lists under Provides, so its stack can change inside without breaking this one.
- If this repo needs a value the other stack does not provide, or the other stack rejects calls from this app, for example because it allows only one origin, ask the user. The fix goes into the other repo, on its own branch.

## 4. Show the design and wait

Show the user the design on one screen:

- the services, each with what it runs and why;
- the switches, each with its modes, its default, whether it is shared, and what its stub covers and does not;
- the other repos it starts, and the variable that holds each checkout;
- the proof action and the result that shows it worked;
- the change to the app's local configuration, the `## Local stack` section for `AGENTS.md`, and each existing line in `AGENTS.md` or `CLAUDE.md` you will rewrite;
- the local override files the stack keeps out of images and containers;
- the open items that stay blocked.

Wait for an explicit go. If the user asks for a change, update the design and show it again.

## 5. Build

Write the files [`references/stack-spec.md`](references/stack-spec.md) lists. Copy [`references/stack`](references/stack) to `local-stack/stack` unchanged and make it executable.

## 6. Prove it

Never use the default stack. Record `docker ps -a`, `docker volume ls` and `docker network ls` before you start. "The proof action" below is one action you pick from the code that shows the app works end to end, fitting the kind of project: an HTTP call and its response, a command and its output, or a message and the row it writes. It is not recorded anywhere; a later run picks it again.

1. **App in a container:** with no `lsproof-a` stack present, run `local-stack/stack up --app --stubs --name lsproof-a`. Run the proof action and check its result.
2. **App on the host, at the same time:** skip this step and report it as not applicable when no switch has a `host` mode. Otherwise run `local-stack/stack up --stubs --name lsproof-b`, so the proof sends nothing to a shared service; step 4 proves the real ones. Start the app on the host the way a developer does, with its usual run command and `LOCAL_STACK_FILE` set to `lsproof-b`'s stack file, nothing else added. Run the proof action against it directly, and once through each service that calls it. Stop the app.
3. **Parallel:** create one record in `lsproof-a`, and check that `lsproof-b` does not show it and that `status` shows different ports for the two.
4. **Real modes:** for each switch whose default is `real`, call it once only if the user allowed that for this run. Otherwise report it as not proved.
5. **Offline:**
   1. From the build logs of step 1, list each outside address an image build downloads from, and put the list in the README as "the image build needs internet for: …".
   2. Run `local-stack/stack compose --name lsproof-a -- down`.
   3. Run `local-stack/stack compose --name lsproof-a -- -f <file> up --detach`, where `<file>` is a temporary file outside the repo with:

      ```yaml
      networks:
        default:
          internal: true
      ```

      When the app waits for a service that needs another repo's stack, add `--no-deps <app service>` and check only the app's own work.
   4. Ports are not published on an internal network, so run the proof action from inside with `local-stack/stack compose --name lsproof-a -- exec <service> <command>`.
   5. Read `local-stack/stack compose --name lsproof-a -- logs`. Each failed lookup or connection to anything that is not a stack service is a service step 2 missed: go back to step 3 with it, never stub it silently. Failures to reach a dependency stack are expected, because it is reached through the host; say so in the report.
   6. Run `local-stack/stack compose --name lsproof-a -- down` before the next `up`.
6. **Dependencies:** start `lsproof-c` with `local-stack/stack up --app --stubs --name lsproof-c`, adding `--mode <switch>=<mode>` for every mode with a `"stack"` key, even when it is not the default. Run the proof action. `local-stack/stack status --name lsproof-c` names each dependency stack, and that stack's own status shows its shared switches in `stub` mode.
7. **Cleanup:** run `local-stack/stack destroy --name <name>` for each proof stack. Check that no container, volume, network or built image of their projects is left, that their stack files and claims are gone, and that the names in the lists you recorded are unchanged.

Stop only the processes you started, by their process ID, never by name. When a step fails, fix the stack and rerun the steps the fix affects. A step you could not run is reported as not proved, never as passed.

## 7. Hand over

- Write the README's `## Decisions` section from the user's answers in the fact file, one line each with its date. Name the skill version, the newest entry in [`references/changelog.md`](references/changelog.md), in the README's first section. Then delete `local-stack/.facts.md`.
- Add the `## Local stack` section to the project's `AGENTS.md` from [`references/agents-local-stack.md`](references/agents-local-stack.md). Merge it with an existing section on running the app locally instead of adding a second one, and keep what that says about the existing setup. Rewrite the other lines the design named, so agents never get two conflicting instructions. If the project has a `CLAUDE.md` that does not import `AGENTS.md`, put the same section there.
- Commit following the repo's branch and commit conventions.
- Report:
  - each proof step: passed, failed or not proved, with the reason;
  - what each stub does not cover, as risks a run with stubs cannot catch;
  - the blocked items and the question each one waits on;
  - every change outside `local-stack/`.
