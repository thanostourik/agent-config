# Changelog

Each version lists what an existing stack must change to match it. A stack's README names the version it was built or last updated with. Each item says what to change and, after **Check:**, which proof steps of `SKILL.md` step 6 prove it. A new version adds small items in this shape; it never rewrites an earlier version.

## Version 6

- **Proof action:** it is no longer asked or recorded; each run picks it from the code. Remove the Decisions line that names it. **Check:** none.

## Version 5

- **Script:** copy `local-stack/stack` again. `--app` now sets every switch that has a `container` mode, so a repo with several processes or with none works. A dependency value without `//`, such as `localhost:9092`, now also gets its `_FROM_CONTAINER` copy with `host.docker.internal`. **Check:** 1, and 6 when a dependency stack provides a host-and-port value.
- **Processes:** a repo that runs several processes gives each its own switch, `app-<process>`; a repo that runs none needs no `app` switch. **Check:** none when the repo runs one process; otherwise 1.
- **Proof action:** the questions now ask which action proves the app works. If the README's Decisions don't name it, ask and record it. **Check:** 1 with that action.
- **Local override files:** found from `.gitignore` and the framework, such as a plain `.env`, not only from a fixed list; the design lists them. **Check:** 1 with a planted file of each kind found.
- **App on the host:** a set but missing `LOCAL_STACK_FILE` stops the process, and the default path is resolved from the repo root. **Check:** 2, plus one start with a missing file. Skip when no switch has a `host` mode.
- **README:** section 3 is `## Run the app on your machine`. **Check:** none.

## Version 4

- **Image contents:** version 2's rule against untracked files is replaced by a specific one: the image and the containers never take a developer's local override files, such as `.env.local`, `.env.*.local` and `application-local.yml`. Untracked code may go in. Remove any Decision recorded as an exception to the old rule. **Check:** none when the stack already keeps those files out; otherwise 1 with a planted `.env.local`.

## Version 3

- **Script:** copy `local-stack/stack` again. **Check:** each item below.
- **Other checkouts:** `down`, `destroy`, `env` and `compose` refuse a stack that another checkout owns, as `up` already did. **Check:** copy the checkout, `up` a proof stack in the copy under the name a stack of the original uses, then `destroy` it in the copy; both are refused and the original's stack still runs.
- **Unused dependency stacks:** switching a `stack` mode to another mode stops that dependency stack and keeps its record, so `destroy` still removes it. **Check:** `up` with `--mode <switch>=stack`, `up` with another mode, confirm the dependency stack is stopped, then `destroy` and confirm it is gone. Skip when no switch has both kinds of modes.
- **Mode switch order:** `up` removes the services of inactive modes before starting the new ones, so two modes may publish the same port. **Check:** switch a mode on a running stack.
- **Stack file after a branch switch:** commands use the stack file path the claim recorded. **Check:** `up` on one branch, switch branches, `down --name <first branch>`, and confirm the file is gone.
- **Cleanup after `down`:** the claim keeps the stack's values, so `destroy` after `down` works when `compose.yaml` takes non-port values. **Check:** `down`, then `destroy`, then 7.

## Version 2

- **Script:** copy `local-stack/stack` again. It records a dependency stack before starting it, waits for readiness itself (setup jobs that exit 0 are fine, so `ready`-style services are no longer needed), and skips Compose when no service is active. **Check:** 1, 2 and 7.
- **Port claims:** the new script keeps a claim while its stack file exists or while a dependency stack it started is claimed. **Check:** `down` one proof stack, `up` another, and confirm the first keeps its ports; then `destroy` the first and confirm its dependency stacks are gone.
- **Stack file on `down`:** the new script removes it; the next `up` writes it again with the same ports. Fix README lines that say otherwise. **Check:** `down`, then confirm the file is gone, then `up` and compare the ports.
- **Ports:** publish each one on `127.0.0.1` and on `${LOCAL_STACK_GATEWAY_IP}` only. **Check:** 1, plus a request to the machine's network address that gets no answer.
- **Consumers on any port:** a stack other repos start accepts them on any `localhost` port. **Check:** 6, from a consumer on a port other than its usual one.
- **IDE port and missing stack file:** the app's own port in IDE mode comes from the stack file; when `LOCAL_STACK_FILE` is set and the file is missing, the app stops with that path. **Check:** 2, plus one start with a missing file.
- **Seed data:** seed data the app later changes applies only on a stack's first `up`. **Check:** change seeded data as the app would, run `up` again, and confirm the change survives.
- **Image contents:** the app image never takes untracked local files, and every `VOLUME` an image declares is mounted on a named volume. **Check:** 1 with a planted untracked file, and 7.
- **Names:** mode names are free; `X_URL_FROM_CONTAINER` exists only when a container uses the address. **Check:** none; read `stack.json`.
- **Proof procedure:** IDE mode runs with `--stubs`, every `stack` mode is proved with `lsproof-c`, the offline step uses `compose -- down`, and the README lists what image builds download. **Check:** 2, 5 and 6.
- **README:** the first section names the skill version. **Check:** none.

## Version 1

The first version.
