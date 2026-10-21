# Local stack spec

What `local-stack/` contains and the rules each file follows. The copied `stack` script relies on these rules; a stack that breaks one fails in parallel or across repos.

## Files

```
local-stack/
  stack            copied unchanged from the skill, executable
  stack.json       ports, switches, values and what this stack provides
  compose.yaml     every service of the stack
  stubs/<switch>/  one fake per switch with a stub mode
  README.md        usage, contract and decisions
  .gitignore       .stack*.env and .facts.md
```

Besides `local-stack/`, the skill changes only the app's local configuration, so that it reads the stack file, and the project's `AGENTS.md`.

## What `stack` does

- **Name:** the stack name defaults to the current branch; `--name` picks another. The Compose project is `<app>-<name>`, such as `backend-main`. Every container, volume, network and built image carries that project's label, which is what `destroy` removes.
- **Ports:** each port in `stack.json` is claimed in one registry per machine, `$XDG_STATE_HOME/local-stacks/`, shared by the stacks of every repo. A port gets its usual value when no other claim holds it and it is free, otherwise the lowest free port from 10000. A claim keeps its ports across `down` and `up` until `destroy`. A claim whose project has no containers, volumes or networks left, and whose `up` is not running, is released when another stack needs ports.
- **Stack file:** `up` writes every value of the stack to `local-stack/.stack.env`, or to `local-stack/.stack-<name>.env` for a name other than the default. Lines are plain `KEY=value`.
- **Switches:** each switch has modes. `up` uses each switch's default, `--stubs` sets every shared switch to `stub`, `--app` sets `app` to `container`, and `--mode <switch>=<mode>` sets one switch. A mode activates the Compose profile `<switch>-<mode>` and sets its variables. `up` removes the services of modes that are no longer active.
- **Dependency stacks:** a mode with `"stack": "<VARIABLE>"` starts the stack in the checkout that `<VARIABLE>` names, with `up --app --name <this project>`, passing `--stubs` on. It reads that stack's `env --provides` and adds each value as `<SWITCH>_<KEY>`, plus `<SWITCH>_<KEY>_FROM_CONTAINER` with `localhost` replaced by `host.docker.internal`. `down` and `destroy` reach the dependency stacks too.
- **Commands:** `up`, `down` (keeps data and ports), `destroy` (removes everything, dependency stacks included), `status`, `env` and `compose -- <docker compose arguments>`.

## `stack.json`

```json
{
  "app": "backend",
  "ports": {"BACKEND_PORT": 8080, "DB_PORT": 5432, "GATEWAY_PORT": 8200, "CHATBOT_STUB_PORT": 18790, "COLLECTOR_STUB_PORT": 18791},
  "switches": {
    "app": {"default": "host", "modes": {
      "host": {"vars": {"BACKEND_FROM_GATEWAY": "http://host.docker.internal:${BACKEND_PORT}"}},
      "container": {"vars": {"BACKEND_FROM_GATEWAY": "http://app:8080"}}}},
    "chatbot": {"default": "real", "shared": true, "modes": {
      "real": {"vars": {"CHATBOT_URL": "https://chatbot.example.com", "CHATBOT_URL_FROM_CONTAINER": "https://chatbot.example.com"}},
      "stub": {"vars": {"CHATBOT_URL": "http://localhost:${CHATBOT_STUB_PORT}", "CHATBOT_URL_FROM_CONTAINER": "http://chatbot-stub:8080"}}}},
    "collector": {"default": "stub", "modes": {
      "stub": {"vars": {"COLLECTOR_URL": "http://localhost:${COLLECTOR_STUB_PORT}", "COLLECTOR_URL_FROM_CONTAINER": "http://collector-stub:8080"}},
      "stack": {"stack": "INSIGHTS_DIR", "vars": {"COLLECTOR_URL": "${COLLECTOR_API_URL}", "COLLECTOR_URL_FROM_CONTAINER": "${COLLECTOR_API_URL_FROM_CONTAINER}"}}}}
  },
  "vars": {"BACKEND_URL": "http://localhost:${GATEWAY_PORT}"},
  "provides": ["BACKEND_URL"]
}
```

