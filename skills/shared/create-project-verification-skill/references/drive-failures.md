# When a drive fails

Copy this section into the generated `verify-<app>/SKILL.md` as `## When a drive fails`, shortened to what this project needs. Generated skills are read without access to this generator.

Record the action, the expected result and its basis (the request, a documented contract or an established test), the actual result, and the environment conditions. Diagnose before fixing. Classify the failure as one of four kinds:

- **Instructions or helper defect.** A command, locator, wait or helper is wrong. Fix it without changing the expected behavior and retry the affected steps.
- **Environment defect or missing prerequisite.** Setup, seed data or a dependency prevents the check. First create what is missing with the project's own APIs, internal endpoints or documented setup, inside the owned environment. Seed data that lacks records is not a blocker. Report what remains separately from product defects, with what you tried. Repair only within the authorized scope.
- **Product defect.** The real path contradicts supported expected behavior. Fix product code only when it is part of the requested change. Otherwise report the mismatch and leave the expectation intact.
- **Uncertain expectation.** Report what you saw and the decision that is missing. Neither the current code nor a failed assertion alone says what the product should do. Never rewrite an expectation just to pass.
