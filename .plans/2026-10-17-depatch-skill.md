# depatch skill

A shared skill, `skills/shared/depatch/`, installed to all five tools. It
checks whether code ended up as a pile of patches and describes how it would
look if written once with the final requirements known. It is read-only: it
reports and never edits code. Changes happen only after the user says "go" on
a separate step.

## Target

The current branch's changes against its base, unless the user points at
existing code instead (a module, folder, or feature, however old). The steps
are the same. Only the evidence differs: for a branch, the conversation, the
plan in `.plans/`, the PR, and the branch commits; for existing code, the code,
tests, docs, and its git history. A target too big to report on clearly gets a
proposed split and a question instead of a report.

## Steps

1. **Spec.** Write what the target does today as behaviours, not code. Mark
   behaviours that look accidental as questions for the user.
2. **Blind design.** A fresh subagent gets only the spec and the code around
   the target: for a branch, the base commit; for existing code, what calls it
   and what it calls. It never sees the target's code or history. It designs
   the target from scratch. In T3 Code this is `delegate_task`; elsewhere the
   tool's own subagent. Without either, the session does it itself and the
   report says the design is not blind.
3. **History.** Use `git log -p` over the target to find churn: lines
   rewritten repeatedly, reverts, fixes of earlier fixes. Churn points where to
   look; it proves nothing alone.
4. **Compare.** Put the blind design next to the real code. Each gap is a
   candidate patch scar.

## Report

- Verdict: clean, some patching, or a pile of patches.
- The spec, with the open questions.
- Patch scars with file:line, each saying which history it comes from.
  Examples: one-caller flags, special cases beside a general path, wrappers
  around the target's own code, two ways to do one thing, leftovers of an
  abandoned direction, back-and-forth data conversions, history names (`new`,
  `v2`), tests pinning intermediate behaviour.
- Redesign: how it would look written once, its rough size against today's
  code, and for existing code a safe order of steps. These are suggestions.

## Work

Add the skill and its `config.defaults.json` entry, run the tests and a
temporary `--home` sync, open the PR, then try the skill on a real branch.
