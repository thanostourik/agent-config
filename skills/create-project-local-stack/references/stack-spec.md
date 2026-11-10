# Local stack spec

What `local-stack/` contains and the rules each file follows. The copied `stack` script relies on these rules: a stack that breaks one collides with other stacks, or cannot be started from another repo. The words used here are defined in `SKILL.md` under "Words".

## Files

```
local-stack/
  stack            copied unchanged from the skill, executable
  stack.json       ports, switches, values and what this stack provides
  compose.yaml     every service of the stack
  stubs/<switch>/  one stub per switch that has a stub mode, when no emulator fits
  README.md        usage, provided values and decisions
  .gitignore       .stack* and .facts.md
```

A stack may add folders its own services need, such as a certificate generator or a setup script.

Outside `local-stack/`, the design the user approves covers the changes to the app's local configuration and its test configuration, and the `AGENTS.md` lines it names. Any other file outside `local-stack/` needs the user's permission first, asked in one short question that names the file, shows the exact change, says in one sentence why the stack needs it, and says what happens without it. Example: "May I add `build/` to `.dockerignore`? Docker otherwise copies that git-ignored folder into the image. Without it, nothing breaks."

## What `stack` does

The script does all of this by itself; you write nothing for it. The README tells developers about it.

- **Name:** the stack name defaults to the current branch; `--name` picks another. Docker groups everything of the stack under the Compose project `<app>-<name>`, such as `orders-main`, and `destroy` removes it all.
- **Files:** the script writes only git-ignored files in `local-stack/` of its own checkout: the stack file, the record and a lock that lets one command at a time work on a stack. `destroy` deletes them. Nothing goes into the home folder, the system or git settings. The script never saves a folder for a later `up` to use, so every developer runs the same committed files with no setup of their own. The record lists the dependency stacks a stack started, with their folders, only so `down` and `destroy` reach them.
- **Ports:** while another stack of this repo holds the usual ports, such as a second worktree's default stack, the default stack gets spare ports for every port and says which stack holds the usual ones. Dependency stacks are started with `--name`, so they get spare ports. When something else holds a usual port that a container of the stack binds, `up` stops and names it; a port only the app on the host listens on is not checked. `down` and `up` keep a stack's ports.
- **Stack file:** it holds every value of the stack, secrets from the user's environment included. Deleting it on `down` means an app never reads a stopped stack's ports; it stops instead.
- **Modes:** `up` uses each switch's default. `--stubs` sets every shared switch to `stub`, `--app` sets every switch that has a `container` mode to `container`, and `--mode <switch>=<mode>` sets one switch. A mode sets its variables and turns on the Compose profile `<switch>-<mode>`, which starts the services marked with it.
- **Dependency stacks:**
  - **Finding the other repo:** a mode with `"stack": "<repo path>"` names another repo. `up` looks in the folders next to this repo's main clone and takes the main clone with a git remote that ends in that repo path, so it works the same from every worktree. A worktree there never counts, because it is a second checkout of a clone. When there is no such clone, or more than one, `up` stops and says to clone the repo next to this one or to name a clone with `up --use <switch>=<folder>`. `--use` applies to that one `up` and is never saved; the next `up` searches again. When a stack already runs the other repo's stack from a different clone, `up` stops and says to `destroy` it or pick another name, because that clone's stack does not own the running containers.
  - **Starting it:** `up` runs that clone's stack with `up --app --name <this project>`, passes `--stubs` on, and adds the modes and environment values that this stack's active modes ask for under `dependencies`. `down` and `destroy` reach it too.
  - **Its values:** each value that stack provides arrives as `<SWITCH>_<KEY>`, plus `<SWITCH>_<KEY>_FROM_CONTAINER` with `localhost` and `127.0.0.1` replaced by `host.docker.internal`.
- **Commands:** `up`, `down` (stops the containers and keeps them, their data and their ports; deletes the stack file), `destroy` (removes everything, dependency stacks included), `status`, `env` and `compose -- <docker compose arguments>`.

