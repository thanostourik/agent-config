---
name: create-jira-issue
description: Use when the user asks to create or file Jira issues, or to draft them for review.
metadata:
  harness: "claude-code, codex, grok, opencode, cursor, gemini"
---

# Create Jira issues

Use the connected Jira tools. Drafting or discussing issues does not authorize
creation, and this skill never authorizes editing existing issues or creating
Jira versions, sprints, components, or statuses.

- **Drafting:** write only the title and description for review. Do not ask for
  a Jira project or resolve project fields yet.
- **Creating:** proceed within the requested scope without another confirmation.
  If the user has not named a project, ask which Jira project to use before
  resolving fields or creating anything — never infer it from the repository,
  issue keys, or available projects.
- **Choices:** whenever you need a decision before continuing, use your question
  tool if you have one, or ask in your reply. If the question gets no answer,
  ask again in your reply and wait; do not answer it yourself.

## Fields

Before creating, look up the selected project's issue types, priorities,
creation fields, versions, and Scrum boards fresh (never carry IDs from another
project or earlier conversation). Honor explicit user overrides; otherwise:

- **Title:** `[Agent] <direct, specific title naming the change or bug>`. Add
  the prefix once. Include a short surface prefix (service, app, or area) only
  when it helps someone skimming the board see what is affected.
- **Type:** pick from the project's types (`Bug` for faulty existing behavior,
  `Task` for chores or decisions, `Story` for new user functionality when
  available).
- **Priority:** set explicitly from the project's priorities based on impact and
  urgency (affected users, security or data loss, blocked work, workarounds). Do
  not leave Jira's default or assume every bug is highest priority.
- **Assignee:** `{{defaults.assignee}}`. When not `none`, resolve that user in
  the instance and verify the project allows assigning to them (never substitute
  another account). When `none`, leave unassigned.
- **Label:** `agent-generated`, keeping any other requested labels too.
- **Sprint:** the sole `active` sprint on the project's relevant board (never a
  future or closed sprint). Ask if several boards or active sprints are
  plausible, or if none is active.
- **Fix version:** the unreleased, unarchived version matching that active
  sprint (for example `1.2.0` for `PROJ-1.2.0`), or else the sole unreleased,
  unarchived numbered release (not a catch-all like `Ongoing`). Ask if several
  remain plausible or none exists. Do not set Affects Version.
- **Component / Parent / Status:** omit component and parent/epic unless
  requested (ask if Jira requires a component); leave initial status at Jira's
  default.

## Writing the ticket

Match length and structure to the size of the work. Write for the person who
will work on it: assume they know their own system, say each fact once, and keep
the scope strictly to what was asked.

- **Tasks, Stories, and requests:** lead in 1–2 sentences with what is being
  asked for, then add only the context needed. Let the content pick the
  structure: 1–3 plain paragraphs for a small request, bullets for several rules
  or edge cases, or natural headings when helpful (such as `Endpoint` /
  `Request` / `Response`, `Acceptance criteria` for multi-part features where
  "done" would otherwise be unclear, or `Notes` for related links or
  constraints).
- **Bugs:** open with 1–2 sentences naming what breaks and its impact, then use
  `Steps to reproduce` (prerequisites and exact requests or actions when known),
  `Actual`, `Expected`, and `Notes` when useful (environment limits, evidence,
  or an unverified suspected cause). Never invent evidence or claim unrun checks
  passed.
- **Interface vs. implementation:** include observable behavior and external
  contracts (routes, parameters, complete request and response shapes, status or
  error codes, UI flows). Keep internal code details out of the description (file
  paths, class or function names, internal queries or constants, step-by-step
  code changes).
- **Suggested approach comment:** add a `Suggested approach` comment right after
  creating the issue (covered by creation authorization) only when asked, or
  when discussion or investigation uncovered non-obvious context, trade-offs, or
  traps in a codebase you own that would otherwise be lost. Skip it for
  straightforward changes or another team's codebase. Start with `Suggested
  approach` and end with the same footer.
- **Footer and formatting:** end the description (and any comment) with one
  italic line `_Filed by <harness> <model>_` (`model unknown` if unavailable; no
  separator or extra text). Match the Jira tool's documented format — Markdown
  (`###`, fenced code blocks) for `mcp-atlassian`, or wiki markup (`h3.`, `#`,
  `{code}`) when sending wiki markup directly; never mix them. Keep JSON and
  request/response bodies in code blocks, use `<orgId>` instead of `{orgId}`
  outside code blocks, and send real newlines.

## Filing and verifying

Create the issue with the resolved fields (adding it to the active sprint
afterwards if the tool cannot set sprint on creation), then read it back to
verify all fields, the description, and any `Suggested approach` comment.

If creation times out or the outcome is uncertain, check whether the issue
exists before retrying. If a later step fails, report the created key and what
failed instead of creating a duplicate or editing without authorization. Return
the issue link(s) and chosen fields, applying the same resolved defaults across
a batch.
