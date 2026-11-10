---
name: create-project-local-stack
metadata:
  harness: "claude-code, codex, grok, cursor"
description: "Generate the project's isolated local stack, committed in the repo as local-stack/. Developers run it next to the app in their IDE. Agents run it with the app included, many at once and across the project's repos, to check their work. Use for /create-project-local-stack or \"set up a local stack for this repo\"."
disable-model-invocation: true
---

# Create a project local stack

You build `local-stack/` in this repo: one command, `local-stack/stack`, that starts everything the app needs on this machine, isolated from every other stack. Developers run `local-stack/stack up` and start the app from their IDE or terminal. Agents run `local-stack/stack up --app --stubs --name <unique name>`, which also runs the app in a container and stubs every shared service; any number run at once, across repos.

The script [`references/stack`](references/stack) handles names, ports, modes, dependency stacks and cleanup; copy it unchanged. You write the project-specific part that [`references/stack-spec.md`](references/stack-spec.md) defines: what runs, how it is configured, and what replaces each outside service.

## Words

- **Stack:** one running copy of `local-stack/`, identified by its name. The name defaults to the current branch.
- **Default stack:** the stack named after the branch. In the developer's checkout it is theirs; agents never use it.
- **Usual port:** a port's value in `stack.json`. The default stack gets the usual ports when no other stack of the repo holds them, so in the developer's checkout they belong to the developer's own stack.
- **Spare port:** a free port the operating system hands out to any program that asks for one. It comes from the system's ephemeral range, which by default starts at 32768 on Linux (`/proc/sys/net/ipv4/ip_local_port_range`) and 49152 on macOS (`sysctl net.inet.ip.portrange.first`). Stacks started with `--name` get spare ports, so every usual port must sit below that range.
- **Proof action:** one action you pick from the code that shows the app works end to end: an HTTP call and its response, a command and its output, or a message and the row it writes.
- **Switch:** an entry in `stack.json` for one thing the stack can run in different ways, such as the app itself or a payment API.
- **Mode:** one value of a switch, such as `real`, `stub`, `host` or `container`.
- **Shared service:** an outside service an agent must not call without permission, because other people use it, or because a call costs money, sends messages, changes data others see or uses up a limit. `--stubs` replaces it.
- **Stub:** something in the stack that answers in place of an outside service: a local emulator of it, or a small server you write.
- **Dependency stack:** another repo's stack that this stack starts, through a mode with a `"stack"` key.
- **Repo path:** a repo's path in its git remote, such as `my-org/catalog` for `git@github.com:my-org/catalog.git`. A stack names other repos this way, never by a folder.
- **Main clone:** the folder that holds a repo's `.git` folder. Every worktree of the repo belongs to it.
- **Stack file:** `local-stack/.stack-<name>.env`, the `KEY=value` file `up` writes and `down` deletes. `local-stack/.stack.env` links to the checked-out branch's stack file. An app running on the host reads it, and stops when it is missing.
- **Throwaway instance:** a copy of a service that a test run starts for itself and removes afterwards, such as a Testcontainers container or an in-memory database.
- **Record:** `local-stack/.stack-<name>.json`, where the script keeps a stack's modes, ports, values and dependency stacks.

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
- Build the stack next to whatever the repo already has for running locally. Never edit or remove that, except for the changes to the app's local and test configuration that the design names.
- If the project already runs locally through a tool that manages its whole environment, such as DDEV, Lando, Laravel Sail, a devcontainer, Tilt or a dev compose file, show the user what that tool already provides and ask whether to build a stack anyway or to stop.
- Keep facts in `local-stack/.facts.md`, one line each: the fact, then its source, such as `config/mail.php:12` or `user, <date>`. Step 7 deletes it.

## Update an existing stack

1. Copy [`references/stack`](references/stack) to `local-stack/stack` unchanged.
2. Read the skill version the README names; a README without one was built with version 1. Read the newer entries in [`references/changelog.md`](references/changelog.md). List every place where `local-stack/`, the app's local or test configuration or the `AGENTS.md` section does not match those entries, [`references/stack-spec.md`](references/stack-spec.md) or this skill. Also list every README sentence those changes make wrong.
3. Fix each one and keep the services, switches and Decisions. Ask the user before a fix that changes what the stack runs, a default, or a Decision. When a rule conflicts with a Decision in the README and both would work, ask which to keep; a kept Decision names the rule it departs from. When the rule plainly does not fit this stack, keep what works and report the rule as a skill bug.
4. Rerun the whole proof of step 6 when the update changes which services run, how the app is configured, or a stack this one starts. Otherwise run the checks the changelog items name. Always end with cleanup.
5. Set the README's skill version to the newest changelog entry, add the answers the user gave during this update to Decisions, commit, and report what changed and which checks ran.

## 2. Discover

