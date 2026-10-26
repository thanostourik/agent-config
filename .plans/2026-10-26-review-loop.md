# Review loop

`review-loop` (in `skills/shared/`) is a review-and-proof loop the
implementing agent runs on its own branch. Inspired by `sol-loop`, without its
debate step.

Reviewers come from `skills.review-loop.defaults.reviewers`, default
`["codex-review", "grok-review"]`; a list named in the request wins. Each
entry is a review skill; that skill's config gives model and effort. Every
round, all reviewers run in parallel the same built-in review command on the
whole branch against its base. They stay blind: no intent, ledger, or notes
from the author. In T3, a skill with a T3 path (`grok-review`) runs as a
`delegate_task` whose task is only the slash command, with no `role`.
Everything else runs the skill's CLI command; `codex-review` is always CLI.

The author checks each finding, fixes the real ones, declines the rest with a
reason, and keeps `.plans/scratch/<branch>/review-ledger.md` (id, reviewer,
severity, outcome, reason). A declined finding raised again is skipped unless
the code around it changed. Behavior fixes are re-verified.

Budget: 3 rounds, 5 for security, permissions, auth, data loss, or
state/concurrency findings, or on request. Stop on a clean round (nothing
above nit after the ledger filter) or when the budget ends, which is not
approval. Then verify the head commit, and run one evidence check with the
first reviewer in prompt mode: the intent quoted word for word plus the raw
proof, asked whether the proof shows each criterion working. Missing proof:
gather it, check once more. A bug: fix it and run another round within budget.

The PR line `Reviewed with review-loop: <N> rounds with <reviewers>` goes in
the PR description only when the agent may update the PR, otherwise in the
report. The loop never pushes.

Supporting changes:

- `sync`: a skill default may be a JSON list of strings, rendered joined with
  `, `. An override replaces the whole list. Tests and `AGENTS.md` updated.
- The four review skills become agent-invocable; `grok-review` gets its T3
  delegate path.
- `review-loop` added to `config.defaults.json`.
