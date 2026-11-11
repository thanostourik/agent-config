# Changelog

Each version lists what an existing stack must change to match it. A stack's README names the version it was built or last updated with. Each item says what to change and, after **Check:**, which proof steps of `SKILL.md` step 6 prove it. A new version adds small items in this shape; it never rewrites an earlier version.

## Version 19

A default stack starts on spare ports whenever something holds its usual ports. Before, it moved to spare ports only for another stack of the same repo and refused for anything else, so a worktree's `up` failed while another repo's stack with the same usual ports, such as 5432, was running.

- **Script:** copy `local-stack/stack` again. When something holds a usual port, `up` on the default stack now picks spare ports for every port and names what holds the usual ones, instead of stopping. **Check:** 2, while another repo's stack or any other process holds at least one usual port, when one does.
- **README:** replace any sentence saying `up` stops when something other than a stack of this repo holds the usual ports with one saying it then uses spare ports, as `stack-spec.md` says under "Ports". **Check:** none.

## Version 18

`attach` takes the other stack's name exactly as that stack's `up` and `status` print it, and nothing else. Before, it needed `<switch>=<name>` with the bare stack name, so `attach backend-main`, copied from the backend's `status`, failed.

- **Script:** copy `local-stack/stack` again. `attach <stack>` now takes the running stack as its `up` and `status` print it, such as `backend-main`, or its bare stack name, `main`. The switch comes from the repo that stack belongs to. `<switch>=<name>` is gone. **Check:** 6, with its attach part, copying each name from that stack's own `status`.
- **README:** replace each `attach <switch>=<name>` with `attach <stack>`, and say the name is the one that stack's `up` or `status` prints, such as `backend-main`, as `stack-spec.md` says under "`README.md`". Remove any sentence saying `status` prints a stack name that `attach` takes without its prefix. **Check:** none.

## Version 17

An app on the host starts without a stack file again, with its committed settings and the usual ports. Version 15 made it stop, which broke a developer's own runs, such as starting the app from the IDE against services they run themselves. Version 15's isolated tests stay, and agents still never start the app on the host without their own stack. These items change how the app is configured, so update step 4 reruns the whole proof.

- **Undo the stop without a stack file:** remove what version 15's item **No fallback to the usual ports** added, so a local run on the host without `local-stack/.stack.env` starts with its committed settings, as `stack-spec.md` says under "The app's configuration". The commit that built the stack or updated it to version 15 shows each piece:
  - Remove the startup check that stops the process when the stack file is missing, and the code added only for it, such as a Spring `EnvironmentPostProcessor` and its registration.
  - Put back each fallback to a usual port it removed from configuration only a local run reads, such as `${DB_PORT:5432}`, and remove each value it set again with no fallback in the local profile, so the shared configuration's fallback applies.
  - Leave the app's service in `compose.yaml`, the test configuration and the stack file import with its `LOCAL_STACK_SUMMARY` as they are.

  When you update from a version before 15, skip that item of version 15 instead. **Check:** 2 and 7. Skip 2 and 7.2 when no switch has a `host` mode.
- **README:** in `## Run the app on your machine`, replace the sentence saying the app stops without a stack and names `local-stack/stack up` with one saying it then uses its committed settings, with the usual ports, as `stack-spec.md` says under "`README.md`". **Check:** none.

## Version 16

A stack can use another repo's stack that already runs instead of starting one, and the app says at startup which stack it uses. Before, the stack always started its own copy of the other repo's stack, and an app gave no sign of which stack its stack file pointed at.

- **Script:** copy `local-stack/stack` again. The new command `attach <switch>=<name>` works like `up`, but the named switch takes its values from the other repo's stack that already runs under that stack name, in any checkout of that repo, found through Docker. It never starts, stops or changes that stack; `down` here deletes the stack file, which undoes the attach. The stack file now holds `LOCAL_STACK_SUMMARY`, one line naming the stack, each dependency or attached stack with its checkout, and that `local-stack/stack down` stops using it. **Check:** 6, with its new attach part; skip that part when no switch has a `"stack"` mode.
- **The app says which stack it uses:** when the app on the host loads the stack file, it prints `LOCAL_STACK_SUMMARY` once at startup, as `stack-spec.md` says under "The app's configuration". **Check:** 2.4. Skip it when no switch has a `host` mode.
- **README:** in `## Run the app on your machine`, say that the app prints at startup which stack it uses. When the stack starts another repo's stack, add `attach` to `## Commands`, add the steps to use a running stack of that repo to `## Run the app on your machine`, and mention `attach` in `## Needs`, as `stack-spec.md` says under "`README.md`". **Check:** none.

