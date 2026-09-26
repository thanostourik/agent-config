# Hooks: one source per hook, shared across tools, switched one by one

## Problem

`hooks/<tool>.json` is one file per tool, and `config.json` switches that whole
file. Every tool file today holds the same render-plan hook, written three
times in three formats. There is no way to turn off one hook without turning
off all hooks for that tool, and no way to write a hook once for every tool.

## Design

Hooks follow the skills layout:

- `hooks/<tool>/<name>.json`: a hook for one tool, in that tool's native shape.
  The file holds an object of event name to list of native hook items, the
  same object that sits under the tool's `hooks` key today.
- `hooks/shared/<name>.json`: a hook for every tool that supports hooks
  (Claude Code, Codex, Cursor), written once in a neutral shape:

  ```json
  {
    "harness": "claude-code, cursor",
    "event": "after-edit",
    "command": "$HOME/.local/bin/render-plan --hook",
    "timeout": 30
  }
  ```

  `harness` is optional and has the same meaning as in skills. Naming a tool
  without hooks is an error. `event` is one of the names in the `HOOK_EVENTS`
  table in `sync`, which maps it to each tool's event name and item shape.
  Today that table holds `after-edit` only. Add rows when a hook needs them.

Sync collects the enabled hooks for each tool, sorted by name, and merges
their event lists into one object. That object goes where hooks go today: the
`hooks` key of `~/.claude/settings.json`, a `{"hooks": ...}` file for Codex, a
`{"version": 1, "hooks": ...}` file for Cursor. A tool with no enabled hook
gets nothing, so a previously installed file or key is deleted.

`config.json` switches hooks by name, like skills:

```json
"hooks": { "render-plan": { "enabled": true } }
```

A shared hook and a per-tool hook with the same name for the same tool stop
sync before writes, like duplicate skill destinations.

## Steps

1. Replace the three `hooks/<tool>.json` files with `hooks/shared/render-plan.json`.
2. Teach `sync` the new layout, the neutral shape, and the merge.
3. Rewrite the hook tests; add one for merging two hooks on one event and one
   for the shared-to-native translation.
4. Update `config.example.json`, `AGENTS.md`, and the `sync` docstring.
