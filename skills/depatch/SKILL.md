---
name: depatch
description: Use when the user asks for "depatch" or "depatchify".
---

# depatch

Code built over many rounds of fixes and changes of direction often reads like
patches piled on patches. You check whether that happened and describe how the
code would look if it had been written once, with the final requirements known
from the start.

This skill is read-only. Do not edit, commit, or delete anything. The redesign
is a suggestion; the user decides later whether to do it.

## Target

The target is what the user points at: a module, a folder, or a feature, however
old. Otherwise it is the current branch's changes against its base: the PR's
base branch, or `origin/main` when there is no PR.

If the target is too big to report on clearly, such as a whole repository,
propose a split into parts and ask which one to start with.

## 1. Spec

Write what the target does today, as behaviours a user or caller can observe,
not as code. For example: "`--check` exits 1 when the state file is out of
date". Take them from:

- for a branch: the conversation, the plan this branch added in `.plans/`, the
  PR description, the tests, and the diff
- for existing code: the code, its tests and docs, and its git history with the
  PRs and issues it links

Write each behaviour as an outcome, not as the mechanism behind it: "parallel
starts show one password dialog", not "takes a `flock` on `agent.lock`". A
mechanism in the spec leaks today's design to the designer.

Mark behaviours that look accidental, such as a quirk callers may rely on, as
open questions. Do not silently keep or drop them.

Save the spec to `.plans/scratch/<branch>/depatch/spec.md`. The notes in that
folder are the only files this skill writes.

## 2. Blind review

A reviewer who never saw the target's code, its history, or this conversation
designs the target from scratch, and then compares that design with the real
code. You wrote or discussed the target, so you do not compare.

Start one fresh subagent for this: in T3 Code use `delegate_task` with
`mode: "async"`; otherwise use the tool's own subagent. Use the current
provider and model unless the user chose others.

Give the reviewer only:

- the spec, with its open questions
- the code around the target: for a branch, the base commit; for existing
  code, the code that calls the target and the code the target calls. When
  that code is outside the repository, describe what it offers in a few
  sentences.
- where the target is, for the second phase: the base and head commits of a
  branch, or the paths of existing code
- the two phases below and the list of typical findings, word for word

It writes `design.md` in the spec's folder and changes nothing else. It starts
no subagents of its own.

**Phase 1: design.** From the spec and the code around the target alone, it
designs the target: the modules or functions with their responsibilities, the
data flow, the names, and a rough size in lines. It writes this to
`design.md`. Until that file is written it must not read the target's files,
installed copies of them, notes or reviews that quote them, the branch diff,
or the git history.

**Phase 2: compare.** It reads the target's code and `git log -p` over it: the
branch commits, or the target's paths for existing code. It no longer changes
`design.md`. It reports:

- every place where the real code is bigger, more tangled, or shaped
  differently than the design. For each: file and line, what it is, what the
  design does instead, and where it came from. That is the commits that
  produced it, or "written this way from the start". Lines rewritten again
  and again, reverts, and fixes of earlier fixes show where to look closer.
- every place where the real code is better than the design
- the rough size of the design against the real code, and what the design
  drops

Typical findings:

- a flag or parameter that only one caller uses
- a special case next to a general path that could cover it
- a wrapper around code written for the same target
- two ways of doing one thing, from an old and a new direction
- leftovers of an abandoned direction: dead code, unused config, fields
  written but never read
- data converted to another shape and back
- names that tell history: `new`, `v2`, `legacy`, `fallback`
- tests that pin intermediate behaviour instead of the spec
- code that is more complicated than the spec needs, even when it was written
  in one commit

Wait for the reviewer. Do not cancel it, and do not design or compare
yourself while one can run.

If no subagent is available, write the design yourself from the spec alone
before you look at the target's code again, then compare. Say in the verdict
that the review is not blind.

## 3. Check

The reviewer does not know the conversation, so it cannot tell a decision
from an accident. Check each finding against the code and against what the
user decided: in the conversation, the plan, the PR, or the issue. Drop a
finding only when:

- the code does not show what the finding says, or
- the user asked for this shape or chose it

Write each dropped finding and its reason to `dropped.md` in the spec's
folder. Liking today's code better is not a reason to drop a finding.

## Report

1. **Verdict:** clean, some patching, or a pile of patches, in one line.
2. **Findings:** most important first, one line each: file and line, what it
   is, where it came from, and what the written-once version does instead.
   For example: "`sync:412`: `--force` is passed only by the tests (added in
   `a1b2c3d`). Written once, the tests call `install()` directly."
3. **Redesign:** its rough size against today's code, and what it drops. For
   existing code, add a safe order of steps where each step leaves the code
   working.
4. **Open questions:** only the ones the user must answer.

Then link `spec.md`, `design.md`, and `dropped.md`, and give the number of
dropped findings. Do not repeat what those files say.

End by asking whether the user wants the redesign. Do not start it yourself.