This example is a fictional backend: take its shape, not its values.

- `app`: a short lowercase name for this repo's stack.
- `ports`: every host port the stack publishes or the app listens on, with its usual value: the one the app's configuration or docs use. Names end in `_PORT`.
- `switches.app`: modes `host` and `container`, for repos whose app runs in the IDE. Its variables are what changes when the app moves, such as the address a gateway forwards to.
- Other switches: one per external service or other repo. Modes are named `real`, `stub` and `stack`. `shared: true` marks a service other people use, which `--stubs` replaces. A shared switch has a `stub` mode. Every mode of a switch sets the same variables.
- `vars`: values that do not depend on a mode.
- `provides`: the values other repos' stacks may read. This is the stack's contract: changing a name breaks its consumers.
- Values use `${NAME}` for a port, an earlier value, a dependency value or a variable from the user's environment. A missing one stops `up` with its name. Secrets come from the user's environment this way; never write one into the repo.
- Name each address twice: `X_URL` as the host sees it, for the IDE and the stack file, and `X_URL_FROM_CONTAINER` as a container sees it.

## `compose.yaml`

- Never set `container_name`, a volume or network `name:`, or a fixed host port. Each published port is `"${X_PORT}:<container port>"`, with `X_PORT` from `stack.json`.
- Services that belong to a mode carry `profiles: [<switch>-<mode>]`. The app's container is `profiles: [app-container]`. Services without a profile always run.
- Build the app from the repo with `build: {context: .., dockerfile: <the app's Dockerfile>}`. If the app has no Dockerfile, write one under `local-stack/app/`. `up` always rebuilds, so the container runs the current working tree.
- Give every long-running service a healthcheck that passes only when it is ready, so `up` returns a working stack. Setup that runs once, such as migrations or seeding, is a service that the others depend on with `condition: service_completed_successfully`.
- Containers reach each other by service name. A container that calls the app in `host` mode or another repo's stack gets `extra_hosts: ["host.docker.internal:host-gateway"]`.
- Use only the default network. The offline proof replaces it.
- Read nothing from `.env` files. Every value comes from `stack.json`.

## The app's configuration

- **IDE mode:** the app reads the stack file through its own configuration mechanism, from `${LOCAL_STACK_FILE}` when that variable is set, otherwise from `local-stack/.stack.env`. Examples: Spring Boot `spring.config.import: optional:file:${LOCAL_STACK_FILE:local-stack/.stack.env}[.properties]`, Node `--env-file-if-exists`, Python `python-dotenv`. Map the stack's names to the app's own settings in that local configuration. Make the smallest change that does this, only in the configuration a local run uses, and leave the app's other environments alone. When the app has no mechanism for this, ask the user how they run it from the IDE.
- **Container mode:** the app's service in `compose.yaml` sets the same settings from the `_FROM_CONTAINER` values.

## Stubs

- One folder per switch under `stubs/`, run by a stock image or a small Dockerfile, with a healthcheck.
- Answer the endpoints the app's client calls, with the request and response shapes the client code uses, including streaming, pagination and the errors the client handles.
- Return fixed answers, so a run can be repeated.
- The README says what each stub does not cover.

## `README.md`

Written for developers and agents. Sections, in this order:

1. What the stack is, in two sentences.
2. `## Commands`: `up`, `up --app`, `--stubs`, `--mode`, `--name`, `down`, `destroy`, `status`, `env`, `compose`, each with one line.
3. `## Run the app from your IDE`: the exact steps for this app, and `LOCAL_STACK_FILE` for a named stack.
4. `## Services`: each service, with what it runs.
5. `## Switches`: a table of each switch, its modes, its default, whether it is shared, and what each stub does not cover.
6. `## Needs`: each other repo, the variable that holds its checkout, and the values used from it.
7. `## Provides`: each value in `provides`, with what it is.
8. `## Decisions`: each answer the user gave, one line with its date. A later run reads this section instead of asking again.
