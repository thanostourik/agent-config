# Agent configuration repository

This personal repository centralizes instructions and reusable workflows for
Claude Code, Codex, Grok, Cursor, and OpenCode. It lives at
`~/Devel/agent-config`. Edit configuration sources here, then use `sync` to
install them into each application's expected location.

## Repository context versus configuration content

This root `AGENTS.md` describes how to work on this repository. Root
`CLAUDE.md` imports it for Claude Code. Neither root file is installed by sync.

Files under `instructions/`, `profiles/`, `skills/`, and `agents/` are
configuration content for other sessions, not instructions to execute while
editing this repository. Do not activate delegation policies merely because
you read their source files. Preserve empty placeholders unless asked to fill
them, and do not rename `instructions/claude-code.md` to `CLAUDE.md`.

## Structure

- `instructions/common.md`: personal preferences shared by all five tools.
- `instructions/<tool>.md`: application-specific additions. Sync concatenates
  common instructions first, followed by the application's instructions.
- `profiles/`: optional model/workflow policies, such as Fable delegating
  investigation to Sol. Sync does not install or activate profiles.
- `skills/shared/`: populated skill directories copied to `~/.agents/skills/`.
- `skills/claude-code/`: populated skill directories copied to `~/.claude/skills/`.
- `agents/claude-code/`: nonempty Markdown agent definitions copied to
  `~/.claude/agents/`.
- `sync`: executable Python script using only the standard library.
- `tests/test_sync.py`: integration tests using temporary repositories and homes.

## Instruction destinations

| Source addition | Destination |
| --- | --- |
| `instructions/claude-code.md` | `~/.claude/CLAUDE.md` |
| `instructions/codex.md` | `~/.codex/AGENTS.md` |
| `instructions/grok.md` | `~/.grok/AGENTS.md` |
| `instructions/opencode.md` | `~/.config/opencode/AGENTS.md` |
| `instructions/cursor.md` | `~/.cursor/rules/agent-config.mdc` |

Cursor output includes rule metadata with `alwaysApply: true`. Its IDE's
home-directory rule discovery covers projects under `~/Devel`; do not assume
the same behavior for projects outside the home directory.

## Sync behavior and verification

- `./sync` previews changes without writing.
- `./sync --check` returns 0 when no changes are needed, 1 for pending changes,
  or 2 for blocked destinations or I/O errors.
- `./sync --apply` writes changes. Differing existing files require
  `--replace-existing`; replacements receive timestamped backups.
- Empty instruction combinations, empty skills, and empty agent definitions
  are skipped. Sync does not remove previously installed files.
- `--home /absolute/temporary/path` redirects installation destinations for
  testing. It does not change where source files are read from.

Do not apply configuration to the real home directory unless the user
explicitly requests installation. Test sync changes with temporary destinations;
never use live configuration as a test fixture.

Run `python -m unittest discover -s tests -v` for sync changes. The tests copy
the current source tree, so populated source fragments can affect tests that
assume an empty scaffold; report that distinction rather than clearing user
content to make tests pass. No build or development server is needed.

Keep shared preferences separate from application behavior and optional model
policies. Never copy credentials, session state, or plugin caches into this repo.
