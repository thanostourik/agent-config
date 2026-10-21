# create-project-local-stack skill

A shared skill, `skills/shared/create-project-local-stack/`, with the same
`harness` as `create-project-verification-skill`. It generates `local-stack/`
in a project repo: an isolated local stack that a person runs with the app in
their IDE, and that an agent runs whole to verify its work.

The skill never reads or edits the project's existing local environment: dev
scripts, local compose files, verify skills. The stack must come from the code
and the user's answers, or the run proves nothing.

The skill never decides anything on its own. Every fact the stack depends on
comes from the repo or from the user. When neither settles a fact, the skill
asks.

## What it writes

```
local-stack/
  stack.sh        the only command people and agents use
  compose.yaml    the stack's services
  stubs/<name>/   one fake per external service that has a stub mode
  README.md       usage, contract, external services, Decisions
```

The mechanism is Docker Compose. A project that already uses its own
environment tool, such as DDEV, gets that tool wrapped behind the same
`stack.sh` commands instead.

## The fixed interface

The skill carries it in `references/stack-spec.md`. It is the same for every
project.

- **Commands:** `stack.sh up | down | status | env`.
- **Two run modes:**
  - `up` starts everything except the app. The person runs the app in the IDE.
  - `up --app` also runs the app in a container. Agents use this.
  - Services that call the app, such as a gateway, point at the container in
    the first case and at the host in the second.
- **Name and ownership:** the stack name defaults to the branch, and callers
  can pass `--name`. One stack is one Compose project. `down` removes only
  resources with that project's label, plus the dependency stacks it started.
- **Env file:** `up` writes every URL, port and token of the stack into one
  file. An IDE run configuration loads it, and `env` prints it.
- **Ports:** every `up` gets free ports, so any number of stacks run side by
  side. The env file holds them, so the IDE and agents read them from there.
- **External services:** each has the modes `real` and `stub`. A service that
  is another repo of the project also has `stack`. Plain `up` uses the
  defaults the user chose. `--mode <service>=<mode>` overrides one service.
  `--stubs` stubs every shared service.
- **Other repos are black boxes.** A consumer knows three things about a
  dependency: the variable that holds its checkout path, its `stack.sh`, and
  the variables listed under Provides in its README. The consumer's `up` calls
  the dependency's `stack.sh up --app` under a related name and passes
  `--stubs` through. Its `down` calls the dependency's `down`. There is no
  Compose `include` between repos. If the dependency has no `local-stack/`,
  the skill stops and tells the user to generate that one first.

## No improvising

- **Every fact has a source:** a file and line, or the user's answer.
  Anything else becomes a question.
- **Questions go through the harness's question tool** at run time:
  `AskUserQuestion` in Claude Code, and its counterpart in the other tools.
  Only a harness without such a tool gets the questions in the reply. Then the
  skill waits.
  - An unanswered question is asked again.
  - When the user does not know, that part is reported as blocked, and the
    rest goes on.
- **Format:** each question asks for one decision. It shows the evidence
  found, the options with a recommendation, and what each answer changes.
  Questions are sent in rounds, as many at once as the tool allows.
- **Question bank,** in `references/questions.md`:
  - Asked for every external service: Is it shared with other people? Does
    calling it have side effects that matter? Which mode does a plain `up` use?
  - Asked for every service that may belong to the project: Is X another repo
    of this project, and where is its checkout?
  - Asked when a fact is unresolved: how the app runs, seed data, how to get
    a test user, where a developer gets each required secret. Secrets are
    never invented.
  - Asked on conflict: two sources disagree. The question shows both, for
    example "README says 8080, compose says 8200".
- **What is kept:**
  - Observed facts live in a working file during the run, and the skill
    deletes it at the end. Code moves, so committed copies would go stale.
  - Only the user's answers are committed, one line each, in the `Decisions`
    section of the README. A later run reads them instead of asking again.

## Steps the skill runs

If `local-stack/` already exists, the skill stops and asks whether to replace
it.

1. **Discover,** read-only. Read the README, `PLATFORM.md` and the docs they
   link. Read the config of every profile, the environment variables, the HTTP
   clients, the gateway routes and the app's Dockerfile. Write the working
   fact list.
2. **Ask** every open question.
3. **Show the design** on one screen: services, external services with their
   modes and defaults, and dependency stacks. Wait for the user's go.
4. **Build** `local-stack/`. Build each stub from the requests and responses
   in the client code.
5. **Prove it:**
   - `up --app` from clean, and the app answers.
   - `up`, then the skill starts the app on the host from the env file, as an
     IDE would, and it answers.
   - An offline run, with all outside traffic blocked. Each blocked
     connection is a service the reading missed, and it becomes a new
     question, not a silent stub.
   - Two stacks in parallel, with no collision.
   - `--stubs` reaches the dependency stacks.
   - `down` leaves nothing, and resources that existed before are unchanged.
6. **Hand over.** Write the README and a short `Local stack` pointer in
   `AGENTS.md`. Then report what is proved, what is blocked, and what each stub
   does not cover.

## Changes in this repo

- Add the skill: `SKILL.md`, `references/stack-spec.md`,
  `references/questions.md`, and an entry in `config.defaults.json`.
- In `create-project-verification-skill`, `references/lifecycle.md` gets a new
  rule. A project without a full disposable stack goes through
  `/create-project-local-stack` first. The stack is never built in the verify
  skill's `bin/`. The verify skill launches it with
  `stack.sh up --app --stubs --name <run name>`.

## Testing that it is generic

- Run the skill blind on copies of the four ContentCloud repos, with
  `.agents/` and `dev_setup/` deleted, in dependency order: insights, backend,
  web, ccbot.
- Compare the external services and questions it finds with the known ones:
  chatbot, collector, mail, MinIO.
- Run it on one project outside ContentCloud that has its own environment
  tool, such as `chatbot-drupal` with DDEV.

## Afterwards, in the project repos

Slimming the existing verify skills onto the new stacks happens in each
project repo, with `/maintain-project-verification-skill`, after the blind
runs pass.
