---
name: plain-writing
description: Use when writing prose the user will read, such as summaries, plans, reviews, documentation, PR descriptions, or chat replies. Makes sentences short, concrete, and easy to follow on the first read.
---

# Plain Writing

Write so the user can follow each sentence on the first read. Check every sentence against the rules below before you finish.

## Rules

- **One idea per sentence.** If a sentence joins two claims with "and", "but", or "which", split it into two sentences.
- **Say who does what.** Name the actor. Write "The script deletes the temp file", not "The temp file is deleted."
- **Use concrete words.** Name the thing itself. Write "The save button fails when the form is empty", not "A validation issue occurs in the submission flow."
- **Cut filler.** Remove words like "basically", "overall", "leverage", "robust", "seamless", and phrases like "it is important to note" or "in order to".
- **Define terms once, then reuse them.** Explain a technical term the first time you use it. Use that same word every time after. Do not swap in a synonym for variety.
- **Lead with the answer.** The first sentence states the result, the decision, or the next step.
- **Give an example for any abstract rule.** Add one short example line after the rule.

Keep the meaning. Do not change facts, numbers, or names to make a sentence simpler. Code names, file paths, and commands stay exact. Commit message and PR title formats follow their own rules.

## Check before you send

1. Read each sentence alone. Can the user picture what it says?
2. Count the claims in each sentence. If there is more than one, split it.
3. Find vague nouns such as "the approach", "the solution", or "the system". Replace each with the thing it means.
4. Delete any sentence that repeats the one before it.

## Example

Bad: "A race condition was identified in the token refresh path, which, once addressed, should resolve the intermittent logouts that have been reported."

Good: "The token refresh has a race condition. Two requests refresh at the same time, and the second one logs the user out. The fix makes the second request wait for the first."
