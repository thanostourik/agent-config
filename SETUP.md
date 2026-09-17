# Setup

`./sync` copies files. This file is the extra machine setup those tools need
after that. Add a section when something new needs steps beyond `./sync`.

## Jira MCP

1. If `config.json` is missing, copy `config.example.json` to `config.json`.
2. Ask for each Jira URL unless the user already gave it. Write it only in
   `config.json` under `mcp.jira.instances`. Do not commit that file. Do not
   create or rename Bitwarden items. Do not run `bw login`.
3. `./sync --apply --replace-existing`
4. Tell the user to restart the coding tools.

## render-plan

1. Once, in a normal terminal: `npx postplan auth login`
