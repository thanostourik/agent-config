# Pick features from the diff, not from path globs

## Problem

Generated verify skills pick the features to drive by file path. Each line under
`## Change triggers` in `features/README.md` maps backticked globs to features,
and `rec.sh affected` matches the changed files against them.

A path says where a file sits, not what it changes. That breaks for folders that
every feature adds files to. contentcloud backend-spring maps
`src/main/resources/db/migration/*` to 15 of its 19 features. CHA-973 only added
a new table (`V38__selected-tenant.sql`), and that one file selected 15 features
for recording and driving.

The globs are an agent's judgment, written once at generation and repeated by a
script on every run. A guess like "a migration could touch anything" never gets
corrected, and the globs go stale when code moves.

## Design

The agent that selects reads the change itself and picks features from the
feature index. Migrations get no rule of their own: every changed file is judged
by what it changes. The `## Change triggers` section and the glob matching are
deleted, and the affected text is rewritten as if selection had always worked
this way.

### Selection rule

One rule, in both places that select:

- Select a feature when the change adds, changes or removes code, data or
  configuration that the behavior on its index line uses. Each selected feature
  gets one reason line that names the changed file and what in it touches the
  feature.
- An addition selects the features that use it. A new table, endpoint or file
  that only a new feature uses selects only that new feature.
- A change that touches no feature's behavior selects nothing: tests,
  documentation, build files that leave the app as it was.

The agent starts from the list of changed files. It reads the diff only of the
files whose feature it cannot tell from the file name and the index lines. It
reads them in one command, in pieces of 20,000 bytes, the same size other reads
in this skill use. At most five pieces: past 100,000 bytes, it selects the
remaining files by name and index line, and the report says which ones.

### `verify-<app>` Pick features

The agent doing the work already knows its change. Pick features becomes: read
the index in `features/README.md`, select by the rule above, state each feature
and its reason in one line. The glob sentence goes.

### Maintenance, changed-recipes mode

- `rec.sh affected` keeps writing `.cache/changed.txt` from the files changed
  since `features/last-reviewed`. It stops reading `## Change triggers`. It
  prints the changed files with their added and removed line counts
  (`git diff --numstat`, untracked files included) and the features with a kept
  staged copy, as today. With no commit, it still says to record every feature.
  With no changed file, it prints nothing to select, and the run goes to Ship as
  today.
- The main agent selects by the rule above. It writes `.cache/triggered.tsv`
  itself, one `<feature>\t<file>` line per reason, in the step 3 command that
  runs `rec.sh brief`, so the selection costs no extra call when no diff has to
  be read. `rec.sh brief` builds each `changes.diff` from that file as it does
  today; that code does not change.
- Ship's report lists each changed file that selected nothing, with why, in
  place of the `skipped` and `unmapped change` lines.

### Files

- `create-project-verification-skill/SKILL.md`: step 1's Verification triggers
  bullet now only feeds the skill's `description`, saying when an agent should
  use the skill. It gets "migrations" back as an example, because a migration
  change does need verification. Step 4 drops the change triggers from
  `features/README.md` and the sentence on their glob shape. "each with its own
  file, index line and change triggers" loses the triggers. "only the change
  triggers name source" goes.
- `references/verify-skill-spec.md`: the intro sentence that moves the trigger mapping into `features/README.md`
  and the Pick features item.
- `references/maintain-verify.md`: step 1 Index (affected, the grep over
  `.cache/changed.txt`, the selection and `triggered.tsv`, no more "Update
  `## Change triggers`"), step 3's "index entries and change triggers", Ship's
  changed-recipes report.
- `references/rec.sh`: `affected` and its header comment. The other commands do
  not change.
- `references/feature-map-example/README.md`: the `## Change triggers` section
  goes.
- `maintain-project-verification-skill/SKILL.md`: the conformer deletes
  `## Change triggers` from an existing `features/README.md`. The rewrite of
  trigger lines into glob shape in step 4 goes.

This replaces the one-word fix in PR #91, on the same branch and PR, with the
title and description rewritten.

## Cost and speed

Measured numbers come from the PR #79 daily cases on wovies and from CHA-973.

| Case | Today | After |
| --- | --- | --- |
| Nothing changed | 34 s, 3 main-agent calls, no recorder | Same: the empty list ends the run before any read |
| One file whose name tells its feature (wovies daily: a Settings subtitle) | 1 feature selected, 10 skipped | Same selection from the name, no diff read, no extra call |
| CHA-973 (16 files, 23.7 KB of code diff) | 15 of 19 features recorded and driven | The new selected-projects feature, plus any existing feature its diff touches; at most one extra call and about 6,000 tokens to read the unclear diffs |
| Large refactor | Every glob match | At most five 20,000-byte pieces, about 25,000 tokens and one call |

Every run also stops reading the `## Change triggers` section: 8.1 KB, about
2,000 tokens, in backend-spring. One feature recorded for nothing costs
300,000 to 1,500,000 recorder tokens and minutes of driving, so a single avoided
feature pays for many diff reads.

Risk: two runs on the same diff can pick slightly different features. The
reason line per feature keeps each pick checkable.

## Verification

1. `bash -n` on `rec.sh`, then `rec.sh affected` and `rec.sh brief` in a
   throwaway git repository with a minimal skill: no commit, no changes, one
   changed and one untracked file, and a `changes.diff` built from a
   hand-written `triggered.tsv`.
2. `python -m unittest discover -s tests -v` and `./sync --home <temp dir>`.
3. Live, on scratch branches only, after you allow it:
   - The wovies daily case again (one source change), against daily case 3:
     5 min 30 s, 43 main-agent calls with setup, 0.3M recorder tokens.
   - A CHA-973 replay in a temporary worktree of contentcloud backend-spring:
     maintenance in changed-recipes mode from the commit before #67. Pass when
     it selects the selected-projects features and none of the 15 the
     migration glob selects today, at the cost the table above gives.
