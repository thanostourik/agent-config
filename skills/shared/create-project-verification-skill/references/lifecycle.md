# Isolation, ownership and cleanup

Goal: verification never changes what the developer uses. That means their running services, data, sessions and configuration. The generated `verify-<app>` writes the project's concrete version of these rules in its Isolation, Launch, Doctor and Cleanup sections.

## Choose the isolation level once

Pick one level while generating. Write it into the generated Isolation section as `Isolation level: <level>`, with one line on why.

- **full** (default): every run uses an environment that verification owns.
- **shared**: the project cannot create an owned environment, and the user approved named shared resources.
- **checks-only**: no live driving. The skill names the focused tests, lint and type checks to run instead. Live steps are reported `blocked: no isolation`.

Aim for **full**. If the project has no disposable setup, propose one and implement it within the scope the user approves. Only when that fails or the user declines, ask the user which of the other two levels they want. Do not choose for them. Never assume read-only access to a running developer instance is acceptable.

## Ownership

An environment is **owned** when the ownership record in `.cache/` lists it and each of its resources carries a marker the project can check: a compose project name, a container label, a data directory path, a port the run picked. A local URL, a branch name or a separate container project name is not a marker.

- Use the project's own disposable-environment setup when it creates owned resources (a dev script, a compose profile, a devcontainer). Do not invent a second mechanism next to it.
- Each run starts from a known baseline. The default is to create a fresh environment. An owned environment left by an earlier run may be reused if every marker still checks out. Reseed it to the baseline first.
- Anything not owned is off limits: never attach to it, change it, reset it or stop it. If a required port or resource is occupied, report a blocker.
- If ownership is uncertain, report a blocker. Never wipe an environment to hide missing cleanup.

## Before the first start

- Trace where startup and driving can send writes: dependencies, gateways, storage, email, background jobs. Point them at disposable destinations or disable them. Check the effective configuration.
- Record what exists before the run and how to restore it.
- Note the success paths that isolation makes unreachable. A disabled dependency's error path does not prove its success path.
- Inspect startup commands for side effects on files, data and processes. After choosing isolation and cleanup, launch once and compare against the recorded original state.
- If the app watches files and reloads, write into `.cache/` while it runs. A reload means asking the user.

## Lifecycle

- Register every resource in the ownership record as it is created, before waiting for readiness. Cleanup then works after a partial startup.
- Every run restores the original state on success, failure and interruption. It removes its own data, sessions, files, databases, containers, volumes and networks. It stops its recorded processes, never by process name. It restores changed configuration. Pre-existing resources stay untouched. Evidence stays.
- Generate the exact cleanup commands for this project, with failure handling, in the lifecycle helpers.
- After an abrupt kill, recover only resources the ownership record proves the earlier run left. Do this before checking that required resources are free.
- If cleanup fails, keep the ownership record, report what remains and how to finish. Do not claim completion.

## Shared level

Use it only when the user chose it. Write these rules into the generated skill.

- The approved resources are listed by name in the Isolation section. Nothing else is touched.
- One driver at a time. Do not drive while anyone else is using the resource.
- Reads are free. Writes go only to fixtures the run creates, named with the run id, and removed in cleanup.
- Doctor checks that the targeted resources are the approved ones, for example the right host and database name, and refuses anything else.
- A step that needs a write outside a marked fixture, or a resource that is not on the approved list, asks the user first and names the resource.
- Deployed and remote services are never eligible. Report those steps blocked.
- Every report is labeled `lower confidence: shared <resources>`.
