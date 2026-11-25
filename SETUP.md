# Setup

`./sync` copies files. This file is the extra machine setup those tools need
after that. Add a section when something new needs steps beyond `./sync`.

## Jira MCP

Needs systemd and these commands installed: `bw`
(Bitwarden CLI, already logged in with `bw login`), `uvx`, `bwrap` (bubblewrap),
`python3`, `systemd-run`, and `systemctl`. Desktop unlock also needs `zenity`
and `setpriv`. `mcp-atlassian-start` stops with a message naming any that is
missing.

1. If `config.json` is missing, create it containing `{}`.
2. Ask for each Jira URL unless the user already gave it. Add each instance
   only to `config.json`, as
   `{"mcp": {"jira": {"instances": {"<key>": {"url": "<Jira URL>"}}}}}`, and
   keep any settings already there. Do not commit that file. Do not
   create or rename Bitwarden items. Do not run `bw login`.
3. `./sync --apply --replace-existing`
4. Unlock once per boot. Do not restart T3.
   - SSH or a local terminal: `session-unlock` (TTY prompts for the GitHub SSH
     key passphrase and the Bitwarden master password).
   - T3 Code: secret prompt for each, then
     `SSH_KEY_PASSPHRASE=... github-ssh-unlock` and
     `BW_PASSWORD=... mcp-atlassian-start --unlock`.
   - Desktop login: autostart runs `session-unlock` and can open password
     windows.
   That caches Jira logins in `jira-cred-agent`, loads the GitHub key into
   `github-ssh-agent`, and warms the sandboxed `mcp-atlassian` daemon.
   Bitwarden locks again immediately afterward.
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

## Android verification

A project verification skill drives an Android app with Maestro through
`bin/maestro.sh`, which downloads the Maestro version it needs by itself. The
machine needs:

1. Java 17 or newer: `java -version`.
2. `socat`: `sudo apt install socat`.
3. Unprivileged user namespaces. Check: `unshare --user --map-root-user --net true && echo ok`.
   On Ubuntu 24.04 and later this fails by default. Allow them with
   `sudo sysctl kernel.apparmor_restrict_unprivileged_userns=0`, and keep it after
   a reboot with
   `echo kernel.apparmor_restrict_unprivileged_userns=0 | sudo tee /etc/sysctl.d/60-userns.conf`.
4. The Android SDK with an emulator and a system image, as the project's
   verification skill says.

## Stacked PRs

Needs `gh` installed and logged in (`gh auth login`).

1. Once: `gh extension install github/gh-stack`
2. Check it: `gh stack --version`

## Codex hooks

Codex skips local hooks in `~/.codex/hooks.json` until you trust them. After `./sync --apply` installs or updates a hook, run `/hooks` in Codex (or open Codex Desktop settings) and approve the hook.
