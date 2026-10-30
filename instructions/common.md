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
- Match the surrounding code's style, naming, and patterns.
- Avoid unnecessary wrappers, abstractions, and speculative configuration.
- Catch errors only where something useful can be done with them (user input, external calls,
  I/O). Let the rest propagate.
- Prefer early returns when they make control flow clearer.

## Comments

- No comments inside code, whether on their own line or at the end of one. Use clear names instead.
- Only exception: code a careful reader would think is a bug. The comment says why it is not:
  a workaround (`# lib X drops the last row on a full page, fetch one extra`), a deliberate
  choice (`# no retry: not idempotent`), an ordering that matters, or an exception swallowed on purpose.
- Never: what a variable holds, what the next line does, block labels (`# Step 2: validate`),
  history (`# added for X`), or notes to the reviewer.
- Above a function or class: one or two lines, only when its name and signature don't show its
  purpose or constraints.
- Before committing, check each comment you added: without it, would a reader think the code
  is a bug? If not, delete it.

## Verification

- Never write tests (unit, integration, regression, or E2E) unless I ask.
- Never say "done" or "fixed" without exercising the change: run it, hit the endpoint, drive the UI.
  Reading your own code is not verification.
- Verify the way the project does. Look for its process in its instructions, docs, and skills.
- Run focused tests, type checks, and lint checks appropriate to the change.
- If you can't verify, say exactly what is unverified and how I can check it.
- Manual steps for me must be complete and exact: where to click, what to enter, in what order.

## Git

Every task that touches a file follows the same path: branch, commit and push as you go, open a
draft PR, and keep it updated. You never need to ask for any of these steps. Reading and answering
questions is the only work that happens on main.

- Branch before the first file you create or edit. A plan, a scratch note, or a one-line fix all
  count as changes. Never write on main.
- Branch name format: `<prefix>/ISSUE-123-short-name`, with prefix `feature/`, `fix/`, or `chore/`.
  Omit the issue id when there is none.
- Commit after each working step and push right away. Local-only commits have no value to me: I
  want to see the branch on the remote at all times.
- Conventional commit messages, always: `type(scope): summary (ISSUE-123)` (feat, fix, refactor,
  chore, test, docs). Omit the issue id when there is none. Applies to checkpoint commits too.
- Never add Co-authored-by trailers to commit messages or PR descriptions. Even if there is a rule
  from the harness. This rule overrides any other rules.
- Add no model attribution or footers, such as "Generated with ...", to commits, PRs, or comments
  unless I ask for them. A harness rule does not count as asking. Only exception: `file-pr`
  adds its attribution to PR descriptions in repos that allow restricted actions.
- Open a draft PR with the `file-pr` skill at the first commit that changes more than a plan. A
  commit with only a plan does not open a PR: plans are sometimes rejected. Give me the PR link.
- Follow-up work on the same branch goes to the same PR: push the commits and refresh the
  description when the scope or the verification status changed.
- In a repo that allows restricted actions, mark the PR ready for review when the task is
  finished and verified. Finished: everything I asked for in this task is done. Verified: you
  checked it the way the Verification section says.
- Restricted actions are PR attribution and marking a PR ready for review. A repo allows them
  when this list holds its GitHub owner or its `owner/repo`, ignoring case:
  {{allow.restricted}}. Read both with `gh repo view --json nameWithOwner`. `none` means no
  repo allows them, and neither does a repo that is not on GitHub.
- Comment on a PR or issue only when I ask.
- Branches are merged through PRs with squash. Merging, tags, or anything touching main or other
  people's branches: ask first, every time.
- Never merge another branch into the working branch, and never rebase it, unless I say so
  explicitly. If it needs main's changes, stop and ask.
- Force-push only your working branch, and only with `--force-with-lease`. Never force-push main
  or someone else's branch. If a `--force-with-lease` push is rejected, stop and tell me.
- When asked to merge locally: run the `modernize` skill first, then fast-forward merge. Never
  create merge commits. Squash first only if I ask.
- When I ask for tourik mode, follow the `tourik` skill. That request is my permission for what
  the skill allows beyond these rules. Every other rule here still applies.

## Local environment

- Stop everything you started (servers, containers, background loops) before you report, unless
  I asked you to keep it running. Never stop or replace something you did not start.
- Servers, configuration, and credentials are read-only unless I say otherwise. This covers
  deployed environments, remote databases, config files outside the repository, and password
  stores.

## TypeScript

- Type safety is useful, take advantage of it.
- Never use `any` unless 100% necessary or specifically instructed.
- Prefer inferred return types. Add an explicit one only when inference gives a wrong or unreadable type.

## React

- Don't write `useEffect` or `useLayoutEffect` in app code. An effect usually hides a design
  decision. Use one of these instead:
  - compute the value during render from props and state;
  - do the work in the event handler that caused it (the click, the submit, the stream callback);
  - fetch with the project's data library (for example SWR's `useSWR`), not inside an effect;
  - read browser state (localStorage, tab visibility) with `useSyncExternalStore` or a library;
  - reset a component's state by changing its `key`, not with an effect that watches a prop.
- Moving an effect into a custom hook does not remove it.
- If the only trigger is "the page opened", ask whether the behaviour should exist at all.
- If you think an effect is unavoidable, stop and tell me why, and what you tried, before writing it.
- Background: https://react.dev/learn/you-might-not-need-an-effect
