# depatch: blind comparison, no history filter, shorter report

Three changes to `skills/depatch/SKILL.md`. The rest of the skill stays: it is
read-only, the target and spec rules hold, and it ends by asking whether the
user wants the redesign.

## Why

- The main agent compares the blind design with the code, although it wrote
  that code. It is not neutral.
- A finding counts only when the git history explains it. Code that was
  over-built in one commit passes clean.
- The report prints the whole spec before the findings, so it is too long to
  read.

## Changes

1. **The subagent compares.** One fresh subagent works in two phases:
   - It designs the target from the spec and writes the design to
     `.plans/scratch/<branch>/depatch/design.md`, before it opens the
     target's code. At the top it lists what it had read by then, so a leak
     shows.
   - It then reads the target's code and `git log -p`, and answers with
     every place where the real code is bigger, more tangled, or shaped
     differently. The main agent saves that answer to `findings.md`, because
     Claude Code refuses a subagent that writes a report file.

   The main agent writes the spec, as today, and saves it to `spec.md` in the
   same folder. After the subagent answers, the main agent checks each
   finding. It drops one only when the code does not show it, or when a
   decision of the user explains it. Dropped findings go to `dropped.md` with
   the reason, and the report gives their count.

   The main agent waits for the subagent. It writes the design itself only
   when no subagent can run, and then says the review is not blind.
2. **History explains, it does not filter.** These two rules go away: "Keep
   it only if you can name the history that produced it" and "Code that is
   only verbose but was written in one go is not a scar". Each finding names
   where it came from: the commits that produced it, or "written this way
   from the start". The list of typical scars stays, as examples for the
   subagent. So does the rule that the real code may be better than the
   design.
3. **A shorter report.**
   - Verdict: one line, same three levels.
   - Findings: most important first, one line each.
   - Redesign: its size against today's code and what it drops.
   - Open questions: only the ones that need the user's answer.

   The spec, the design, the full findings and the dropped findings stay in
   the scratch folder. The report links them.

"Patch scars" becomes "findings", because a finding no longer needs patch
history. `tourik` names the old word in its report list, so that one word
changes there too. `docs/skills.md` gets the new one-line description.

Not part of this: a scope-creep list, a taste pass, and the rule in `tourik`
for when it starts depatch.

## Work

Edit the skill, run the tests and a temporary `--home` sync, open the PR,
then run the new skill on a real branch of this repository.