Read the whole repo: code, configuration, build files, docs, CI pipelines, test setups, and any scripts or container files already there. Use existing files only as sources of facts; the stack follows `stack-spec.md`, not their structure. Discovery only reads; it runs nothing. Find:

- **The processes:** each process this repo runs, such as an API, a worker, a scheduled job, a CLI or a web front end: its build command, its entry point, the port it listens on if any, and how it reads configuration. Read the build files, any Dockerfile, and the run scripts they define. A library runs no process; its stack holds what its tests need.
- **Its configuration:** every profile and environment file, every environment variable the code reads, which of them a local run uses, and which local files are git-ignored overrides, such as `.env.local` or `application-local.yml`.
- **Everything it talks to:** every host, URL, port, connection string, SDK client and queue in the configuration and the code. For each, note what the app sends and what it expects back, from the client code.
- **What talks to it:** proxies, gateways, workers, browsers, devices or other repos that call it, and through which address.
- **Its data:** schemas, migrations, seed or fixture data, and how an account or tenant comes to exist.
- **Its tests:** the test command CI runs, the configuration tests load, and for each service the stack provides, how tests get it: a throwaway instance, the local configuration, a committed fallback or a fixed address. Look at every test that starts the app or connects to a service, such as a Spring `@SpringBootTest` class, which loads the default profiles unless the test configuration says otherwise.
- **Other repos of the project:** docs that describe the project and this repo's job in it, such as a README or `ARCHITECTURE.md`, and clients for services this repo does not contain.

Then sort each thing the app talks to into one of three kinds, and write the kind into the fact file:

- **Runs in the stack:** only this app uses it, such as its own database. Build it as a service.
- **Outside service:** something outside this project, such as a payment API or a shared AI service. It gets a switch with `real` and `stub` modes.
- **Another repo of this project:** it gets a switch with a mode that starts that repo's stack, and a `stub` mode if the user wants one.

When the code does not settle the kind, ask.

## 3. Ask

Ask every open question from step 2, following [`references/questions.md`](references/questions.md). New facts can open new questions; ask those too. Write each answer into the fact file.

Read where this system's ephemeral range starts (see "Spare port"). Ask about each usual port at or above it, as `questions.md` says under "Asked on a conflict".

For another repo:

- Ask for its repo path. Find its clone next to this repo's main clone; when it is elsewhere, ask the user for the folder, only to read it.
- If that clone has no `local-stack/stack`, tell the user to run `/create-project-local-stack` there first, and stop until they have, unless they choose a `stub` mode for it. Never build another repo's stack inside this one.
- Use only what that repo's `local-stack/README.md` lists under Provides, so its stack can change inside without breaking this one.
- If this repo needs a value the other stack does not provide, or the other stack rejects calls from this app, for example because it allows only one origin, ask the user. The fix goes into the other repo, on its own branch.

## 4. Show the design and wait

Show the user the design on one screen:

- the services, each with what it runs and why;
- the switches, each with its modes, its default, whether it is shared, and what its stub covers and does not;
- the other repos it starts, each by its repo path;
- the proof action and the result that shows it worked;
- the change to the app's local configuration, and each existing way to run the app locally that relied on a fallback the change removes;
- the change to the app's test configuration: the throwaway instance for each service, and where it is set;
- the `## Local stack` section for `AGENTS.md`, and each existing line in `AGENTS.md` or `CLAUDE.md` you will rewrite;
- the local override files the stack keeps out of images and containers;
- the open items that stay blocked.

Wait for an explicit go. If the user asks for a change, update the design and show it again.

## 5. Build

Write the files [`references/stack-spec.md`](references/stack-spec.md) lists. Copy [`references/stack`](references/stack) to `local-stack/stack` unchanged and make it executable. Commit `local-stack/` and the app's configuration changes following the repo's branch and commit conventions, so step 6 can check them out in a worktree.

## 6. Prove it

Use only the proof stacks `lsproof-a`, `lsproof-b` and `lsproof-c`, never the developer's own stack, and stop only the processes you started, by process ID, never by name. Before you start, save the output of `docker ps -a`, `docker volume ls` and `docker network ls`. In step 5, `compose` means `local-stack/stack compose --name lsproof-a --`.

Until step 7 passes, run the repo's tests only as step 7 does, never on the host, and never start the app on the host in a checkout without its own running stack. This holds while you build or update the stack too: a test configuration that still falls back to the usual ports changes the developer's stack.

1. **App in a container:** with no `lsproof-a` stack present, run `local-stack/stack up --app --stubs --name lsproof-a`. Run the proof action and check its result.
2. **App on the host, at the same time:** when no switch has a `host` mode, skip this step and report it as not applicable. Otherwise:
   1. Add a worktree outside the repo: `git worktree add -b lsproof-b <dir>`.
   2. In it, run `local-stack/stack up --stubs` without `--name`. The stack is that worktree's default stack, `lsproof-b`. It gets the usual ports, or spare ports and a message naming the stack that holds them, such as the developer's own. `--stubs` keeps shared services out of this step; step 4 proves the real ones.
   3. Do what a fresh checkout needs before its first run, such as installing dependencies. Then start the app the way a developer does, with its usual run command and nothing added.
   4. Run the proof action against the app directly, and once through each service that calls it. Stop the app.
   5. When a later fix changes the stack, commit it and run `git -C <dir> reset --hard <your branch>` before you rerun this step.
