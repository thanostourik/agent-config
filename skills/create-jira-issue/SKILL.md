---
name: create-jira-issue
description: Use when the user asks to create or file Jira issues, or to draft them for review.
metadata:
  harness: "claude-code, codex, grok, opencode, cursor"
---

# Create Jira issues

Use the connected Jira tools. Drafting or discussing issues does not authorize
creation. When the user asks to create them, proceed within that scope without
another confirmation. Respect a request to create only the first issue of a
batch. This skill does not authorize editing existing issues or creating Jira
versions, sprints, components, or statuses.

When you need me to make a choice before you can continue, use your question
tool if you have one, or ask in your reply if you don't. If the question gets no
answer, ask again in your reply and wait. Do not answer it yourself.

## Project

When asked only to draft an issue, write the title and description for review
without asking for the Jira project or resolving project fields; resolve those
only when creating.

If the user has not specified a project for these issues, ask which Jira
project to use before resolving project fields or creating anything. Never
default to a project or infer one from the repository, issue keys, or available
Jira projects. Resolve the user-specified project to its key.

## Defaults

Honor explicit user overrides. Otherwise use:

- Title: `[Agent] <direct, specific title naming the change or bug>`. Add the
  prefix exactly once. Add a short surface prefix (such as a service, app, or
  area name) only when it helps someone skimming the board see what is
  affected; omit it when the project or title already makes that clear.
- Label: `agent-generated`. Keep any other requested labels too.
- Assignee: Athanasios Tourikas, Jira username `ato`. Resolve this user in the
  selected instance and check that the project allows assigning to him. Do not
  substitute the authenticated user or a similarly named account.
- Component: omit unless the user explicitly requests one. If Jira requires
  a component, ask the user which one to use.
- Parent/epic: none; standalone issues.
- Type: choose from the project's supported types. Use Bug for faulty existing
  behavior, Task for chores or decisions, and Story for new user functionality
  when that type is available. Honor a user-specified type.
- Priority: choose from the priorities available for the selected project,
  based on the issue's impact and urgency. Consider affected users, security
  or data loss, blocked work, and available workarounds. Honor a user-specified
  priority; otherwise select and set it explicitly rather than leaving Jira's
  default. Do not assume every bug deserves the highest priority.
- Initial status: Jira default unless specified.
- Footer: one italic line, `Filed by <harness> <model>`, at the very bottom.
  The harness is the coding tool running the model, such as Claude Code or
  Codex. Use the actual harness and known model name; if the model name is
  unavailable, say `model unknown` rather than guessing. Example:
  `Filed by Claude Code Claude Sonnet 5.5`. Add no separator, PR link, or
  explanation to the footer.

## Resolve the current version and sprint

Read the selected project's issue types, available priorities, creation fields,
versions, and relevant Scrum boards before creating. Look up components only
when requested or required. Resolve user-specified values too; do not carry IDs
from another project or an earlier conversation.

- Sprint: get sprints with state `active` from the relevant project board. Use
  the sole relevant active sprint. If several boards or active sprints remain
  plausible, ask which one; do not choose a future or closed sprint. If none
  is active, ask whether to leave the issue outside a sprint.
- Fix version: use an unreleased, unarchived version clearly associated with
  that active sprint, for example version `1.2.0` for sprint `PROJ-1.2.0`.
  Otherwise use the sole unreleased, unarchived numbered release. A catch-all
  such as `Ongoing` is not a numbered release. If several releases remain
  plausible or none exists, ask; Jira has no universal active-version flag.
- Use the resolved IDs for `fixVersions` and sprint membership. Do not set
  Affects Version merely because a fix version was selected.

## Description

Match the length and structure to the size of the work. Write for the person
who will work on the ticket: assume they know their own system, do not explain
their product back to them, and say each fact once.

### Tasks, Stories, and requests

Lead in the first 1–2 sentences with what is being asked for, then add only the
context or boundaries needed to understand it (such as what must stay
unchanged). Let the content pick the structure:

- A small request needs only 1–3 short paragraphs, with no headings.
- Use a short bullet list when there are several behaviors, rules, or edge
  cases.
- Use natural headings when they help structure the ticket — for example,
  `Endpoint` / `Request` / `Response` for an API contract, `Acceptance
  criteria` for a multi-part feature where "done" would otherwise be unclear,
  or `Notes` for related links, constraints, or side details.

Keep the scope strictly to what was asked; do not invent extra requirements.

### Bugs

Open with 1–2 sentences naming what breaks and its impact. Then use `Steps to
reproduce` (with prerequisites and exact requests or actions when known),
`Actual`, `Expected`, and `Notes` when useful (environment limits, supporting
evidence, or an unverified suspected cause). Do not invent reproduction
evidence or claim unrun checks passed.

### Interface vs. implementation

- Include in the description: observable behavior and external contracts —
  routes, parameters, complete request and response shapes, status or error
  codes, and UI flows.
- Keep out of the description: internal implementation details — source file
  paths, class or function names, internal queries or constants, and
  step-by-step code changes.

## Suggested approach

Add a `Suggested approach` comment right after creating the issue only when the
user asks for one, or when discussion or investigation uncovered non-obvious
implementation context, trade-offs, or traps in a codebase you own that the
next person or agent would otherwise lose.

Skip the comment for straightforward changes, for tickets targeting another
team's codebase, or when you would only be restating the description. Keep the
requested interface and parameters in the description, not the comment.

This comment on your own new issue is covered by the authorization to create
it. Start it with the heading `Suggested approach`, use the same input format
as the description, and end it with the same footer.

## Formatting

Use the input format the Jira tool documents. With mcp-atlassian's Markdown
description input, use `###` headings, numbered lists, fenced code blocks, and
`_Filed by <harness> <model>_`. It converts these to Jira wiki markup. When
sending wiki markup directly, use `h3.` headings, `#` numbered steps, `{code}`
blocks, and the same underscore-delimited italic footer. Do not mix the two
formats or send wiki markup through a Markdown converter.

Keep JSON and request/response bodies in code blocks. Use `<orgId>`-style
placeholders in paths instead of `{orgId}`. Literal braces outside code blocks
can become Jira macros. Pass real newlines, not literal backslash-n text.

## Create and verify

Resolve required fields before creating. Set the prefix, label, assignee,
type, priority, fix version, and description in the creation request. Set a
component only when the user specified it. If the tool cannot set sprint during
creation, add the returned issue key to the resolved active sprint afterwards.

Read back each created issue and verify its project, title, labels, assignee,
type, priority, fix version, description, parent/epic, and sprint membership.
Check that any component matches the user's explicit request, and that the
suggested-approach comment exists when you wrote one.

If creation times out or the outcome is uncertain, check whether the issue
exists before retrying. If a later step fails, report the created key and the
incomplete field; do not create a replacement or alter an existing issue
without authorization.

Return the issue links and chosen fields, plus any incomplete operation. In a
batch, apply the same resolved defaults consistently.
