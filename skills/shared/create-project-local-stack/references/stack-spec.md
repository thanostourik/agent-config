# Local stack spec

What `local-stack/` contains and the rules each file follows. The copied `stack` script relies on these rules; a stack that breaks one fails in parallel or across repos. The words used here are defined in `SKILL.md` under "Words".

## Files

```
local-stack/
  stack            copied unchanged from the skill, executable
  stack.json       ports, switches, values and what this stack provides
  compose.yaml     every service of the stack
  stubs/<switch>/  one stub per switch that has a stub mode, when no emulator fits
  README.md        usage, provided values and decisions
  .gitignore       .stack*.env and .facts.md
```

A stack may add folders its own services need, such as a certificate generator or a setup script.

Outside `local-stack/`, the design the user approves covers the app's local configuration change and the `AGENTS.md` lines it names. Any other file outside `local-stack/` needs the user's permission first, asked in one short question that names the file, shows the exact change, says in one sentence why the stack needs it, and says what happens without it. Example: "May I add `build/` to `.dockerignore`? Docker otherwise copies that git-ignored folder into the image. Without it, nothing breaks."

## What `stack` does

- **Name:** the stack name defaults to the current branch; `--name` picks another. The Compose project is `<app>-<name>`, such as `orders-main`. Every container, volume, network and built image carries that project's label, which is what `destroy` removes. Every command except `status` refuses a stack whose claim belongs to another checkout.
- **Ports:** each stack's ports are recorded in a registry shared by every repo on this machine, `$XDG_STATE_HOME/local-stacks/`. A port gets its usual value if it is free, otherwise the lowest free port from 10000. After `down`, a stack keeps its ports while it still has data or a dependency stack. A stopped stack with neither can lose its ports to another stack, which costs nothing. `destroy` always frees them.
- **Gateway address:** `up` sets `LOCAL_STACK_GATEWAY_IP` to the gateway of Docker's bridge network, usually `172.17.0.1`. Only this machine and its containers reach it.
- **Readiness:** `up` returns when every service of the active modes is running and healthy, or has exited with code 0, as setup jobs do. A service that exits with another code or turns unhealthy stops `up` with its name. A stack with no active service skips Compose.
- **Stack file:** `up` writes every value of the stack as `KEY=value` lines to `local-stack/.stack.env`, or to `local-stack/.stack-<name>.env` for a name other than the default. `down` deletes it, so an app never reads a stopped stack's ports. The claim records the file's path and the values, so commands still work after the developer checks out another branch, and `destroy` works after `down`. Both may hold secrets from the user's environment.
- **Modes:** `up` uses each switch's default. `--stubs` sets every shared switch to `stub`, `--app` sets every switch that has a `container` mode to `container`, and `--mode <switch>=<mode>` sets one switch. A mode turns on the Compose profile `<switch>-<mode>` and sets its variables. `up` removes the services of modes no longer chosen before it starts the new ones.
- **Dependency stacks:** a mode with `"stack": "<VARIABLE>"` starts the stack in the checkout that `<VARIABLE>` names, with `up --app --name <this project>`, passing `--stubs` on. It reads that stack's `env --provides` and adds each value as `<SWITCH>_<KEY>`, plus `<SWITCH>_<KEY>_FROM_CONTAINER` with `localhost` and `127.0.0.1` replaced by `host.docker.internal`. `down` and `destroy` reach the dependency stacks too. A dependency stack that a later `up` no longer uses is stopped and stays recorded until `destroy` removes it.
- **Commands:** `up`, `down` (stops the stack, keeps its data, removes the stack file), `destroy` (removes everything, dependency stacks included), `status`, `env` and `compose -- <docker compose arguments>`.

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
      "stack": {"stack": "CATALOG_DIR", "vars": {"CATALOG_URL": "${CATALOG_API_URL}", "CATALOG_URL_FROM_CONTAINER": "${CATALOG_API_URL_FROM_CONTAINER}"}}}}
  },
  "vars": {"ORDERS_API_URL": "http://localhost:${API_PORT}", "ORDERS_QUEUE_ADDR": "localhost:${QUEUE_PORT}"},
  "provides": ["ORDERS_API_URL", "ORDERS_QUEUE_ADDR"]
}
```

- `app`: a short lowercase name for this repo's stack.
- `ports`: every host port the stack publishes or the app listens on, with its usual value: the one the app's configuration or docs use. Names end in `_PORT`.
- **A switch per process:** each process this repo runs gets a switch, named `app` when there is one and `app-<process>` when there are several, such as `app-api` and `app-worker`. It has a `container` mode when agents run it in a container, and a `host` mode when developers run it on their machine; its default is `host` when it has one. Its variables are what changes when the process moves, such as the address a proxy forwards to; they may be empty. A repo that runs no process, such as a library, has no such switch.
- **Other switches:** one per outside service or other repo. Name modes after what they do, such as `real`, `stub` or `off`; a mode with a `"stack"` key starts another repo's stack. `shared: true` marks a shared service, which needs a `stub` mode. Every mode of a switch sets the same variables.
- `vars`: values that do not depend on a mode.
- `provides`: the values other repos' stacks may read. Other repos depend on these names, so renaming one breaks them.
- Values use `${NAME}` for a port, an earlier value, a dependency value or a variable from the user's environment. A missing one stops `up` with its name. Secrets come only from the user's environment this way, never from a file in the repo. A credential that exists only inside the stack, such as the stack database's password, is a fixed value in `compose.yaml`, not a secret.
- **Address names:** a URL is `X_URL`, a host and port without a scheme is `X_ADDR`, a bare host is `X_HOST`, each as the host sees it. Add the same name with `_FROM_CONTAINER`, as a container sees it, only when a container uses that address.
- When a process runs on the host, the port it listens on is one of the `ports`, and its configuration takes it from the stack file. Otherwise it may hold a port another stack has claimed.
- When the stack checks who calls it, by origin, redirect address or allowed host, it accepts any `localhost` port, because other repos' stacks call it from ports it cannot know.

## `compose.yaml`

- Never set `container_name`, a volume or network `name:`, or a fixed host port. Publish each port on exactly two addresses: `127.0.0.1` for this machine, and the Docker gateway so containers of other stacks can reach it. Binding to all addresses would let other machines on the network reach it. Bind to another address only when the user allows it, for a client on another device such as a phone.

  ```yaml
  ports:
    - "127.0.0.1:${X_PORT}:<container port>"
    - "${LOCAL_STACK_GATEWAY_IP}:${X_PORT}:<container port>"
  ```
- A service that belongs to a mode carries `profiles: [<switch>-<mode>]`, such as `app-container` or `payments-stub`. Services without a profile always run.
- Build a process from the repo with `build: {context: .., dockerfile: <its Dockerfile>}` when that Dockerfile builds a runnable image without values fixed for one environment. Otherwise write `local-stack/<process>/Dockerfile`, with a `Dockerfile.dockerignore` next to it. `up` always rebuilds, so the container runs the current working tree.
- Keep the local override files that discovery found, such as `.env`, `.env.local` or `application-local.yml`, out of every image and container. They override the stack's values, so a run with stubs could reach a real server.
- Mount every volume an image declares (`VOLUME`) on a named volume, so `destroy` removes it.
- Give every long-running service a healthcheck that passes only when it is ready, so `up` returns a working stack. Setup that runs once, such as migrations, is a service the others depend on with `condition: service_completed_successfully`. Setup that writes data the app later changes, such as seeded accounts or rows the app updates, runs only on a stack's first `up`, so a restart never undoes the app's changes.
- Containers reach each other by service name. A container that calls a process on the host or another repo's stack gets `extra_hosts: ["host.docker.internal:host-gateway"]`.
- Use only the default network. The offline proof replaces it.

## The app's configuration

- **On the host:** the process reads `LOCAL_STACK_FILE` when it is set, and stops with that path when the file is missing, so a typo never falls back to settings that may point at a real server. When the variable is not set, it reads `local-stack/.stack.env` from the repo root, if that exists. Three ways to do this, and when more than one fits, ask the user which:
  - the app's own configuration loader, in the configuration a local run uses only;
  - the IDE run configuration's environment file, for apps that read only environment variables;
  - a small run script in `local-stack/` that exports the file and starts the app.

  Example: Node's `--env-file` stops on a missing file; `--env-file-if-exists` does not. Map the stack's names to the app's own settings there, and leave the app's other environments alone.
- **In a container:** the process's service in `compose.yaml` sets the same settings from the `_FROM_CONTAINER` values.

## Stubs

- Prefer an emulator or a local instance of the same product, such as LocalStack for AWS services, Mailpit for mail, or the broker itself for a message queue. Write a stub yourself only when none exists.
- A stub you write answers what the app's client code sends, in its protocol, with the response shapes, streaming, paging and errors the client handles. Its answers are fixed, so a run can be repeated.
- Run each stub from a stock image or a small Dockerfile under `stubs/<switch>/`, with a healthcheck.
- When the app's code fixes the address, such as a hard-coded hostname or an `https`-only client, the stub answers under the real hostname: give it that name as a network alias on the stack's network. For `https`, serve a certificate from a certificate authority that the stack generates and that only the stack's containers trust.

## `README.md`

Written for the developers who use the stack. Sections, in this order:

1. What the stack is, in two sentences, and the line `Built with create-project-local-stack version <n>.`
2. `## Commands`: `up`, `up --app`, `--stubs`, `--mode`, `--name`, `down`, `destroy`, `status`, `env`, `compose`, each with one line.
3. `## Run the app on your machine`: the exact steps for this app, and `LOCAL_STACK_FILE` for a named stack.
4. `## Services`: each service, with what it runs.
5. `## Switches`: a table of each switch, its modes, its default, whether it is shared, and what each stub does not cover.
6. `## Needs`: each other repo, the variable that holds its checkout, and the values used from it.
7. `## Provides`: each value in `provides`, with what it is.
8. `## Decisions`: each answer the user gave, one line with its date. A later run reads this section instead of asking again.
