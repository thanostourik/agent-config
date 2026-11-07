# Local stack finds other repos' clones by itself

A stack that starts another repo's stack names that repo's checkout through an
environment variable today: `"stack": "CONTENTCLOUD_BACKEND_DIR"`. Every
developer and every agent has to set it, and its value differs on each
machine. An agent in web-react cannot start the frontend with its backend
until someone tells it a path.

This change removes the variable. A stack names the other repo, never a
folder, and `up` finds that repo's clone on the machine. A stack works for
anyone the moment they clone it, whatever other repos it needs, or none.

## Words

- **Repo path:** the other repo's path in its git remote URL, such as
  `eworx-org/contentcloud-backend-spring` for
  `git@github.com:eworx-org/contentcloud-backend-spring.git`. It works for any
  host, nested groups included.
- **Main clone:** the folder that holds a repo's `.git` folder. Every worktree
  of the repo knows it through `git rev-parse --git-common-dir`.

## How `up` finds a clone

A mode says `"stack": "<repo path>"`. For it, `up`:

1. Uses the folder saved for that switch in this repo's git settings
   (`local-stack.<switch>.checkout`), when one is saved.
2. Otherwise looks at the folders next to this repo's main clone. A folder
   counts when its `.git/config` has a remote whose URL ends in the repo path,
   with or without `.git`. Only that one file per git folder is read, so this
   takes milliseconds: 0.02 s for 15 folders and 0.05 s for 10,000 entries on
   this machine. A home-folder search took 44 s and is not used.
3. One clone found: starts its `local-stack/stack`, as before.
4. None found: stops, and says to clone the repo next to this one or to run
   `up --use <switch>=<folder>` once.
5. Several found: stops, lists them, and says to pick one with `--use`.

`up --use <switch>=<folder>` checks that the folder is a clone of the repo
path with its own `local-stack/stack`, and saves it in this repo's git
settings. Git keeps those in the main clone's `.git/config`, which every
worktree shares, so a developer whose clones are not side by side types it
once. A saved folder that no longer holds that clone stops `up` with the same
advice.

Nothing is written outside the repos.

## Files

- `references/stack`: the clone search, `--use`, and a `stack.json` check
  that a `"stack"` value is a repo path.
- `references/stack-spec.md`: dependency stacks by repo path; the files rule
  names the git setting; README section 6.
- `SKILL.md` and `references/questions.md`: ask for the other repo's path in
  its remote, not for a checkout and a variable.
- `references/changelog.md`: version 11, with the migration: replace each
  variable with the repo path and remove the variable from the docs.

The project repos that start another stack, web-react and ccbot, move to
version 11 in their own branches afterwards.

## Proof

On fixture repos in the scratchpad, with the real Docker:

- a repo whose stack needs another repo finds its clone next to it, from the
  main clone and from a worktree elsewhere, with no variable set;
- no clone next to it, and two clones, each stop `up` with its advice;
- `--use` saves the folder, every worktree then uses it, and a wrong folder
  is refused;
- a stack that needs no other repo works as before;
- `down` and `destroy` still reach the dependency stack;
- no file outside the repos is created or changed.

Plus the unit tests and `./sync` into a temporary home.
