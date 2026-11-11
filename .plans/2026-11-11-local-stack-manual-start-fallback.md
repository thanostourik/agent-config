# The app starts without a stack again

## Why

Version 15 made an app on the host stop at startup when `local-stack/.stack.env`
is missing, and removed its fallbacks to the usual ports. That answered an
incident caused by an agent's test run. A developer who starts the app by hand,
such as from the IDE against the usual ports with no stack file, had nothing to
do with it, and the rule breaks that run.

## The rule

- Without the stack file, the app on the host uses its committed settings,
  whose ports are the usual ports. With it, the stack file's values replace them.
- Kept from version 15: isolated tests, and agents that start their own stack
  with `--name` and never start the app on the host without one.
- Kept from version 16: the app prints `LOCAL_STACK_SUMMARY` when it loads the
  stack file.

## Files

- `references/stack-spec.md`: "The app's configuration" loses the stop and the
  no-fallback rules; the script's stack file bullet and README section 3 say the
  app uses its committed settings without a stack.
- `SKILL.md`: the stack file word, the design no longer lists setups that
  relied on a fallback, and proof step 7.2 checks the fallback inside the
  isolation container instead of the stop.
- `references/changelog.md`: version 17, which undoes what version 15 added
  for the stop rule.