## `stack.json`

A fictional order service with an API, a database, a message queue, a paid payment API and another repo of the same project, its catalog service. Take its shape, not its values.

```json
{
  "app": "orders",
  "ports": {"API_PORT": 8000, "DB_PORT": 5432, "QUEUE_PORT": 5672, "PAYMENTS_STUB_PORT": 18100, "CATALOG_STUB_PORT": 18101},
  "switches": {
    "app": {"default": "host", "modes": {"host": {}, "container": {}}},
    "payments": {"default": "real", "shared": true, "modes": {
      "real": {"vars": {"PAYMENTS_URL": "https://api.payments.example.com", "PAYMENTS_URL_FROM_CONTAINER": "https://api.payments.example.com"}},
      "stub": {"vars": {"PAYMENTS_URL": "http://localhost:${PAYMENTS_STUB_PORT}", "PAYMENTS_URL_FROM_CONTAINER": "http://payments-stub:8080"}}}},
    "catalog": {"default": "stub", "modes": {
      "stub": {"vars": {"CATALOG_URL": "http://localhost:${CATALOG_STUB_PORT}", "CATALOG_URL_FROM_CONTAINER": "http://catalog-stub:8080"}},
      "stack": {"stack": "my-org/catalog", "vars": {"CATALOG_URL": "${CATALOG_API_URL}", "CATALOG_URL_FROM_CONTAINER": "${CATALOG_API_URL_FROM_CONTAINER}"}}}},
    "promotions": {"default": "off", "modes": {
      "off": {"vars": {"PROMOTIONS_ENABLED": "false"}},
      "on": {"vars": {"PROMOTIONS_ENABLED": "true"}, "dependencies": {"catalog": {"modes": {"prices": "stub"}, "env": {"CATALOG_PRICE_FILE": "${LOCAL_STACK_CHECKOUT}/fixtures/prices.json"}}}}}}
  },
  "vars": {"ORDERS_API_URL": "http://localhost:${API_PORT}", "ORDERS_QUEUE_ADDR": "localhost:${QUEUE_PORT}"},
  "provides": ["ORDERS_API_URL", "ORDERS_QUEUE_ADDR"]
}
```

- `app`: a short lowercase name for this repo's stack.
- `ports`: every port the stack publishes or the app listens on, with its usual value. Every usual value sits below the system's ephemeral range; `up` refuses one inside it. Names end in `_PORT`.
- **A switch per process:** each process this repo runs gets a switch, named `app` when there is one and `app-<process>` when there are several, such as `app-api` and `app-worker`. It has a `container` mode when agents run it in a container, and a `host` mode when developers run it on their machine; its default is `host` when it has one. Its variables are what changes when the process moves, such as the address a proxy forwards to; they may be empty. A repo that runs no process, such as a library, has no such switch.
- **Other switches:** one per outside service or other repo. Name modes after what they do, such as `real`, `stub` or `off`; a mode with a `"stack"` key starts another repo's stack, named by its repo path. `shared: true` marks a shared service, which needs a `stub` mode. Every mode of a switch sets the same variables.
- **What a mode asks of another repo's stack:** `"dependencies": {"<switch>": {"modes": {...}, "env": {...}}}` on any mode, where `<switch>` is this stack's switch with the `"stack"` mode. `modes` become `--mode` arguments of that stack's `up`; `env` values are set in its environment, where its own `${NAME}` values read them. In the example, `promotions=on` starts the catalog stack with `--mode prices=stub` and `CATALOG_PRICE_FILE` set. It applies only while that switch is in its `stack` mode. Two active modes that ask for different values stop `up`. Give the other stack a switch for the behavior instead of starting it differently by hand, so this repo's verification only calls `up`.
- `vars`: values that do not depend on a mode.
- `provides`: the values other repos' stacks may read; renaming one breaks them.
- Values use `${NAME}` for a port, an earlier value, a dependency value or a variable from the user's environment. `${LOCAL_STACK_CHECKOUT}` is this checkout's root, for a file in it. A missing one stops `up` with its name. Secrets come only from the user's environment this way, never from a file in the repo. A credential that exists only inside the stack, such as the stack database's password, is a fixed value in `compose.yaml`, not a secret.
- **Address names:** a URL is `X_URL`, a host and port without a scheme is `X_ADDR`, a bare host is `X_HOST`, each as the host sees it. Add the same name with `_FROM_CONTAINER`, as a container sees it, only when a container uses that address.
- When a process runs on the host, the port it listens on is one of the `ports`, and its configuration takes it from the stack file. Otherwise a second worktree's copy would start on the usual port that the first copy uses.
- When the stack checks who calls it, by origin, redirect address or allowed host, it accepts any `localhost` port, because other repos' stacks call it from ports it cannot know.

