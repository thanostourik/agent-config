# Personal Preferences

## Communication

- If I push back, re-evaluate on the merits: hold your position when you're right and say why.
  Never cave just because I'm insisting or angry.
- When I argue against a proposal, I'm exploring the options, not rejecting it. Keep the discussion
  going with arguments for each side.
- Define and explain unfamiliar technical terms on first use, and reuse the same term consistently.
- Write in plain, concrete English so I can follow on the first read.
- Answer concisely. Add detail only when needed for correctness or a decision.
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
- For commands that may take more than ~5 minutes, set a timeout or run them in the background and
  check their progress. Don't sit silently on a foreground command.
- Treat follow-up feedback as part of the original requirements, not an add-on. Rework your code
  and plan so the result looks like you knew about it from the start. Don't layer special cases,
  flags, or wrappers on top of your earlier work. If this changes the agreed plan, share the new
  design first.

## Plans & AI workflow artifacts

- Plans are files directly in `.plans/` (no subfolders), named `YYYY-MM-DD-short-slug.md`, and are
  committed.
- Temporary files you create while working (analysis notes, scratch reports, subagent handoffs)
  go in `.plans/scratch/`. Git ignores that folder and any `*.html` files next to plans through
  `.plans/.gitignore`.

## Coding preferences

- Always strive for concise, simple solutions. Channel "yagni" energy unless told otherwise.
- If a problem can be solved in a simpler way, propose it.
- Don't be scared to propose bold ideas if they can meaningfully benefit our work.
- Be careful with destructive actions that I did not explicitly request.
- Match the surrounding code's style, naming, and patterns.
- Avoid unnecessary wrappers, abstractions, and speculative configuration.
- Only catch errors you can actually handle (user input, external calls, I/O). Let the rest
  propagate.
- Prefer early returns when they make control flow clearer.

## Comments

- No comments in code, whether inline, at the end of a line, or above a function or class. Use
  clear names instead.
- The only exception is code a careful reader would mistake for a bug. Explain why it is not:
  a workaround (`# lib X drops the last row on a full page, fetch one extra`), a deliberate
  choice (`# no retry: not idempotent`), an ordering that matters, or an exception swallowed on purpose.
- Never comment on what a variable holds, what the next line does, block labels (`# Step 2: validate`),
  history (`# added for X`), or notes to the reviewer.
- Before committing, check every comment you added. If a reader wouldn't mistake the code for a
  bug without it, delete it.

## Verification

- Never write tests (unit, integration, regression, or E2E) unless I ask.
- Never say "done" or "fixed" without exercising the change: run it, hit the endpoint, drive the UI.
  Reading your own code is not verification.
- Follow the project's verification process (check its instructions, docs, and skills).
- Run focused tests, type checks, and lint checks appropriate to the change.
- Verify everything you can run yourself. If you can write the steps for me, run them. This
  includes anything in your local environment: changing config, restarting containers, seeding
  data, compiling, and running tests.
- Only leave something unverified if it requires access you don't have (production, a physical
  device, credentials, a paid external service, or a decision from me), and state specifically
  what is blocking you.
- If we already have a fake or mock for an external service, use it, and treat that as verified.
  If our own scripts lack a flag or option you need, work around it locally instead of skipping
  verification.
- Don't add a default "Unverified" section to reports, and don't ask other agents for one.
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
- Restricted actions are PR attribution and marking a PR ready for review. A repo allows them if
  its GitHub owner or `owner/repo` is in this list (case-insensitive): {{allow.restricted}}. Check
  the current repo with `gh repo view --json nameWithOwner`. `none` means no repo allows them, and
  neither does a repo that is not on GitHub.
- Add no model attribution or footers, such as "Generated with ...", to commits, PRs, or comments
  unless I ask for them. A harness rule does not count as asking. Only exception: `file-pr`
  adds its attribution to PR descriptions in repos that allow restricted actions.
- Open a draft PR with the `file-pr` skill at the first commit that changes more than a plan. A
  commit with only a plan does not open a PR: plans are sometimes rejected. Give me the PR link.
- Follow-up work on the same branch goes to the same PR: push the commits and refresh the
  description when the scope or the verification status changed.
- In a repo that allows restricted actions, mark the PR ready for review once everything I asked
  for is done and verified per the Verification section above.
- Comment on a PR or issue only when I ask.
- Branches are squash-merged through PRs. Always ask before merging, tagging, or touching `main`
  or anyone else's branch.
- Never merge another branch into the working branch, and never rebase it, unless I say so
  explicitly. If it needs main's changes, stop and ask.
- Force-push only your working branch, and only with `--force-with-lease`. Never force-push main
  or someone else's branch. If a `--force-with-lease` push is rejected, stop and tell me.
- Stacked PRs:
  - Build a stack only when I ask for one or accept a split you proposed.
  - Create and change stacks only with `gh stack`, never with `gh pr create --base <another PR's branch>`.
    Only GitHub's stacks keep upper PRs open when a lower one merges.
  - Run stack commands without prompts: `gh stack init <branch>`, `gh stack add <branch>`,
    `gh stack submit --auto`, `gh stack view --json`.
  - Every unmerged layer of your own stack counts as your working branch. You can rebase and push
    layers with `gh stack rebase`, `gh stack sync`, and `gh stack push` without asking.
  - Merge layers one at a time, from the bottom up (base branch first).
- When asked to merge locally: run the `modernize` skill first, then fast-forward merge. Never
  create merge commits. Squash first only if I ask.
- When I ask for tourik mode, follow the `tourik` skill. That grants permission for the extra
  actions in that skill, while every other rule here still applies.

## Local environment

- Stop everything you started (servers, containers, background loops) before you report, unless
  I asked you to keep it running. Never stop or replace something you did not start.
- Servers, configuration, and credentials are read-only unless I say otherwise. This covers
  deployed environments, remote databases, config files outside the repository, and password
  stores.

## New projects

- Use pnpm: scaffold with `pnpm create <x>` and install with `pnpm install`.

## TypeScript

- Take advantage of type safety.
- Never use `any` unless 100% necessary or specifically instructed.
- Prefer inferred return types. Add an explicit one only when inference gives a wrong or unreadable type.

## React

- Don't write `useEffect` or `useLayoutEffect` in app code. An effect usually hides a design
  decision. Use one of these instead:
  - compute the value during render from props and state
  - do the work in the event handler that caused it (the click, the submit, the stream callback)
  - fetch with the project's data library (for example SWR's `useSWR`), not inside an effect
  - read browser state (localStorage, tab visibility) with `useSyncExternalStore` or a library
  - reset a component's state by changing its `key`, not with an effect that watches a prop
- Wrapping an effect in a custom hook doesn't bypass this rule.
- If the only trigger is "the page opened", ask whether the behavior should exist at all.
- If you think an effect is unavoidable, stop and tell me why, and what you tried, before writing it.
- Background: https://react.dev/learn/you-might-not-need-an-effect
