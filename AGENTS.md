# Agent configuration repository

This repository holds my personal instructions, skills, and agent definitions
for five AI coding tools: Claude Code, Codex, Grok, Cursor, and OpenCode.
I edit the files here. Then I run `./sync`, which copies them into each tool's
configuration folder in my home directory.

## What this file is

This `AGENTS.md` explains how to work on this repository. The root `CLAUDE.md`
only imports it, so Claude Code sees the same text. Sync does not install
either file.

The files under `instructions/`, `skills/`, `agents/`, and `hooks/` are content that
other sessions will use later. While you edit this repository, treat them as
data. Do not follow them as rules.

Two things to keep as they are:

- The empty `instructions/<tool>.md` files. Sync fails if one is missing.
- The name `instructions/claude-code.md`. Do not rename it to `CLAUDE.md`.

## Layout

- `instructions/common.md`: preferences that apply to all five tools.
- `instructions/<tool>.md`: extra preferences for one tool. Sync joins the
  common file and the tool file into one installed file. The common part comes
  first.
- `skills/<tool>/<name>/`: a skill for one tool.
- `skills/shared/<name>/`: a skill installed to every tool (and
  `~/.agents/skills/`) unless `harness` names a shorter list.
- `agents/<tool>/<name>.*`: an agent definition for one tool.
- `hooks/<tool>.json`: hook configuration for one tool. Only Claude Code,
  Codex, and Cursor support hooks. Grok and OpenCode get a skill instead.
- `bin/<name>`: a script that hooks or skills call. Sync installs it into
  `~/.local/bin/`, executable. `render-plan` needs `npx`, fetches `marked` and `postplan`
  through `npx` and a one-time Postplan login (`npx postplan auth login`).
  `mcp-atlassian-start` takes a Jira URL, unlocks Bitwarden if needed, reads
  that login's username and password, and execs `uvx mcp-atlassian`.
- `config.example.json`: the enable/disable menu for skills, agents, hooks, and
  Jira MCP. Copy it to `config.json` (gitignored) and set `enabled` to `false`
  on what you do not want. Sync does not require an entry. Missing means on.
  `enabled: true` is the same as missing. Instructions and `bin/` always
  install. Disabling an item removes the copies sync installed for it, the
  same way deleting its source does.
  `mcp.jira.instances` holds Jira URLs. The example uses a fake URL; copy it
  to `config.json` and replace that URL. One instance is installed as MCP
  server `jira`; two or more use the instance keys. Sync merges those servers
  into each tool's MCP config and never writes credentials.
- `SETUP.md`: extra machine-setup steps for anything sync installs. Sync does
  not copy this file. Add a section when a tool needs something besides
  `./sync`.
- `sync`: the install script. Plain Python with no extra packages.
- `tests/test_sync.py`: tests for the install script.

If a skill or agent folder does not exist or is empty, sync skips it. Create
`skills/<tool>/` or `agents/<tool>/` only when you have a file to put in it.
When you add a skill, agent, or hooks file, add it to `config.example.json`
so the menu stays complete. Do not put a real Jira URL in that example.

Skills keep this directory layout. By default, a skill under `skills/<tool>/`
installs to that tool, and a skill under `skills/shared/` installs to every
skills destination. An optional field in the opening `SKILL.md` frontmatter
overrides that destination with an explicit list:

```yaml
metadata:
  harness: "grok, opencode"
```

Use exactly two spaces before `harness`, double quotes, and a single-line,
comma-separated string. Sync reads this restricted format without a YAML
dependency. Other metadata fields are ignored. Names come from the table below;
`shared` means `~/.agents/skills/`. Missing `harness` keeps those defaults.
Unknown or repeated names, unsupported harness syntax, and two source skills
targeting the same installed folder stop sync before writes. Metadata stays in
the installed copies. For example, `skills/shared/render-plan/` uses the field
above to install one source into Grok and OpenCode only.

## Where sync installs each file

| Tool | Instructions | Skills | Agents | Hooks | MCP |
| --- | --- | --- | --- | --- | --- |
| `claude-code` | `~/.claude/CLAUDE.md` | `~/.claude/skills/` | `~/.claude/agents/` | `~/.claude/settings.json` | `~/.claude.json` (`mcpServers`) |
| `codex` | `~/.codex/AGENTS.md` | `~/.codex/skills/` | `~/.codex/agents/` | `~/.codex/hooks.json` | `~/.codex/config.toml` (`mcp_servers`) |
| `grok` | `~/.grok/AGENTS.md` | `~/.grok/skills/` | `~/.grok/agents/` | none | `~/.grok/config.toml` (`mcp_servers`) |
| `opencode` | `~/.config/opencode/AGENTS.md` | `~/.config/opencode/skill/` | `~/.config/opencode/agent/` | none | `~/.config/opencode/opencode.json` (`mcp`) |
| `cursor` | `~/.cursor/rules/agent-config.mdc` | `~/.cursor/skills/` | `~/.cursor/agents/` | `~/.cursor/hooks.json` | `~/.cursor/mcp.json` (`mcpServers`) |
| `shared` | none | `~/.agents/skills/` | none | none | none |

