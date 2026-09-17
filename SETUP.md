# Jira MCP setup

This file is for an agent (or you) wiring Jira into Claude Code, Codex, Grok,
Cursor, and OpenCode from this repository. T3 has no MCP config file.

## Prompt to paste into a new session

```
Follow SETUP.md in this repository to wire Jira MCP into Claude Code, Codex, Grok, Cursor, and OpenCode. Use my existing Bitwarden login whose URI is the Jira URL. Do not put the URL or credentials in git, do not create or rename Bitwarden items, and do not run bw login from the agent.
```

## What gets installed

Each tool starts `~/.local/bin/mcp-atlassian-start <jira-url>` as an MCP
server. That script unlocks Bitwarden if needed (zenity), then reads the
username and password from the vault login whose URI is that URL, and execs
`uvx mcp-atlassian` in read-only mode. The password never goes into git, into
`config.json`, or into the tool MCP files.

`config.json` holds only the URL (and an instance key). Sync merges the server
entries. One instance becomes MCP server `jira`. Two or more keep the keys you
wrote under `mcp.jira.instances`.

## Do not

- Commit `config.json`, URLs, usernames, passwords, or Bitwarden session files.
- Create, rename, or edit Bitwarden items. The login whose URI is the Jira URL
  must already exist.
- Run `bw login` from the agent. Login needs a real terminal (device approval).
- Use `rbw`. Official `bw` only.
- Put the Jira URL in a tool prompt as a way to start MCP. MCP starts from the
  tool config when the session starts, not from chat text.
- Apply with `./sync --home` pointed at a throwaway folder when the user asked
  to install on this machine. `--home` is for tests.

## Prerequisites (ask the user to confirm)

1. Official Bitwarden CLI `bw` is installed and already logged in
   (`bw login --check` succeeds). If it is not logged in, stop and tell them to
   run `bw login` in a normal terminal.
2. The vault already has a login whose URI is the Jira site URL. That item has
   the Jira username and password. Do not search the vault by name.
3. `uvx` and `zenity` are on PATH (`~/.local/bin` is fine for `uvx`).
4. A graphical session so zenity can prompt for the Bitwarden master password
   when the vault is locked (`DISPLAY` is usually enough).

## Steps

1. Work in this repository. Do not put secrets in any committed file.
2. If `config.json` is missing, copy `config.example.json` to `config.json`.
3. Ask the user for each Jira URL they want, unless they already gave it in
   chat. Write those URLs only in `config.json` under `mcp.jira.instances`.
   Use a short letter-starting key per instance (`work`, `other`). Example
   shape, with fake URLs:

   ```json
   "mcp": {
     "jira": {
       "enabled": true,
       "instances": {
         "work": { "url": "https://jira.example.com" }
       }
     }
   }
   ```

   Leave other `enabled` flags as they are. Do not invent a second instance.
4. Preview, then install into the real home folder:

   ```
   ./sync
   ./sync --apply --replace-existing
   ```

   `--replace-existing` is required when a tool already has an MCP config
   (Cursor `~/.cursor/mcp.json`, Grok `~/.grok/config.toml`, Claude
   `~/.claude.json`, Codex `~/.codex/config.toml`, OpenCode
   `~/.config/opencode/opencode.json`). Sync backs those files up next to
   themselves before replacing. It merges only the Jira MCP keys and leaves
   other servers and settings in place.
5. Tell the user to restart each coding tool so it starts the new MCP process.
   The first Jira call in a session may show a zenity window for the Bitwarden
   master password if the vault is locked. That is the Bitwarden master
   password, not the Jira password.

## Disable

Set `mcp.jira.enabled` to `false` in `config.json` (or clear `instances`) and
run `./sync --apply --replace-existing`. Sync removes only the Jira MCP servers
it previously installed.

## Checks if something fails

- `bw login --check` must succeed. If it does not, the user logs in; the agent
  does not.
- `bw get username <url>` and `bw get password <url>` must work after unlock.
  If they fail, the vault login URI does not match the URL in `config.json`.
  Stop. Do not create a new item.
- `mcp-atlassian-start` with no arguments must print usage and exit. Do not
  start it just to test Jira; that would prompt for Bitwarden and print
  nothing useful without an MCP client.
