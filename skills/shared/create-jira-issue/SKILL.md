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

If the user has not specified a project for these issues, ask which Jira
project to use before resolving project fields or creating anything. Never
default to a project or infer one from the repository, issue keys, or available
Jira projects. Resolve the user-specified project to its key.

## Defaults

Honor explicit user overrides. Otherwise use:

- Title: `[Agent] <concise title describing the problem or requested outcome>`.
  Add the prefix exactly once.
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

## Standard description

Start with a short paragraph describing the problem or requested outcome and
its impact. Use these sections in order:

| Bug | Task, Story, or decision |
| --- | --- |
| Steps to reproduce | Context |
| Actual | Requested work |
| Expected | Acceptance criteria |
| Notes, when useful | Notes, when useful |

For bugs, include prerequisites, numbered reproduction steps, exact requests
and responses when known, and a concrete expected result. For other work,
describe the current situation, scope of work or decision, and observable
completion criteria. Notes hold relevant environment limits, supporting
evidence, or a suspected cause clearly identified as such. Include source,
feature-file, or PR references only when available and relevant; a PR is not
required. Do not invent reproduction evidence or claim unrun checks passed.

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
Check that any component matches the user's explicit request.

If creation times out or the outcome is uncertain, check whether the issue
exists before retrying. If a later step fails, report the created key and the
incomplete field; do not create a replacement or alter an existing issue
without authorization.

Return the issue links and chosen fields, plus any incomplete operation. In a
batch, apply the same resolved defaults consistently.
