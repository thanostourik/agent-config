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

A stack may add folders its own services need, such as a certificate generator or a setup script.

Besides `local-stack/`, the skill changes only the app's local configuration, so that it reads the stack file, and the project's `AGENTS.md`.

## What `stack` does

- **Name:** the stack name defaults to the current branch; `--name` picks another. The Compose project is `<app>-<name>`, such as `backend-main`. Every container, volume, network and built image carries that project's label, which is what `destroy` removes. Every command except `status` refuses a stack whose claim belongs to another checkout.
- **Ports:** each port in `stack.json` is claimed in one registry per machine, `$XDG_STATE_HOME/local-stacks/`, shared by the stacks of every repo. A port gets its usual value when no other claim holds it and it is free, otherwise the lowest free port from 10000. A claim keeps its ports across `down` and `up` until `destroy`. A claim is released when another stack needs ports and the claim is abandoned: its `up` is not running, its stack file is gone, no dependency stack it started still holds a claim, and its project has no containers, volumes or networks left. So a stopped stack with data keeps its ports; a stopped stack without data may get other ports on its next `up`, which loses nothing.
- **Gateway address:** `up` sets `LOCAL_STACK_GATEWAY_IP` to the gateway of Docker's bridge network, usually `172.17.0.1`. Only this machine and its containers reach it.
- **Readiness:** `up` returns when every service of the active modes is running and healthy, or has exited with code 0, as setup jobs do. A service that exits with another code or turns unhealthy stops `up` with its name. A stack with no service in the active modes, such as one whose app runs on the host and whose only dependency is another repo's stack, skips Compose.
- **Stack file:** it exists only while the stack is up, so an app that reads it never finds a stopped stack's ports. The claim records its path, so commands find it after a branch switch. The claim also keeps the stack's values, so `destroy` works after `down`; like the stack file, it may hold secrets from the user's environment. `up` writes every value of the stack to `local-stack/.stack.env`, or to `local-stack/.stack-<name>.env` for a name other than the default. Lines are plain `KEY=value`.
- **Switches:** each switch has modes. `up` uses each switch's default, `--stubs` sets every shared switch to `stub`, `--app` sets `app` to `container`, and `--mode <switch>=<mode>` sets one switch. A mode activates the Compose profile `<switch>-<mode>` and sets its variables. `up` removes the services of modes that are no longer active before it starts the new ones.
- **Dependency stacks:** a mode with `"stack": "<VARIABLE>"` starts the stack in the checkout that `<VARIABLE>` names, with `up --app --name <this project>`, passing `--stubs` on. It reads that stack's `env --provides` and adds each value as `<SWITCH>_<KEY>`, plus `<SWITCH>_<KEY>_FROM_CONTAINER` with `localhost` replaced by `host.docker.internal`. `down` and `destroy` reach the dependency stacks too. A dependency stack that a later `up` no longer uses is stopped with `down` and stays recorded until `destroy` removes it.
- **Commands:** `up`, `down` (keeps data and ports, removes the stack file), `destroy` (removes everything, dependency stacks included), `status`, `env` and `compose -- <docker compose arguments>`.

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
- `switches.app`: every stack has it, because `--app` sets it to `container`. It has a `host` mode only when developers run the app on their machine, from the IDE or a terminal; otherwise `container` is its only mode and its default. Its variables are what changes when the app moves, such as the address a gateway forwards to.
- Other switches: one per external service or other repo. Name modes after what they do, such as `real`, `stub`, `stack` or `off`; a mode with `"stack"` starts another repo's stack. `shared: true` marks a service other people use, which `--stubs` replaces. A shared switch has a `stub` mode. Every mode of a switch sets the same variables.
- `vars`: values that do not depend on a mode.
- `provides`: the values other repos' stacks may read. This is the stack's contract: changing a name breaks its consumers.
- Values use `${NAME}` for a port, an earlier value, a dependency value or a variable from the user's environment. A missing one stops `up` with its name. Secrets come from the user's environment this way; never write one into the repo. A credential that exists only inside the stack, such as the stack database's password, is a fixed value in `compose.yaml`, not a secret.
- Name an address `X_URL` as the host sees it, for the IDE, the browser and the stack file. Add `X_URL_FROM_CONTAINER`, as a container sees it, only when a container uses that address.
- The app's own listening port in IDE mode is one of the `ports`, and the app's local configuration takes it from the stack file. Otherwise a developer's app holds a port that another stack has claimed.
- A stack that other repos start accepts them on any `localhost` port: CORS origins, login redirect addresses and allowed web origins use `http://localhost:*` patterns, never one consumer's port.

