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
- Follow-up feedback is a new requirement on the whole task, not a patch on the last diff.
  Rework what this task already built, code and plan, so the result reads as if written once
  with everything known. Special cases, flags, or wrappers around your own earlier code mean
  you are patching. If the rework changes the agreed plan, tell me the new design first.

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

Every task that touches a file follows the same path: branch, commit and push as you go, open a
PR when the implementation is in place, keep it updated until I merge it. You never need to ask
for any of these steps. Reading and answering questions is the only work that happens on main.

- Branch before the first file you create or edit. A plan, a scratch note, or a one-line fix all
  count as changes. Never write on main.
- Branch name format: `<prefix>/ISSUE-123-short-name`, with prefix `feature/`, `fix/`, or `chore/`.
  Omit the issue id when there is none.
- Commit after each working step and push right away. Local-only commits have no value to me: I
  want to see the branch on the remote at all times.
- Conventional commit messages, always: `type(scope): summary (ISSUE-123)` (feat, fix, refactor,
  chore, test, docs). Omit the issue id when there is none. Applies to checkpoint commits too.
- Never add Co-authored-by trailers to commit messages.
- Open the PR as soon as the implementation is committed, using the `file-pr` skill. Do not wait
  for verification to finish: the PR description says what is verified and what is not, and you
  update it as that changes. Give me the PR link.
- Follow-up work on the same branch goes to the same PR: push the commits and refresh the
  description when the scope or the verification status changed.
- Branches are merged through PRs with squash. Merging, tags, or anything touching main or other
  people's branches: ask first, every time.
- Never merge another branch into the working branch, and never rebase it, unless I say so
  explicitly. If it needs main's changes, stop and ask.
- No force-push, ever. If a push is rejected, stop and tell me.
- When asked to merge locally: run the `modernize` skill first, then fast-forward merge. Never
  create merge commits. Squash first only if I ask.

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
