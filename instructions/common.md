# Personal Preferences

## Communication

- If I push back, re-evaluate on the merits: hold your position when you're right and say why.
  Never cave just because I'm insisting or angry.
- When I argue against a proposal, I'm exploring the options, not rejecting it. Keep the discussion
  going with arguments for each side.
- Define and explain unfamiliar technical terms on first use, and reuse the same term consistently.
- Answer concisely; add detail only when needed for correctness or a decision.
- Explain plans and architecture in plain, short sentences. I'm not a native English speaker.
- Questions and design discussion are NEVER implementation approval, not even if I agree
  with your proposal mid-discussion. Implement only after an explicit "go" / "do it" / "implement".

## General preferences

- Implement only the requested scope. Avoid unrelated cleanup and features.
- Follow the agreed plan. Ask before changing scope, behavior, architecture,
  dependencies, or the agreed approach.
- If the task is too broad to complete reliably, explain the issue and propose a concrete split.
- Never revert, overwrite, or commit my uncommitted local work. Ask first, every time.
- Resolve routine implementation details using repository conventions.
- When giving me setup or test instructions, give exact, complete steps. Do not assume I know the tool.
- Anything that can run longer than ~5 minutes: set an explicit timeout or run it in the background
  with progress checks. Never sit silently on a foreground command.

## Plans & AI workflow artifacts

- Plans are flat files in `.plans/`, named `YYYY-MM-DD-short-slug.md`, and are committed.
- Temporary working artifacts (analysis notes, scratch reports, subagent handoffs) go in
  `.plans/scratch/` and are not committed. Rendered `*.html` next to plans is also not committed.
  Projects keep a `.plans/.gitignore` for both.

## Coding preferences

- Always strive for concise, simple solutions. Channel "yagni" energy unless told otherwise.
- If a problem can be solved in a simpler way, propose it.
- Don't be scared to propose bold ideas if they can meaningfully benefit our work.
- Be careful with destructive actions that I did not explicitly request.
- Tests are good. Endless smoke tests, "regression tests" for feature deletions, etc. are much less
  good. Tests should be focused, not slop.
- Don't comment every line.
  Add concise comments above functions or classes when their purpose, usage, or constraints are not clear from the code.
- Match the surrounding code's style, naming, and patterns.
- Avoid unnecessary wrappers, abstractions, and speculative configuration.
- Handle errors at meaningful boundaries; avoid redundant catches.
- Prefer early returns when they make control flow clearer.

## Verification

- Never say "done" or "fixed" without exercising the change: run it, hit the endpoint, drive the UI.
  Reading your own code is not verification.
- Pick the checks that match the change: unit tests for logic, an endpoint call for an API, a
  screenshot compared against the mockup for UI.
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
  Draft PR descriptions from the plan + diff; that's where the plan's "why" gets preserved.
- Branches are merged through PRs with squash. Merging, tags, or anything touching main or other
  people's branches: ask first, every time.
- When asked to merge locally: rebase the branch onto main, then fast-forward merge. Never create
  merge commits. Squash first only if I ask. If the branch is already pushed, the rebase will require
  a force-push: tell me and stop.
- No force-push, ever. If a push is rejected, stop and tell me.

## Local environment

- Containers started by the project's dev script (databases, auth servers, etc.) run in a branch-isolated
  environment. You may start, reset, and reseed them freely.
- App servers (Next.js, Spring Boot, etc.): check whether one is already running and reuse it.
  Ask before starting one yourself, and stop anything you started when you're done so I can run it from my IDE.
- Never touch shared or remote services (deployed environments, remote databases).
- Run focused tests, type checks, and lint checks appropriate to the change.
- Avoid full builds unless needed to verify the change, and say why when one is.

## TypeScript

- Type safety is useful, take advantage of it.
- Never use `any` unless 100% necessary or specifically instructed.
- Prefer inferred return types. Add an explicit one only when inference gives a wrong or unreadable type.
