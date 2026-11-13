# Configuration

## Sync commands

```
./sync                                # show what would change, write nothing
./sync --check                        # same, but exit 1 when changes are pending
./sync --apply                        # make each tool's config folder match this repository
./sync --apply --replace-existing     # also replace files sync did not write, after a backup
./sync --clean-backups                # delete the backups sync has saved
./sync --home /tmp/test --apply       # install into another folder, for testing
```

Sync adds, updates, and deletes what it installed, and touches nothing else. Without
`--replace-existing` it refuses to replace or delete a file it did not write. With it,
sync first saves the file under `~/.config/agent-config/backups/<timestamp>/`. The full
rules are in [AGENTS.md](../AGENTS.md#what-sync-owns).

## Settings

The shipped settings are in `config.defaults.json`. Do not edit that file. Put your
changes in `config.json` next to it, then run `./sync --apply`. Git ignores
`config.json`.

`config.json` has the same shape as `config.defaults.json`, but holds only the keys you
change. Every key you leave out keeps its shipped value.

### Turn something off

Set `enabled` to `false` under `skills`, `agents`, or `hooks`. The key is the skill's
folder name, or the agent's or hook's file name without the extension. The next
`./sync --apply` removes it from every tool.

```json
{ "skills": { "bro": { "enabled": false } } }
```

### Change a skill default

Some skills have a `defaults` object in `config.defaults.json`, for example the model a
reviewer uses. Copy the key you want into `config.json` and give it a new value. A list
replaces the whole shipped list.

```json
{ "skills": { "codex-review": { "defaults": { "model": "<model id>" } } } }
```

These are only defaults. A model or effort you name in a request always wins.

### Jira

Jira URLs go in `config.json` too. Follow [SETUP.md](../SETUP.md#jira-mcp).

## Hide agent work from clients

Some clients must not see that an agent worked on their code. Two actions would show it.
This repository calls them the restricted actions:

- adding attribution lines ("Filed by ... through ...") to PR descriptions;
- marking a PR ready for review when the work is finished and verified.

By default the agent does neither, in any repository. It leaves the attribution out and
leaves each PR as a draft for you to publish.

To allow both actions somewhere, add an entry to `allow.restricted` in `config.json`.
An entry is a GitHub owner, which covers all of that owner's repositories, or one
`owner/repo`. Upper and lower case do not matter.

```json
{ "allow": { "restricted": ["some-owner", "some-org/some-repo"] } }
```

Then run `./sync --apply`. It writes the list into the installed instructions.

The agent reads the repository's name with `gh repo view --json nameWithOwner`. A
repository that is not on GitHub never allows the two actions.

If a client's repository must also stay free of agent files, see
[Companion QA repository](verification.md#companion-qa-repository).
