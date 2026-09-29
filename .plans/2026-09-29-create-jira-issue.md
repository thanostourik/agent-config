# Create Jira issues with the agreed template

## Goal

Turn the issue conventions agreed in T3 thread
`b50b42cf-f7be-4adc-bae4-ef01446d1132` into one shared skill.

## Design

- Add `skills/shared/create-jira-issue/SKILL.md` for all five tools and an
  enabled entry in `config.example.json`.
- Ask which project to use if the user has not specified one. Never infer or
  default to a project. Omit components unless the user explicitly requests one.
- Default to assignee Athanasios Tourikas (`ato`) and standalone issues. Honor
  explicit overrides.
- Use title prefix `[Agent]`, label `agent-generated`, and an italic
  `Filed by <harness> <model>` footer with no extra provenance text.
- Resolve the active sprint and current fix version from Jira at invocation
  time. Do not freeze the old version or sprint IDs into the skill.
- Choose a supported issue type and priority from the work unless the user
  specifies them. Set the chosen priority explicitly based on impact and urgency.
- Use consistent descriptions for bugs and other work. Follow the connector's
  input format: mcp-atlassian converts Markdown into Jira wiki markup.
- Require an actual instruction to create issues. Discussion permits drafting,
  and existing creation authorization does not need another confirmation.
- Read back created issues and sprint membership. Check rendered descriptions
  where available, and report verification limits without claiming visual proof.

## Verification

Validate the skill, exercise its description with the installed connector's
local formatter, and install into a temporary home to check all destinations
and repeat sync with `--check`. Do not create test issues or install into the
real home folder. Commit, push, open a PR, then update its verification results.
