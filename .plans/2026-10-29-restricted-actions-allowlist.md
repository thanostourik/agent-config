# Restricted actions allowlist

Some clients must not see agent work. So attribution is off by default, and
PRs stay drafts until I mark them ready. Today only tourik mode turns both on.
Personal repos and unrestricted company repos need them too. Restricted client
repos need tourik mode without them.

Restricted actions:

- attribution: the `Reviewed by` and `Filed by` lines in a PR description
- ready-marking: changing a PR from draft to ready for review

## Config

A new top-level `allow` object. Its only key is `restricted`, a list of
GitHub owners (`thanostourik`) or single repos (`eworx-org/some-repo`):

```json
{
  "allow": {
    "restricted": ["thanostourik", "eworx-org/some-internal-repo"]
  }
}
```

`config.defaults.json` ships `"restricted": []`. I add repos in `config.json`.

A repo is allowed when the list holds its owner or its `owner/repo`, compared
case-insensitively. The agent reads both from `gh repo view --json
nameWithOwner`. A repo not on GitHub is not allowed.

## Sync

- Validate `allow`: an object whose only key is `restricted`, a list of
  `owner` or `owner/repo` strings. Anything else stops sync.
- Replace the marker `{{allow.restricted}}` with the list, in skill Markdown
  and in instruction files. It renders like a skill default list: items joined
  with `, `, and `none` when empty. A malformed `{{allow` marker stops sync.

## Consumers

- `common.md`: in an allowed repo, mark the PR ready when the task is finished
  and verified, and attribution in PR descriptions is allowed. Elsewhere,
  the current rules stay: no attribution, and the PR stays a draft until I
  mark it ready.
- `file-pr`: adds attribution in allowed repos, and when I ask for it. The
  `attribution` argument goes away.
- `tourik`: stops passing `attribution`. At the ready gate it marks the PR
  ready only in an allowed repo. Elsewhere it leaves the draft and says so in
  the report. Behavior change: tourik on a repo not in the list no longer
  adds attribution or marks the PR ready.

`review-loop` needs no change: its `Reviewed by` line goes through `file-pr`.
`create-jira-issue` and `create-project-verification-skill` stay as they are.

## Docs

`AGENTS.md` and the `sync` docstring describe `allow` and the marker.

## Verification

- `python -m unittest discover -s tests -v`
- `./sync --home <temp dir> --apply` with a `config.json` that lists repos:
  the installed `common.md`, `file-pr`, and `tourik` show the list. With an
  empty list they show `none`. A bad entry and an unknown `allow` key stop
  sync.