## `compose.yaml`

- Never set `container_name`, a volume or network `name:`, or a fixed host port. Publish each port on exactly two addresses: `127.0.0.1` for this machine, and the Docker gateway, `${LOCAL_STACK_GATEWAY_IP}` (usually `172.17.0.1`), so containers of other stacks can reach it. Binding to all addresses would let other machines on the network reach it. Bind to another address only when the user allows it, for a client on another device such as a phone.

  ```yaml
  ports:
    - "127.0.0.1:${X_PORT}:<container port>"
    - "${LOCAL_STACK_GATEWAY_IP}:${X_PORT}:<container port>"
  ```
- A service that belongs to a mode carries `profiles: [<switch>-<mode>]`, such as `app-container` or `payments-stub`. Services without a profile always run.
- Build a process from the repo with `build: {context: .., dockerfile: <its Dockerfile>}` when that Dockerfile builds a runnable image without values fixed for one environment. Otherwise write `local-stack/<process>/Dockerfile`, with a `Dockerfile.dockerignore` next to it. `up` always rebuilds, so the container runs the current working tree.
- Keep the local override files that discovery found, such as `.env`, `.env.local` or `application-local.yml`, out of every image and container. They override the stack's values, so a run with stubs could reach a real server.
- Mount every volume an image declares (`VOLUME`) on a named volume, so `destroy` removes it.
- Set no `restart:` policy. `down` keeps the containers stopped, and a policy could start them again when Docker restarts.
- Give every long-running service a memory limit, `mem_limit`, sized from a busy run, never an idle one. After the first run of proof step 1, run a busy run: the proof action and an action that reaches each other service (such as a sign-in for an auth server), each a few hundred times, 30 at a time. Read each service's use with `docker stats --no-stream` right after, and set its limit to about one and a half times that, at least `256m`. Then repeat step 1 and the busy run: every service answers, stays healthy, and `docker inspect -f '{{.State.OOMKilled}}'` prints `false`. A runtime that sizes itself from the machine, such as a JVM without `-Xmx`, Keycloak or Elasticsearch, otherwise grows until the machine runs short; under a limit it sizes itself from the limit. In trials an unlimited Keycloak grew to 8 GB in one test run; it used 0.65 GB idle and 1.7 GB under 30 sign-ins at a time, and a limit of twice its idle use got it killed. Change only the limit of a stock image, never its startup flags, which its start script may depend on.
- Give every long-running service a healthcheck that passes only when it is ready: `up` waits for every service to be healthy, or to exit with code 0, and stops on anything else. Setup that runs once, such as migrations, is a service the others depend on with `condition: service_completed_successfully`. Setup that writes data the app later changes, such as seeded accounts or rows the app updates, runs only on a stack's first `up`, so a restart never undoes the app's changes.
- Containers reach each other by service name. A container that calls a process on the host or another repo's stack gets `extra_hosts: ["host.docker.internal:host-gateway"]`.
- Use only the default network. The offline proof replaces it.

## The app's configuration

