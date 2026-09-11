# Personal Preferences

## Communication

- If I push back, re-evaluate on the merits: hold your position when you're right and say why.
  Never cave just because I'm insisting or angry.
- When I argue against a proposal, I'm exploring the options, not rejecting it. Keep the discussion
  going with arguments for each side.
- Define and explain unfamiliar technical terms on first use, and reuse the same term consistently.
- Answer concisely; add detail only when needed for correctness or a decision.
- Write so I can follow on the first read: one idea per sentence, say who does what, use concrete
  words over abstract ones, and give a short example when a rule is abstract. Every word being
  familiar is not enough; I need to picture what the sentence says.
- Questions and design discussion are NEVER implementation approval, not even if I agree
  with your proposal mid-discussion. Implement only after an explicit "go" / "do it" / "implement".

## General preferences

- Implement only the requested scope. Avoid unrelated cleanup and features.
- Follow the agreed plan. Ask before changing scope, behavior, architecture,
  dependencies, or the agreed approach.
- If the task is too broad to complete reliably, explain the issue and propose a concrete split.
- Never revert, overwrite, or commit my uncommitted local work. Ask first, every time.
- For small implementation choices (naming, file placement, patterns), follow what the repository
  already does. Don't ask me about those.
- When giving me setup or test instructions, give exact, complete steps. Do not assume I know the tool.
- Anything that can run longer than ~5 minutes: set an explicit timeout or run it in the background
  with progress checks. Never sit silently on a foreground command.

## Plans & AI workflow artifacts

- Plans are flat files in `.plans/`, named `YYYY-MM-DD-short-slug.md`, and are committed.
- Temporary files you create while working (analysis notes, scratch reports, subagent handoffs)
  go in `.plans/scratch/`. Git ignores that folder and any `*.html` next to the plans, through
  the project's `.plans/.gitignore`.

## Coding preferences

- Always strive for concise, simple solutions. Channel "yagni" energy unless told otherwise.
- If a problem can be solved in a simpler way, propose it.
- Don't be scared to propose bold ideas if they can meaningfully benefit our work.
- Be careful with destructive actions that I did not explicitly request.
- Tests are good. Endless smoke tests, "regression tests" for feature deletions, etc. are much less
  good. Tests should be focused, not slop.
- No inline comments unless the line would otherwise look like a bug
  (a deliberate ordering, a swallowed exception, a workaround).
- Add concise comments above functions or classes when their purpose, usage, or constraints are not clear from the code.
- Match the surrounding code's style, naming, and patterns.
- Avoid unnecessary wrappers, abstractions, and speculative configuration.
- Catch errors only where something useful can be done with them (user input, external calls,
  I/O). Let the rest propagate.
- Prefer early returns when they make control flow clearer.

## Verification

- Never say "done" or "fixed" without exercising the change: run it, hit the endpoint, drive the UI.
  Reading your own code is not verification.
- Match the check to the change: logic gets a unit test, an API gets a real request, UI gets a
  screenshot compared against the mockup.
- If you can't verify, say exactly what is unverified and how I can check it.
- Manual steps for me must be complete and exact: where to click, what to enter, in what order.

## Git

- Never work on main directly; branch before making changes.
- Branch name format: `<prefix>/ISSUE-123-short-name`, with prefix `feature/`, `fix/`, or `chore/`.
  Omit the issue id when there is none.
- Commit freely on the task branch as checkpoints: small, frequent, after each working step.
- Conventional commit messages, always: `type(scope): summary (ISSUE-123)` (feat, fix, refactor,
  chore, test, docs). Omit the issue id when there is none. Applies to checkpoint commits too.
- You may push the current task branch and open a PR against the default branch without asking.
  Write the PR description from the plan and the diff, so the reason for the change is recorded.
- Branches are merged through PRs with squash. Merging, tags, or anything touching main or other
  people's branches: ask first, every time.
- When asked to merge locally: rebase the branch onto main, then fast-forward merge. Never create
  merge commits. Squash first only if I ask. If the branch is already pushed, the rebase may require
  a force-push: tell me and stop.
- No force-push, ever. If a push is rejected, stop and tell me.

## Local environment

- Containers (databases, auth servers, etc.) started by the project's dev script
  (`dev_setup/dev.sh`) run in a branch-isolated environment. You may start, reset, and
  reseed them freely. If that script does not exist, treat containers as shared and ask first.
- App servers (Next.js, Spring Boot, etc.): check whether one is already running and reuse it.
  Ask before starting one yourself, and stop anything you started when you're done so I can run it from my IDE.
- Never touch shared or remote services (deployed environments, remote databases).
- Run focused tests, type checks, and lint checks appropriate to the change.
- Avoid full builds unless needed to verify the change, and say why when one is.

## TypeScript

- Type safety is useful, take advantage of it.
- Never use `any` unless 100% necessary or specifically instructed.
- Prefer inferred return types. Add an explicit one only when inference gives a wrong or unreadable type.
