---
name: create-project-local-stack
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Generate the project's isolated local stack, committed in the repo as local-stack/: developers run it with the app in their IDE, agents run it whole, many at once and across the project's repos, to verify their work. Use for /create-project-local-stack or \"set up a local stack for this repo\"."
disable-model-invocation: true
---

# Create a project local stack

You build `local-stack/` in this repo: one command, `local-stack/stack`, that starts everything the app needs on this machine, isolated from every other stack. Two kinds of users run it:

- **Developers** run `local-stack/stack up`, which starts everything except the app, then run the app from their IDE.
- **Agents** run `local-stack/stack up --app --stubs --name <unique name>`, which also runs the app in a container and swaps every shared external service for a stub. Any number of these run at once, on one machine, from one or several repos.

The mechanism (names, ports, modes, dependency stacks, cleanup) lives in [`references/stack`](references/stack), which you copy unchanged. Your work is the project-specific part: what runs, how it is configured, and what replaces each external service. [`references/stack-spec.md`](references/stack-spec.md) defines every file you write.

## Ask, never guess

This is the rule the whole skill rests on.

- Every fact the stack depends on needs a source: a file and line in this repo or in a repo it depends on, or the user's answer. A fact with neither is a question for the user. Never fill it with a reasonable default, a common convention or what similar projects do.
- Ask with your harness's tool for asking the user questions, such as `AskUserQuestion` in Claude Code. Only when your harness has none, ask in your reply and stop until the user answers. A question that gets no answer is asked again. Never answer it yourself.
- Follow [`references/questions.md`](references/questions.md) for which questions to ask and how to write them.
- When the user does not know an answer, the part that depends on it is blocked. Leave it out of the stack, keep building the rest, and report it.

## 1. Start

- Check that `docker compose version` reports v2 and that `python3` exists. Report anything missing, and stop.
- If `local-stack/` exists, ask the user whether to replace it or to stop. Never overwrite it silently. Its README's `## Decisions` section holds the user's earlier answers.
- Build the stack next to whatever the repo already has for running locally. Never edit or remove that.
- If the project already runs locally through a tool that manages its whole environment, such as DDEV, ask the user whether to build a Compose stack anyway or to stop.
- Keep observed facts in `local-stack/.facts.md`, one line each: the fact, then its source, such as `kong.yml:42` or `user, <date>`. It is a working file; step 6 deletes it.

## 2. Discover

Read the whole repo: code, configuration, build files, docs, CI pipelines, test setups, and any scripts or container files already there. Every file is evidence, and none is a template: the stack follows the spec. Discovery only reads; it runs nothing. Find:

- **The app:** each process this repo runs: its build command, its entry point, its listening port and how it reads configuration. Read the build files (`pom.xml`, `build.gradle`, `package.json`, `pyproject.toml`, …), the Dockerfile if any, and the run scripts they define.
- **Its configuration:** every profile and environment file, every environment variable the code reads, and which of them a local run uses.
- **Everything it talks to:** every host, URL, port, connection string, SDK client and queue in the configuration and the code: databases, caches, object storage, mail, auth servers, gateways, search, AI services, webhooks, other HTTP APIs. For each, note what the app sends and what it expects back, from the client code.
- **What talks to it:** gateways, proxies, workers, browsers or other repos that call the app, and through which address.
- **Its data:** schemas, migrations, seed or fixture data, and how a user or tenant comes to exist.
- **Other repos of the project:** READMEs, `PLATFORM.md` and similar docs that describe the project and this repo's job in it, and clients for services this repo does not contain.

Then sort each thing the app talks to into one of three kinds, and write the kind into the fact file:

- **Runs in the stack:** the app owns it and nothing outside the stack needs it, such as the app's own database. Build it as a service.
- **External service:** something outside this project, such as a shared AI service or a payment API. It gets a switch with `real` and `stub` modes.
- **Another repo of this project:** it gets a switch with a `stack` mode, which starts that repo's own local stack, and a `stub` mode if the user wants one.