- **On the host:** the process reads `local-stack/.stack.env`, resolved from the repo root. It reads it through its framework's own configuration mechanism, in the configuration a local run uses, such as `spring.config.import` with an `optional:file:` location in the local Spring profile, or the Next.js config loading the file. When the framework has no such mechanism, a few lines in the app's own startup code that only a local run reaches read it. Never a wrapper script, an IDE-only setting or a variable the developer has to set: the developer starts the app the framework's standard way, from the IDE or the terminal. Map the stack's names to the app's own settings there, and leave the app's other environments alone.
- **Without the stack file:** the process stops at startup, before it opens any connection, with a message that names the missing file and says to run `local-stack/stack up`. The usual ports belong to the developer's own stack, so an app in another checkout that fell back to them would change that stack's data, such as by running its own migrations there.
- **No fallback:** the configuration a local run reads sets no fallback for a value the stack provides, such as `${DB_PORT:5432}` in a Spring profile or `process.env.DB_PORT ?? 5432` in Node. A missing value stops the process. When that configuration also serves another environment, such as a deployed test server, ask before you change it there. Another local setup keeps working when it writes the stack file itself; the design names each existing setup that relied on a fallback.
- **Two copies on the host:** a developer who runs two copies at once uses one worktree each. Each worktree's `up` starts its own default stack, and its `.stack.env` links to that stack's file.
- **In a container:** the process's service in `compose.yaml` sets the same settings from the `_FROM_CONTAINER` values. It skips the stack file check, such as by leaving out the local profile, because `compose.yaml` sets every value.

## Tests

The test suite is isolated by design, so any test, run from any checkout with or without a stack, cannot reach a stack.

- Tests never read the stack file or the configuration a local run reads. Example: Spring tests run with a test profile that replaces the local one, and the stack file import sits only in the local profile.
- Each service the stack provides that a test uses comes from a throwaway instance, such as a Testcontainers container, an in-memory database or an emulator the test runner starts. It is set once, in the test configuration every test loads, such as `src/test/resources/application.yml`, a base class every integration test extends, or the test runner's global setup. A new test is then isolated without doing anything; a setting in each test class is not enough.
- The test configuration sets no fallback for those services either. A test that finds no throwaway instance fails.
- When a service has no throwaway instance the tests can start, such as a product with no container image or emulator, ask the user how those tests get it, as `questions.md` says. Never point them at the stack file or a usual port.

## Stubs

- Prefer an emulator or a local instance of the same product, such as LocalStack for AWS services, Mailpit for mail, or the broker itself for a message queue. Write a stub yourself only when none exists.
- A stub you write answers what the app's client code sends, in its protocol, with the response shapes, streaming, paging and errors the client handles. Its answers are fixed, so a run can be repeated.
- Run each stub from a stock image or a small Dockerfile under `stubs/<switch>/`, with a healthcheck.
- When the app's code fixes the address, such as a hard-coded hostname or an `https`-only client, the stub answers under the real hostname: give it that name as a network alias on the stack's network. For `https`, serve a certificate from a certificate authority that the stack generates and that only the stack's containers trust.

## `README.md`

Written for the developers who use the stack. Sections, in this order:

1. What the stack is, in two sentences, and the line `Built with create-project-local-stack version <n>.`, where `<n>` is the newest entry in `changelog.md`.
2. `## Commands`: `up`, `up --app`, `--stubs`, `--mode`, `--name`, `--use` when the stack starts another repo's stack, `down`, `destroy`, `status`, `env`, `compose`, each with one line.
3. `## Run the app on your machine`: the exact steps for this app, and how to run a second copy at once: in its own worktree, with its own `up`. Say that the app stops without a running stack and names `local-stack/stack up`, and that the tests need no stack.
4. `## Services`: each service, with what it runs.
5. `## Switches`: a table of each switch, its modes, its default, whether it is shared, and what each stub does not cover.
6. `## Needs`: each other repo, by its repo path, and the values used from it. Say that its clone sits next to this repo's clone, or is named for one run with `--use`.
7. `## Provides`: each value in `provides`, with what it is.
8. `## Decisions`: each answer the user gave, one line with its date. A later run reads this section instead of asking again.
