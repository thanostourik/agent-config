---
name: depatch
description: Use when the user asks whether code ended up as a pile of patches, or how it would look if written once with the final requirements known.
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

- for a branch: the conversation, the plan in `.plans/`, the PR description,
  the tests, and the diff
- for existing code: the code, its tests and docs, and its git history with the
  PRs and issues it links

Mark behaviours that look accidental, such as a quirk callers may rely on, as
open questions. Do not silently keep or drop them.

## 2. Blind design

A designer who never saw the target's code or history designs it from scratch.
Start one fresh subagent for this: in T3 Code use `delegate_task` with
`mode: "async"`; otherwise use the tool's own subagent. Use the current
provider and model unless the user chose others.

Give the designer only:

- the spec
- the code around the target: for a branch, the base commit; for existing
  code, the code that calls the target and the code the target calls
- the paths it must not read: the target's files, and the branch diff and
  commits

Ask for: the modules or functions with their responsibilities, the data flow,
the names, and a rough size in lines. Tell it: read only, no edits, no
subagents of its own.

If no subagent is available, write the design yourself before you read the
target's code closely, and say in the report that the design is not blind.

## 3. Compare

Put the blind design next to the real code. Each place where the real code is
bigger, more tangled, or shaped differently is a candidate patch scar. Keep it
only if you can name the history that produced it and the spec does not need
it. The real code may also be better than the blind design; say so when it is.

Typical scars:

- a flag or parameter that only one caller uses
- a special case next to a general path that could cover it
- a wrapper around code written for the same target
- two ways of doing one thing, from an old and a new direction
- leftovers of an abandoned direction: dead code, unused config, fields
  written but never read
- data converted to another shape and back
- names that tell history: `new`, `v2`, `legacy`, `fallback`
- tests that pin intermediate behaviour instead of the spec

## 4. History

Read `git log -p` over the target: the branch commits, or the target's paths
for existing code. Look for lines rewritten again and again, reverts, and fixes
of earlier fixes. Churn shows where to look closer. It proves nothing alone.

## Report

1. **Verdict:** clean, some patching, or a pile of patches, in one line.
2. **Spec:** the behaviours, then the open questions.
3. **Patch scars:** most important first. For each: file and line, what it is,
   the history that produced it, and what the written-once version does
   instead.
4. **Redesign:** the structure written once, its rough size against today's
   code, and what it drops. For existing code, add a safe order of steps where
   each step leaves the code working.

End by asking whether the user wants the redesign. Do not start it yourself.