## Version 15

Nothing started in a checkout without its own stack may reach another stack. Before, an app or a test in such a checkout fell back to the usual ports and changed the developer's stack, such as by running a branch's migration on its database. These items change how the app is configured, so update step 4 reruns the whole proof; each item's check names the steps that prove it.

- **Script:** copy `local-stack/stack` again. Its message about spare ports no longer says the app expects the usual ports. **Check:** none.
- **Proof:** step 7, **Isolation**, is new, and cleanup is now step 8; in older versions' checks, 7 means cleanup. Until step 7 passes, run the repo's tests only as step 7 does, also while you make the changes below, and skip the check of earlier versions that starts the app on the host without a stack file: step 7.2 replaces it. **Check:** 7, then 8.
- **No fallback to the usual ports:** a local run on the host takes each value the stack provides from the stack file, never from a fallback such as `${DB_PORT:5432}` in a Spring profile or `process.env.DB_PORT ?? 5432`. Remove each such fallback from configuration only a local run reads. When it sits in configuration other environments may share, such as a `dev` profile, leave it there and set the value again, with no fallback, in configuration only a local run reads, such as the local profile. Make the process stop at startup when `local-stack/.stack.env` is missing or links to a deleted file, before it opens any connection, with a message that names the file and `local-stack/stack up`, as `stack-spec.md` says under "The app's configuration". The app's service in `compose.yaml` sets every value and skips the check, such as by leaving out the local profile. Tell the user about each existing local setup that relied on a fallback: it keeps working when it writes the stack file itself. In the README's `## Run the app on your machine`, replace any sentence saying the app starts without a stack with one saying it stops and names `local-stack/stack up`. **Check:** 1, 2 and 7.2. Skip 2 and 7.2 when no switch has a `host` mode.
- **Isolated tests:** change the app's test configuration as `stack-spec.md` says under "Tests", adding the test dependencies it needs, such as Testcontainers. Tests never read the stack file or the local configuration, and each service the stack provides that a test uses comes from a throwaway instance set once in the test configuration every test loads, with no fallback. Look at every test that starts the app or connects to a service, not only those that already start throwaway instances, such as a Spring `@SpringBootTest` class with no Testcontainers, which loads the default local profiles. When a service has no throwaway instance the tests can start, ask, as `questions.md` says. In the README's `## Run the app on your machine`, say that the tests need no stack. **Check:** 7.1.
- **`AGENTS.md`:** add the last line of [`agents-local-stack.md`](agents-local-stack.md), that tests need no stack, to the `## Local stack` section. **Check:** none.

## Version 14

- **Script:** copy `local-stack/stack` again. `up` no longer saves a folder: `--use <switch>=<folder>` names the other repo's clone for that one `up`, and `up` no longer reads one saved in git settings. The search next to this repo's main clone skips worktrees, so a worktree of the other repo there no longer makes `up` stop and ask for `--use`. When a stack already runs the other repo's stack from a different clone than this `up` picked, `up` stops before changing anything and says to `destroy` the stack or pick another name. In the README, describe `--use` as naming a clone for one run, and remove "once" from it in `## Commands` and `## Needs`. Remove a folder an earlier version saved with `git config --unset local-stack.<switch>.checkout`, when `git config --get-regexp '^local-stack\.'` shows one. **Check:** 6, with a worktree of the other repo added next to its clone first, then removed.

## Version 13

- **Script:** copy `local-stack/stack` again. `down` now prints `stack: stopped <container>` for each container it stops; before, it stopped them silently. **Check:** 3; `down` prints one line per container.

## Version 12

- **Memory limits:** give every long-running service in `compose.yaml` a `mem_limit` of about one and a half times what it uses during a busy run, at least `256m`, as `stack-spec.md` describes; change only the limit of a stock image, never its startup flags. **Check:** 1 and the busy run, then every service is healthy and none was killed for memory (`docker inspect -f '{{.State.OOMKilled}}'` prints `false`).

