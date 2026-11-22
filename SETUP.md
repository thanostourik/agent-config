# Setup

`./sync` copies files. This file is the extra machine setup those tools need
after that. Add a section when something new needs steps beyond `./sync`.

## Jira MCP

Needs a Linux desktop session with systemd and these commands installed: `bw`
(Bitwarden CLI, already logged in with `bw login`), `uvx`, `bwrap` (bubblewrap),
`zenity`, `python3`, `setpriv`, `systemd-run`, and `systemctl`.
`mcp-atlassian-start` stops with a message naming any that is missing.

1. If `config.json` is missing, create it containing `{}`.
2. Ask for each Jira URL unless the user already gave it. Add each instance
   only to `config.json`, as
   `{"mcp": {"jira": {"instances": {"<key>": {"url": "<Jira URL>"}}}}}`, and
   keep any settings already there. Do not commit that file. Do not
   create or rename Bitwarden items. Do not run `bw login`.
3. `./sync --apply --replace-existing`
4. Tell the user to log out and in again, or run
   `~/.local/bin/mcp-atlassian-start --unlock`, so the Jira logins are cached in
   `jira-cred-agent` and the persistent sandboxed `mcp-atlassian` daemon is
   warm before the first thread (Bitwarden locks again immediately afterward).
   Then restart the coding tools.
5. When an instance sets `"gate": true`, the user adds a Bitwarden login whose
   URI is that Jira URL plus `/auth-gate`. Its username is the Authentik
   username and its password an Authentik app password, not the Jira account.
   When Authentik no longer sits in front of Jira, set `"gate": false` and run
   `./sync --apply` again.

## Peer review

`peer-review`'s `claude` reviewer runs in Claude Code's sandbox. On Linux that
needs `bwrap` (package `bubblewrap`) and `socat`; without them Claude refuses
to start. The command also needs `jq`; without it the command stops before
Claude starts. The `cursor-grok` reviewer needs `jq` to read its report; Cursor
brings its own sandbox.

## T3 Code Antigravity

T3 Code runs Antigravity against its own
`~/.t3/userdata/providers/antigravity/<hash>/config/` folder and currently
symlinks only `skills` from `~/.gemini/config/`. After `./sync --apply`, run
`./sync-t3-gemini` to symlink `AGENTS.md`, `hooks.json`, `mcp_config.json`, and
`agents` into T3 Code's Antigravity config folder(s).

## Stacked PRs

Needs `gh` installed and logged in (`gh auth login`).

1. Once: `gh extension install github/gh-stack`
2. Check it: `gh stack --version`