3. **Parallel:** create one item of the app's data in `lsproof-a`, and check that `lsproof-b` does not show it and that `status` shows different ports for the two, with every port of `lsproof-a` at or above the start of the ephemeral range. Run `local-stack/stack down --name lsproof-a`, then `up --app --stubs --name lsproof-a` again, and check that its ports and that item are unchanged.
4. **Real modes:** for each switch whose default is `real`, call it once only if the user allowed that for this run. Otherwise report it as not proved.
5. **Offline:**
   1. From the build logs of step 1, list each outside address an image build downloads from, and put the list in the README as "the image build needs internet for: …".
   2. Run `compose down`.
   3. Run `compose -f <file> up --detach`, where `<file>` is a temporary file outside the repo with:

      ```yaml
      networks:
        default:
          internal: true
      ```

      When the app waits for a service that needs another repo's stack, add `--no-deps <app service>` and check only the app's own work.
   4. Ports are not published on an internal network, so run the proof action from inside with `compose exec <service> <command>`.
   5. Read `compose logs`. Each failed lookup or connection to anything that is not a stack service is a service step 2 missed: go back to step 3 with it, never stub it silently. Failures to reach a dependency stack are expected, because it is reached through the host; say so in the report.
   6. Run `compose down` before the next `up`.
6. **Dependencies:** start `lsproof-c` with `local-stack/stack up --app --stubs --name lsproof-c`, adding `--mode <switch>=<mode>` for every mode with a `"stack"` key, even when it is not the default, and for every mode with `dependencies`. Run the proof action. `local-stack/stack status --name lsproof-c` names each dependency stack, and that stack's own status shows its shared switches in `stub` mode and the modes the `dependencies` asked for.
7. **Isolation:** nothing started in a checkout without its own stack reaches another stack, even while the developer's stack holds the usual ports. Work in the `lsproof-b` worktree while `lsproof-b` is up, so its stack file exists; when step 2 was skipped, add the worktree as step 2.1 says. Run both commands below in a container, never on the host:
   - from a stock image of the repo's toolchain, such as `maven:<version>` or `node:<version>`, with the version the build files name;
   - with the worktree mounted at its own path as the working folder, and the dependency cache mounted, as your own user (`--user "$(id -u):$(id -g)"`);
   - when the tests start throwaway instances through Docker, with the Docker socket mounted and its group added (`--group-add`);
   - with no `--network host`, no `host.docker.internal` and no published port.

   Inside, `localhost` is the container itself, so no usual port of the host answers, and neither does any address in the stack file. A test or a run that reaches for another stack fails there instead of changing it.
   1. Run the repo's whole test suite, the command CI runs. It passes. A test that fails to reach a `localhost` port or an address of the stack file took that service from the stack file, the local configuration or a fallback: fix the test configuration as `stack-spec.md` says under "Tests", and rerun.
   2. When a switch has a `host` mode, delete the link `local-stack/.stack.env`, leaving the stack file it points to, and start the app with its usual run command. It stops at startup with a message that names `local-stack/stack up`, and its log shows no attempt to connect to any service.
   3. When either cannot run this way, report the step as not proved. Never run it on the host instead.
8. **Cleanup:** run `local-stack/stack destroy --name <name>` for each proof stack, `lsproof-b` from its worktree. Then remove the worktree with `git worktree remove <dir>` and its branch with `git branch -D lsproof-b`. Check that no container, volume, network or built image of their projects is left, that no `local-stack/.stack-lsproof-*` file is left, and that the lists you saved before step 1 are unchanged.

When a step fails, fix the stack and rerun the steps the fix affects. A step you could not run is reported as not proved, never as passed.

## 7. Hand over

- Write the README's `## Decisions` section from the user's answers in the fact file. Then delete `local-stack/.facts.md`.
- Add the `## Local stack` section to the project's `AGENTS.md` from [`references/agents-local-stack.md`](references/agents-local-stack.md). Merge it with an existing section on running the app locally instead of adding a second one, and keep what that says about the existing setup. Rewrite the other lines the design named, so agents never get two conflicting instructions. If the project has a `CLAUDE.md` that does not import `AGENTS.md`, put the same section there.
- Commit following the repo's branch and commit conventions.
- Report:
  - each proof step: passed, failed or not proved, with the reason;
  - what each stub does not cover, as risks a run with stubs cannot catch;
  - the blocked items and the question each one waits on;
  - every change outside `local-stack/`.
