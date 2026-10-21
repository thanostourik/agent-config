# create-project-local-stack skill

A shared skill, `skills/shared/create-project-local-stack/`, with the same
`harness` as `create-project-verification-skill`. It generates `local-stack/`
in a project repo: an isolated local stack that developers run with the app in
their IDE, and that agents run whole to verify their work. Any number of
stacks run at once, on one machine, from one or several repos.

## Two rules

- **Ask, never guess.** Every fact the stack depends on has a source: a file
  and line, or the user's answer. Anything else is a question, asked with the
  harness's question tool at run time (`AskUserQuestion` in Claude Code). The
  questions follow a fixed bank in `references/questions.md`. When the user
  does not know, that part is blocked and reported, and the rest goes on.
- **Every file is evidence, none is a template.** Discovery reads the whole
  repo, including any scripts or container files it already has for running
  locally. The stack follows the skill's spec, and it is built next to
  existing tooling, which it never edits or removes.

## One mechanism, copied unchanged

`references/stack` is a Python script with no extra packages. The skill copies
it into every repo as `local-stack/stack`, the way the verification generator
copies `drive.sh`, so every repo runs the version tested here. Each repo adds
only `stack.json`, `compose.yaml`, its stubs and a README.

- **Commands:** `up`, `down`, `destroy`, `status`, `env`, `compose`.
- **Names:** the Compose project is `<app>-<name>`. The name defaults to the
  branch, and agents pass `--name`. The repo is part of the name, so two repos
  on the same branch never share a project. One name used from two checkouts
  is refused.
- **Ports:** one registry per machine, `$XDG_STATE_HOME/local-stacks/`, shared
  by every repo. Each port gets its usual value when no other claim holds it
  and it is free, otherwise the lowest free port from 10000. Claims survive
  `down`, so stored URLs stay valid. A claim whose project left nothing in
  Docker, and whose `up` is not running, is released when ports are needed.
- **Stack file:** `local-stack/.stack.env`, or `.stack-<name>.env` for another
  name. The app's local configuration reads it itself, so a run from the IDE
  needs no setup.
- **Switches:** each external service, and the app itself, is a switch with
  modes. A mode sets variables and turns on the Compose profile
  `<switch>-<mode>`. `--app` runs the app in a container, `--stubs` stubs every
  shared service, and `--mode` sets one switch.
- **Other repos are black boxes.** A `stack` mode starts the other repo's own
  `local-stack/stack` under a related name, passes `--stubs` on, and reads
  only the values that stack lists under `provides`. Containers reach it
  through the host. There is no Compose `include` between repos.

## Steps the skill runs

1. Check Docker Compose v2 and Python. For an existing `local-stack/`, or a
   tool that manages the whole environment such as DDEV, the user chooses to
   go on or stop.
2. Discover from the whole repo: the app, its configuration, everything it
   talks to, what talks to it, its data, and the project's other repos.
3. Ask every open question.
4. Show the design on one screen and wait for a go.
5. Build `local-stack/`, the stubs, and the app's configuration change.
6. Prove it: agent mode and IDE mode at once, real modes only with the user's
   permission, an offline run that finds missed services, dependency stacks,
   and a cleanup that leaves nothing behind.
7. Write the README's decisions, the `AGENTS.md` section, commit and report.

## Left out for now

A wrapper for projects that run through a whole-environment tool such as DDEV.
It needs its own version of names, ports, switches and dependency stacks, and
it can only be tested on a real DDEV project. It gets built when the skill
first runs on one, such as `chatbot-drupal`. Until then the skill asks whether
to build a Compose stack or stop.

## Changes in this repo

- The skill: `SKILL.md`, `references/stack`, `references/stack-spec.md`,
  `references/questions.md`, `references/agents-local-stack.md`, and its
  `config.defaults.json` entry.
- `create-project-verification-skill`'s `lifecycle.md`: a project with
  `local-stack/stack` is launched through it. A project without a disposable
  setup goes through `/create-project-local-stack` first, and a verify skill
  never builds a stack in its `bin/`.

## Testing

- `references/stack` against real Docker, on a fixture of two repos where one
  needs the other.
- Blind runs of the skill on copies of the four ContentCloud repos, with
  `.agents/` and `dev_setup/` deleted, in dependency order: insights, backend,
  web, ccbot. Compare the services and questions it finds with the known ones:
  chatbot, collector, mail, MinIO.

## Afterwards, in the project repos

Slimming the existing verify skills onto the new stacks happens in each
project repo, with `/maintain-project-verification-skill`, after the blind
runs pass.
