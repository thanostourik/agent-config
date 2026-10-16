# agent-config

My personal instructions, skills, hooks, and agent definitions for Claude Code, Codex,
Grok, Cursor, and OpenCode, kept in one place.

## Use

```
./sync                                # show what would change, write nothing
./sync --check                        # same, but exit 1 when changes are pending
./sync --apply                        # make each tool's config folder match this repository
./sync --apply --replace-existing     # also replace content sync did not write, keeping a backup
./sync --clean-backups                # delete the backups sync has saved
./sync --home /tmp/test --apply       # install into another folder, for testing
```

To turn a skill, agent, hook, or Jira MCP off, copy `config.example.json` to
`config.json` and set that entry's `enabled` to `false`. Do not commit
`config.json`. Sync treats a missing entry as on. The next `./sync --apply`
removes the copies it installed for disabled items.

## Skill defaults

Model, provider, and effort choices can be set under a skill's `defaults`:

```json
{
  "skills": {
    "codex-review": {
      "enabled": true,
      "defaults": { "model": "gpt-6.1-sol", "effort": "high" }
    }
  }
}
```

Edit `config.json` in this repository and add or change the settings you want.
If it does not exist, create it with the JSON above. If it already exists,
merge the entry into its existing `skills` object. Run `./sync` to preview,
then `./sync --apply` to install. The installed Markdown contains your chosen
values. Open a new agent session to load the updated skill.

An explicit choice in your request takes precedence over the configured
default. A setting missing from `config.json` uses the shipped default from
the source Markdown. Delete an override and run sync again to restore it.
`config.example.json` lists all supported settings and their shipped values;
sync does not read that file as configuration.

The four CLI review skills support `model` and `effort`. `t3-fan-out` also
supports `provider`. `triple-review` has separate settings for each reviewer:
`general_provider`, `general_model`, `general_effort`, and the same suffixes
under `simplify_` and `over_engineering_`. Providers are T3 provider instance
IDs. Sync validates the configuration's shape; the skills check whether the
selected targets are available when they run.

### Adding a configurable default

In a skill's `SKILL.md` or a Markdown reference file inside its folder, mark
the value with `{{defaults.name|shipped value}}`. For example:

```markdown
Use the user's selected model, or `{{defaults.model|gpt-6.1-sol}}`
when none is specified.
```

That declares `skills.<skill-folder-name>.defaults.model` and the shipped value
`gpt-6.1-sol`. Sync replaces the marker in every installed copy, leaving the
source unchanged. Keep the instruction that explicit user choices win.

Use flat option names starting with a lowercase letter, followed by lowercase
letters, digits, or underscores. Values must be nonempty, single-line strings
without surrounding whitespace or `{{` or `}}`. Shipped values also cannot
contain `|` or braces. Repeated markers for one option must have the same
shipped value. Use prose or lists for markers because `|` separates Markdown
table cells. Add the option and its shipped value to `config.example.json`,
and document its meaning and accepted values here.

Only skill Markdown supports markers; other assets are copied unchanged.
There are no expressions or recursive substitutions. Malformed markers,
unknown options, conflicting shipped values, and invalid configuration stop
sync before any writes, including for disabled skills. Nonempty defaults for
a missing or empty skill also stop sync.

## Project verification skills

Two skills set up and maintain verification for one project. Run them from the
project's root, in a new session. Both are manual: the agent never starts them
on its own.

Start a skill like this:

- Claude Code, Cursor, Grok: type `/skill-name` and the mode, for example
  `/create-project-verification-skill quick`.
- Codex: type `$skill-name` and the mode, for example
  `$create-project-verification-skill quick`.

| Skill | When | Modes |
|---|---|---|
| `create-project-verification-skill` | Once per project. It writes the project's `verify-<app>` and `maintain-verify-<app>` skills, the feature map and an `AGENTS.md` section. | none: write all features, then fully audit<br>`quick`: write and drive one feature per surface, nothing more |
| `maintain-project-verification-skill` | After this repo's generator changed and you ran `./sync --apply`. It brings the project's skills up to date. | none: update the map, drive new and changed steps<br>`map only`: no drives<br>`full audit`: drive every step |

After generation, the project's own skills are the daily tools:

| Skill | Use |
|---|---|
| `verify-<app>` | Agents use it on their own before calling work done. You can also ask for it by name. |
| `/maintain-verify-<app>` | Keeps the feature map honest. Adds features missing from the map and drives new and changed steps. Add `map only` or `full audit`. |

`quick` maps and proves only one feature per surface. The next
`/maintain-verify-<app>` finds the other features in the source, adds them and
drives them. If a project already has these skills, `create` stops and asks
whether to replace or upgrade them. Where a project cannot create a
disposable environment, `create` asks you what to do instead of guessing.

Jira MCP URLs also go in `config.json` (never in git). Some tools need machine
setup beyond copying files. Paste this into a new agent session:

```
Follow SETUP.md in this repository and complete every setup the tools in this repo need.
```

See [SETUP.md](SETUP.md). Sync adds, updates, and deletes what it installed,
and touches nothing else. It refuses to replace or delete content it did not
write unless you pass `--replace-existing`, and then saves it under
`~/.config/agent-config/backups/<timestamp>/` first. See [AGENTS.md](AGENTS.md)
for the ownership rules, folder layout, install locations, and tests.
