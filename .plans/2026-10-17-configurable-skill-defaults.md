# Configurable skill defaults

## Design

Keep installation switches under `skills.<name>.enabled` and configurable
values under `skills.<name>.defaults`. In skill Markdown, a marker such as
`{{defaults.model|gpt-6.1-sol}}` declares both an option and its shipped default.
Sync replaces markers when building installed files. Explicit user choices
still take precedence in the skill's instructions.

Support nonempty, single-line string values and flat option names. Render only
skill Markdown, including reference files. Copy other assets unchanged. Reject
malformed markers, conflicting shipped defaults, unsupported option names, and
invalid configuration before writing. Validate disabled skills too.

Start with the four CLI review skills, the three triple-review targets, and
the fan-out target. Keep unavailable-target behavior: report it rather than
silently selecting another model. Resolve T3 effort option names through its
live catalog so a configured provider can use its own option name.

## Implementation

1. Add marker rendering and configuration validation to sync.
2. Mark the existing model, provider, and effort defaults in the six skills.
3. List settings in config.example.json and document usage and authoring in
   README.md and AGENTS.md.
4. Commit and push the implementation, then open its PR before verification.
5. Exercise real sync runs against temporary homes, run the existing unittest
   suite, and update the PR with results. Do not add tests or install into the
   real home directory.