## `compose.yaml`

- Never set `container_name`, a volume or network `name:`, or a fixed host port. Publish each port twice, on this machine's loopback address and on the Docker gateway, so that other machines on the network never reach it:

  ```yaml
  ports:
    - "127.0.0.1:${X_PORT}:<container port>"
    - "${LOCAL_STACK_GATEWAY_IP}:${X_PORT}:<container port>"
  ```
- Services that belong to a mode carry `profiles: [<switch>-<mode>]`. The app's container is `profiles: [app-container]`. Services without a profile always run.
- Build the app from the repo with `build: {context: .., dockerfile: <the app's Dockerfile>}` when that Dockerfile builds a runnable image without values fixed for one environment. Otherwise write `local-stack/app/Dockerfile`, with `local-stack/app/Dockerfile.dockerignore` next to it. `up` always rebuilds, so the container runs the current working tree.
- Mount every volume the image declares (`VOLUME`) on a named volume, so `destroy` removes it.
- Give every long-running service a healthcheck that passes only when it is ready, so `up` returns a working stack. Setup that runs once, such as migrations or seeding, is a service that the others depend on with `condition: service_completed_successfully`. Setup that writes data the app later changes, such as seeded users or gateway consumers, runs only on a stack's first `up`, so a restart never undoes the app's changes.
- Containers reach each other by service name. A container that calls the app in `host` mode or another repo's stack gets `extra_hosts: ["host.docker.internal:host-gateway"]`.
- Use only the default network. The offline proof replaces it.
- Keep a developer's local override files, such as `.env.local`, `.env.*.local` and `application-local.yml`, out of the image and the containers. They override the stack's values, so a run meant to use fakes could reach a real server, and they can carry secrets into the image. Secrets a real mode needs come from the user's environment through `stack.json`.

## The app's configuration

- **IDE mode:** the app reads the stack file through its own configuration mechanism, from `${LOCAL_STACK_FILE}` when that variable is set, otherwise from `local-stack/.stack.env`. Examples: Spring Boot `spring.config.import: optional:file:${LOCAL_STACK_FILE:local-stack/.stack.env}[.properties]`, Node `--env-file-if-exists`, Python `python-dotenv`. Map the stack's names to the app's own settings in that local configuration. Make the smallest change that does this, only in the configuration a local run uses, and leave the app's other environments alone. When `LOCAL_STACK_FILE` is set and the file does not exist, the app stops with that path, instead of falling back to other local settings that may point at a real server. When the app has no mechanism for this, ask the user how they run it from the IDE.
- **Container mode:** the app's service in `compose.yaml` sets the same settings from the `_FROM_CONTAINER` values.

## Stubs

- One folder per switch under `stubs/`, run by a stock image or a small Dockerfile, with a healthcheck.
- Answer the endpoints the app's client calls, with the request and response shapes the client code uses, including streaming, pagination and the errors the client handles.
- Return fixed answers, so a run can be repeated.
- When the app's code fixes the address, such as a hard-coded hostname or an `https`-only client, the stub answers under the real hostname: give it that name as a network alias on the stack's network. For `https`, serve a certificate from a certificate authority that the stack generates and that only the stack's containers trust.
- The README says what each stub does not cover.

## `README.md`

Written for developers and agents. Sections, in this order:

1. What the stack is, in two sentences, and the line `Built with create-project-local-stack version <n>.`
2. `## Commands`: `up`, `up --app`, `--stubs`, `--mode`, `--name`, `down`, `destroy`, `status`, `env`, `compose`, each with one line.
3. `## Run the app from your IDE`: the exact steps for this app, and `LOCAL_STACK_FILE` for a named stack.
4. `## Services`: each service, with what it runs.
5. `## Switches`: a table of each switch, its modes, its default, whether it is shared, and what each stub does not cover.
6. `## Needs`: each other repo, the variable that holds its checkout, and the values used from it.
7. `## Provides`: each value in `provides`, with what it is.
8. `## Decisions`: each answer the user gave, one line with its date. A later run reads this section instead of asking again.
