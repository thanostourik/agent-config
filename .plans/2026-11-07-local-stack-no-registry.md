# Local stack without the port registry

The `create-project-local-stack` script keeps a registry of port claims in
`$XDG_STATE_HOME/local-stacks/`. Those claims go stale. Two crashed agent
stacks kept the backend's usual ports forever, so the developer's own stack got
10001+ and the frontend's committed settings stopped working. 204 lock files
also piled up there. The root flaw is "a port gets its usual value if it is
free": first come, first served, so agents can take the developer's ports.

This change removes the registry. Nothing is written outside the repos, and no
Docker object is used as bookkeeping. Copying the new script into the project
repos is a later, separate step.

## Words

- **Usual port:** a port's value in `stack.json`, the one the app's committed
  settings use.
- **Spare port:** a port the OS hands out when asked for any free port (bind
  to port 0). The OS takes these only from its ephemeral range: Linux reads it
  from `/proc/sys/net/ipv4/ip_local_port_range` (32768–60999 here), macOS from
  `sysctl net.inet.ip.portrange.first/last` (49152–65535).
- **Published port:** a port a container of the stack binds on the host, read
  from `docker compose config` for the active modes. A port the app binds
  itself on the host, such as the backend's 8080 in IDE mode, is not published.

## Who gets which ports

1. **The default stack** (the one named after the branch, the developer's)
   gets the usual ports. If a published usual port is taken by something that
   is not a stack, `up` stops and names the holder: the container or the
   process and its PID. A port the app binds itself is not checked, so the
   app may start before the stack.
2. **An additional default stack** (a second worktree's) gets spare ports when
   any published usual port is held by another stack's container. It gets
   spare ports for every key, the app's port included, so it never takes a
   port the first stack's app needs. `up` prints which stack holds the usual
   ports.
3. **A named stack** (`--name`, which agents and dependency stacks always use)
   always gets spare ports.

Spare ports never equal a usual port, because every usual port must sit below
the ephemeral range. `up` checks this, and the skill tells the generator to
check it.

Deviation from the approved wording: the approved design said "`up` without
`--app`" for the developer and "`--app`" for agents. This plan decides by name
instead, because it matches the roles exactly: agents always pass `--name`,
the developer never needs it. Two cases differ: a frontend developer running
`up --app` in the backend repo to get the backend in a container keeps the
usual ports, so the frontend's committed settings work; an agent running
`up --name x` without `--app` still gets spare ports, so it never takes the
developer's ports.

## Reuse and races

- A stack's record keeps its ports. The next `up` reuses a recorded spare port
  when it is still free or held by this stack's own containers. It reuses
  only recorded ports in the ephemeral range, so a stack that moved to spare
  ports never keeps a usual one.
- The default stack moves back to the usual ports as soon as they are free.
- When `docker compose up` fails, `up` checks each published port. A port now
  held by something else was lost in the window between picking and binding.
  `up` prints that, picks a new spare port and tries again, up to three
  times. A lost usual port stops `up` with its holder instead. Ports are never
  shared silently: Docker refuses a second bind.
- Known, accepted gap: an additional default stack's app port is not held
  while the app is stopped, so an agent's spare pick may take it. The app then
  fails with "port in use", and the next `up` picks again.

## State in the repo

All files live in the checkout's git-ignored `local-stack/`:

- `.stack-<name>.env`: the stack file, as today. `down` deletes it, so an app
  never reads a stopped stack's ports.
- `.stack-<name>.json`: the record: modes, ports, values and dependency
  stacks. It replaces the claim. `destroy` deletes it.
- `.stack-<name>.lock`: the per-stack lock. A command that ends with no
  record (`destroy`, or a refused or failed first `up`) deletes it while
  holding it; a waiting command notices the file was replaced and locks again.
- `.gitignore` becomes `.stack*` and `.facts.md`.

## Ownership

"This stack belongs to another checkout" reads Compose's own
`com.docker.compose.project.working_dir` label on the project's containers.
Compose sets it only on containers, not on volumes or networks. So `down` now
stops the containers instead of removing them, which keeps the label until
`destroy`. Stopped containers hold no ports.

## No `LOCAL_STACK_FILE`

An app on the host always reads its checkout's `local-stack/.stack.env`,
through its framework's own configuration mechanism (for example Spring's
`spring.config.import: optional:file:...` or Next.js config), never a wrapper
script, an IDE-only setting or a variable the developer sets. When the file is
missing, the app uses its committed settings, which are the usual ports.
Parallel host runs use one worktree each, where `.stack.env` links to that
worktree's default stack. `--name` stays for agents, whose app runs in a
container.

## Files

- `references/stack`: drop the registry and the abandoned-claim logic; add
  port picking, published ports, the retry, the in-repo record and lock, the
  label-based ownership check, `down` as `compose stop`.
- `references/stack-spec.md`: the rules above; app configuration without
  `LOCAL_STACK_FILE`; `.gitignore`; README section 3.
- `SKILL.md`: words; ephemeral range check in step 5; proof step 2 in a
  temporary worktree (the stack is committed before the proof so the worktree
  has it); port checks in step 3; cleanup checks the in-repo files.
- `references/changelog.md`: version 10, with the migration (stop old stacks
  with the old script, delete the registry once no repo uses it).
- `references/questions.md`: the stack file question without the removed
  options.

## Proof

On two fixture repos in the scratchpad, one starting the other as a
dependency stack, with the real Docker:

- several named stacks in parallel across both repos, all on distinct spare
  ports, each seeing only its own data;
- `down` and `up` keep the ports; a recorded port taken while down is picked
  again alone;
- a stack whose `up` is killed, and one whose containers are killed, leave
  nothing that blocks ports: the default stack still gets the usual ports;
- a named `up` while the default stack holds the usual ports gets spare ports;
  a second worktree's default stack gets spare ports and says why;
- a usual port held by a plain process stops the default `up` with its PID;
- a port taken during the race window is reported and picked again;
- the same name from a second checkout is refused, running and after `down`;
- a usual port in the ephemeral range is refused;
- an app on the host reads `.stack.env` with no variable set;
- cleanup leaves no Docker object, stack file, record or lock;
- no file under `~/.local/state` is created or changed.

Plus the repo's own checks: the unit tests and `./sync` into a temporary home.
