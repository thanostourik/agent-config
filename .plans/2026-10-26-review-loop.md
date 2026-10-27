# Review loop

`review-loop` (in `skills/shared/`) is a review-and-proof loop the
implementing agent runs on its own branch. Inspired by `sol-loop`, without its
debate step.

Reviewers come in two lists. Round reviewers
(`skills.review-loop.defaults.reviewers`, default `["codex-review"]`) review
every round. Final reviewers (`defaults.final_reviewers`, default
`["grok-review"]`) review once, in the final round, next to the round
reviewers: the round after the first clean round, or the last round the
budget allows. Grok took about 20 minutes a round against Codex's 6 and never
came back clean, so running it every round set the length of every round and
of the loop. A list named in the request wins; reviewers named without a list
are round reviewers, with no final round. A final reviewer that is also a
round reviewer is only a round reviewer, so listing Grok in both brings back
Grok every round. An empty `final_reviewers` turns the final round off: sync
renders an empty list as `none`, and the skill reads `none` as an empty list.
Each entry is a review skill; that skill's config gives model and effort. In a
round, its reviewers run in parallel the same built-in review
command on the whole branch against its base. They stay blind: no intent,
ledger, or notes from the author. In T3, a skill with a T3 path
(`grok-review`) runs as a `delegate_task` whose task is only the slash
command, with no `role`. Everything else runs the skill's CLI command;
`codex-review` is always CLI.

The author checks each finding, fixes the real ones, declines the rest with a
reason, and keeps `.plans/scratch/<branch>/review-ledger.md` (id, reviewer,
severity, outcome, reason). A declined finding raised again is skipped unless
the code around it changed. Behavior fixes are re-verified. Review makes the
change correct, not bigger: only bugs this branch caused are fixed, each with
the smallest change; older problems are recorded `out of scope` and reported
as follow-ups. The report shows the diff size before and after.

Budget: 3 rounds, 5 for security, permissions, auth, data loss, or
state/concurrency findings, or on request; both are skill defaults. Stop on a
clean round (nothing above nit after the ledger filter) once the final round
has run, or when the budget ends, which is not approval. Then verify the head
commit, and run one evidence check with the first round reviewer in prompt
mode: the intent quoted word for word plus the raw proof, asked whether the
proof shows each criterion working. Missing proof: gather it, check once more.
A bug: fix it and run another round within budget.

The PR line `Reviewed with review-loop: <N> rounds with <reviewers>` goes in
the PR description only when the agent may update the PR, otherwise in the
report. The loop never pushes.

Supporting changes:

- `sync`: a skill default may be a JSON list of strings, rendered joined with
  `, `, or `none` when empty. An override replaces the whole list. Tests and
  `AGENTS.md` updated.
- The four review skills become agent-invocable and install into every tool,
  their own included, so the default reviewers exist wherever `review-loop`
  does; `grok-review` gets its T3 delegate path.
- `review-loop` added to `config.defaults.json`.