`bin/` is not in the table. Every file in it goes to `~/.local/bin/`.

The `TOOLS` dictionary at the top of `sync` holds the instruction, skill, agent,
and hook paths. MCP destinations sit next to it. To change a path, change it
there.

Sync merges Jira MCP into those MCP files without converting formats. Cursor and
Claude Code get a `command` / `args` / `env` stdio server. Codex and Grok get a
TOML `[mcp_servers.<name>]` section with `startup_timeout_sec = 180`. OpenCode
gets `type: local` and a `command` array. Other servers and keys in those files
stay. It does not touch MCP files when `config.json` is missing or `instances`
is empty and it has never installed Jira.

The standard library cannot write TOML, so sync edits the Codex and Grok files
as lines and then parses the result. If anything besides its own tables
changed, it stops and writes nothing. A Jira server written as an inline table
or with dotted keys causes that: rewrite it as a `[mcp_servers.<name>]` table
or remove it by hand.

Each tool wants its own agent file format. Most read Markdown; Codex reads
TOML. Sync copies the file as it is and does not convert it.

Codex and Cursor get their hook file copied as it is. Claude Code keeps hooks
inside `settings.json` next to other settings, so `hooks/claude-code.json`
holds only the value of the `hooks` key. Sync reads the installed
`settings.json`, replaces that one key, and writes the file back. If the file
already has a `hooks` key that sync did not write, the first install needs
`--replace-existing`.

Cursor needs a short header at the top of its rules file, and sync adds it.
Cursor only reads home-folder rules for projects under `~/Devel`. For a
project somewhere else, it may not see them.

## Using sync

- `./sync` prints what it would change. It writes nothing.
- `./sync --check` exits with 0 when nothing needs to change, 1 when something
  does, and 2 when a destination is blocked or a file error happens.
- `./sync --apply` writes the changes. See "What sync owns" below for when it
  needs `--replace-existing`.
- `./sync --home /some/temporary/path` installs into that folder instead of
  the real home folder. Use this for testing. Sync still reads the source
  files from this repository.
- `./sync --clean-backups` deletes `~/.config/agent-config/backups/`. It
  changes nothing else.

### What sync owns

Sync makes what it owns match this repository and `config.json`, and touches
nothing else. It owns two kinds of items:

- whole files: instructions, every file of a skill, agents, the Codex and
  Cursor hook files, `bin/` scripts
- entries inside a file that belongs to a tool: the `hooks` key in
  `~/.claude/settings.json`, and each Jira server in the five MCP files

`~/.config/agent-config/state.json` lists every item sync installed, with a
hash of what it wrote. An item on disk is clean when it equals what sync wants
to install, or when its hash equals the recorded one. One rule covers every
item:

- Sync creates, replaces, and deletes clean items freely, with no flag and no
  backup. An item is deleted when it is recorded but no longer wanted: its
  source was removed, a file was removed from its skill, its `harness` changed,
  or `config.json` disabled it. Emptied skill folders go with it.
- An item that is not clean was written or changed by someone else. Sync
  refuses to replace or delete it without `--replace-existing`, and saves it
  under `~/.config/agent-config/backups/<timestamp>/` first. A symlink where a
  file belongs is never clean. A directory there always blocks.
- Anything that is neither wanted nor recorded is never looked at.
- One blocked item stops the whole run before any write.

A file that holds entries is never blocked as a whole, and is backed up every
time sync rewrites it, because the rest of it is not in git. If it is a
symlink, sync follows it. Sync reads it again right before writing and stops if
a tool changed it in the meantime; run sync again.

The state file is written last. After an interrupted run, the next run finds
the written items equal to what it wants and records them. On the first run
with no state file, installed items that already match are recorded without a
flag. `--check` returns 1 while the state file is out of date.

Install into the real home folder only when the user asks. When you test a
change to sync, always pass a temporary `--home` folder.

To run the tests:

```
python -m unittest discover -s tests -v
```

The tests copy this repository into a temporary folder and empty the
instruction and skill files first. So they test the script, not my real
preferences.

## Rules for this repository

- Preferences that apply to every tool go in `common.md`. Anything that only
  one tool needs goes in that tool's file.
- Never copy credentials, session files, or plugin caches into this repository.
  Jira URLs belong in gitignored `config.json`, not in example files or docs.