When the code does not settle the kind, ask.

## 3. Ask

Ask every open question from step 2, following [`references/questions.md`](references/questions.md). New facts can open new questions; ask those too. Write each answer into the fact file.

For another repo, ask where its checkout is. If that checkout has no `local-stack/stack`, tell the user to run `/create-project-local-stack` there first, and stop until they have, unless they choose a `stub` mode for it. Never build another repo's stack inside this one. Use only what that repo's `local-stack/README.md` lists under Provides, so its stack can change inside without breaking this one.

## 4. Show the design and wait

Show the user the design on one screen:

- the services, each with what it runs and why;
- the switches, each with its modes, its default, whether it is shared, and what its stub covers and does not;
- the other repos it starts, and the variable that holds each checkout;
- the change to the app's local configuration that makes it read the stack file;
- the open items that stay blocked.

Wait for an explicit go. A change the user asks for here means a new design, shown again.

## 5. Build

Write the files [`references/stack-spec.md`](references/stack-spec.md) lists. Copy [`references/stack`](references/stack) to `local-stack/stack` unchanged and make it executable. Build each stub from the client code's requests and responses.

## 6. Prove it

Use stack names no one else uses, such as `lsproof-a` and `lsproof-b`. Never use the default name: it belongs to the developer. Record `docker ps -a`, `docker volume ls` and `docker network ls` before you start.

1. **Agent mode:** `local-stack/stack up --app --stubs --name lsproof-a` from clean. Send one request that crosses the app's main path, such as signing in and loading the main page or calling the main endpoint, and check the answer.
2. **IDE mode, at the same time:** `local-stack/stack up --name lsproof-b`. Start the app on the host the way a developer runs it from the IDE: its usual run command, with `LOCAL_STACK_FILE` pointing at `lsproof-b`'s stack file and nothing else added. Send the same request, also through each service that calls the app. Stop the app.
3. **Parallel:** both stacks ran at once on different ports, and neither saw the other's data.
4. **Real modes:** for each switch whose default is `real`, call it once only if the user allowed that for this run. Otherwise report it as not proved.
5. **Offline:** `local-stack/stack down --name lsproof-a`, then `local-stack/stack compose --name lsproof-a -- -f <file> up --detach --wait`, where `<file>` is a temporary file outside the repo that makes the default network internal:

   ```yaml
   networks:
     default:
       internal: true
   ```

   Ports are not published on an internal network, so send the request from inside with `local-stack/stack compose --name lsproof-a -- exec <service> <command>`. Read `local-stack/stack compose --name lsproof-a -- logs`. Each failed lookup or connection to anything that is not a stack service is a service step 2 missed. Go back to step 3 with it, never stub it silently. A switch in `stack` mode reaches the other repo through the host, so its failures here are expected; say so in the report.
6. **Dependencies:** for each switch in `stack` mode, `local-stack/stack status --name lsproof-a` names the other repo's stack. That stack's own status shows its shared switches in `stub` mode.
7. **Cleanup:** `local-stack/stack destroy` for both names. Check that no container, volume, network or built image carries either project's label, that both stack files and registry claims are gone, and that the lists you recorded are unchanged.

When a step fails, fix the stack and rerun the steps the fix affects. A step you could not run is reported as not proved, never as passed.

## 7. Hand over

- Write the README's `## Decisions` section from the user's answers in the fact file, one line each with its date. Then delete `local-stack/.facts.md`.
- Add the `## Local stack` section to the project's `AGENTS.md` from [`references/agents-local-stack.md`](references/agents-local-stack.md). Integrate an existing section on running the app locally instead of adding a second one, and keep what it says about the existing setup. If the project has a `CLAUDE.md` that does not import `AGENTS.md`, put the same section there.
- Commit following the repo's branch and commit conventions.
- Report:
  - each proof step: passed, failed or not proved, with the reason;
  - what each stub does not cover, as risks a stub-mode run cannot catch;
  - the blocked items and the question each one waits on;
  - the change to the app's configuration.
