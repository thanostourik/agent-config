# Verification skills in a companion repo

## Goal

Some projects must not show that agents work on them: no `AGENTS.md`, no
`.agents/`, no `.gitignore` entries in the client's repo. The verification
skills then live in a separate **companion repo**, a normal git repo next to
the app checkouts that holds only the agent files.

## Design

- `/create-project-verification-skill` first checks whether the current repo
  holds app source. When it does not, it is a companion: the generator asks for
  the path of each app checkout before anything else.
- The generated skill saves those paths in `verify-<app>/apps`, one line per
  app, `<name> <path>`, the path relative to the companion root, such as
  `otis ../otis`.
- `steps.sh` gets `export_apps`. It exports `APP_<NAME>` (name upper-cased,
  `-` as `_`) for each line, unless the caller already set it, so a run can
  point at another checkout: `APP_OTIS=~/wt/otis bin/drive.sh search`.
  `drive.sh` and `rec.sh` call it; `launch.sh`, `doctor.sh` and
  `cleanup.sh` source `steps.sh` and call it when they need an app.
- `features/last-reviewed` keeps the companion's commit on its first line and
  adds `<name> <commit>` per app. `rec.sh affected`, `brief` and `reviewed`
  read and write the app commits with `git -C "$APP_<NAME>"`, and name app
  files `<name>/<path>`. Change-trigger globs in a companion start with the
  app name: `` `otis/src/export/*`: pdf-export ``.
- Nothing is written to an app checkout: no file, no dependency, no ignore
  entry, no commit. Playwright goes into the companion's own `package.json`.
  `AGENTS.md`, stubs and `.claude/settings.json` go into the companion.
- `verify-<app>` accepts feature names or `all` as arguments and drives those.
- Isolation is not a blocker. An isolated, disposable environment that the
  repos already provide is used without asking. A non-isolated one is used
  only after the user approves it. With none, the user starts the app and
  the skill drives it at the `shared` level, with its safeguards.

Without an `apps` file, everything works as before.

## Out of scope

- `with-verification`, the skill that finds a companion from an app checkout.
- A companion mode for `/create-project-local-stack`.

## Verification

- Exercise `export_apps`, `rec.sh affected`, `brief` and `reviewed`, and
  `drive.sh` in a scratch companion and app repo.
- The generator text is proven only by a real generation run against an app.