## Version 11

- **Script:** copy `local-stack/stack` again. A mode with a `"stack"` key now names the other repo by its path in its git remote, and `up` finds its clone next to this repo's main clone, or in the folder saved once with `up --use <switch>=<folder>`. Replace each `"stack": "<VARIABLE>"` in `stack.json` with that repo's path, such as `"stack": "my-org/catalog"`, and remove the variable everywhere it is mentioned: README, `AGENTS.md`, and the repo's own skills or scripts that read it. Something that needs the other clone's folder reads it from `status`, which prints each dependency's checkout. In the README, add `--use` to the commands and rewrite `## Needs` as `stack-spec.md` says. **Check:** 1, 2 and 6 with the variable unset in your shell; step 2 runs in a worktree outside the repo, which proves the clone is found from a worktree too. Leave your clones where they are; the skill's own proof covers `--use`. Finish with 7.

## Version 10

- **Script:** with the old script still in place, run `destroy` for each stack of this repo you no longer need and `down` for the rest, because the new script does not read the registry. Then copy `local-stack/stack` again. It keeps no registry: the default stack gets the usual ports, a stack started with `--name` gets spare ports from the system's ephemeral range, and each stack's record and lock live in `local-stack/`. `down` now stops the containers and keeps them. Once no repo on this machine runs an older script, delete `$XDG_STATE_HOME/local-stacks/` (by default `~/.local/state/local-stacks/`). **Check:** 1, 2 and 3; then copy the checkout, run `up --app --stubs --name lsproof-a` in both, and confirm the copy is refused; finish with 7.
- **`.gitignore`:** replace `.stack*.env` with `.stack*`, so the record and the lock stay out of git. **Check:** after `up`, `git status` shows no `.stack-*` file.
- **Usual ports:** each one sits below the start of the system's ephemeral range. Ask about each that does not, as `questions.md` says. **Check:** `up` on the default stack reports no port error.
- **App on the host:** `LOCAL_STACK_FILE` is gone. The app always reads `local-stack/.stack.env` from the repo root, through its framework's own configuration mechanism. Replace a run script or an IDE run configuration's environment file with that mechanism, and ask the user first when it changes how developers start the app. In the README, replace the `LOCAL_STACK_FILE` steps with a second copy in its own worktree. **Check:** 2, plus one start of the app without a stack file, which uses its committed settings.
- **Restart policy:** remove any `restart:` policy from `compose.yaml`, because `down` now keeps stopped containers. **Check:** none; read `compose.yaml`.

## Version 9

- **Script:** copy `local-stack/stack` again. A mode may now ask a dependency stack for modes and environment values with `"dependencies"`, and `${LOCAL_STACK_CHECKOUT}` names the checkout's root. A stack that needs another repo's stack to start differently, such as with a feature on or a file from this checkout, adds a switch for it in both stacks instead of a manual step. **Check:** 6 with each mode that has `dependencies`; when none has, `up` once to confirm the script still starts the stack.

## Version 8

- **Script:** copy `local-stack/stack` again. Every stack, the default one included, writes `local-stack/.stack-<name>.env` and keeps that path. `.stack.env` is now a link to the checked-out branch's stack file, which `up` of that stack points there; `down` and `destroy` leave it. Then run `up` once on the checked-out branch, which replaces the old `.stack.env` file with the link. **Check:** `up` on one branch, switch to another, `up` again, and confirm `.stack.env` links to `.stack-<new branch>.env` and `.stack-<first branch>.env` still holds the first stack's ports; `destroy --name <first branch>` and confirm `.stack-<new branch>.env` remains; start two `up --name lsproof-a` at once and confirm the second prints that it waits.

## Version 7

- **Script:** copy `local-stack/stack` again. After a branch switch, `up` of the new branch's stack moves the earlier stack's `.stack.env` to `.stack-<its name>.env`, so `destroy` of one stack no longer deletes the other's file. `up`, `down` and `destroy` on one stack now wait for each other. **Check:** start two `up --name lsproof-a` at once and confirm the second prints that it waits; then `up` on one branch, switch branches, `up` again, `destroy --name <first branch>`, and confirm the new branch's `.stack.env` remains.

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
