# Changelog

Each version lists what an existing stack must change to match it. A stack's README names the version it was built or last updated with.

## Version 2

- `local-stack/stack`: copy it again. It records a dependency stack before starting it, waits for readiness itself (setup jobs that exit 0 are fine, so `ready`-style services are no longer needed), skips Compose when no service is active, sets `LOCAL_STACK_GATEWAY_IP`, keeps a claim while its stack file exists or a dependency stack it started is claimed, and removes the stack file on `down`.
- Ports: publish each one on `127.0.0.1` and on `${LOCAL_STACK_GATEWAY_IP}` only.
- A stack other repos start accepts them on any `localhost` port.
- The app's own port in IDE mode comes from the stack file. When `LOCAL_STACK_FILE` is set and the file is missing, the app stops with that path.
- Seed data the app later changes applies only on a stack's first `up`.
- The app image never takes untracked local files; every `VOLUME` an image declares is mounted on a named volume.
- Mode names are free; `X_URL_FROM_CONTAINER` exists only when a container uses the address.
- Proof: IDE mode runs with `--stubs`; every `stack` mode is proved with `lsproof-c`; the offline step uses `compose -- down` and the README lists what image builds download.
- README: the first section names the skill version.

## Version 1

The first version.
