# Local stacks are really isolated

## The incident

In a repo with a version 14 stack, the developer's default stack held the
usual ports. An agent in another worktree, with no stack of its own, ran
focused tests. One test class booted the app with its default local profiles.
With no stack file in that worktree, the configuration fell back to its
committed defaults, which are the usual ports. The test connected to the
developer's database and applied the branch's new migration there. The
developer's stack then broke.

The generator caused it: `stack-spec.md` said that without the stack file the
app starts with its committed settings, whose ports are the usual ports. The
usual ports are the developer's stack. The generator said nothing about tests.

## The rule

Nothing started in a checkout without its own stack reaches another stack.
Generic, with framework details only as examples.

1. **No usual-port fallback.** The configuration a local run on the host reads
   sets no fallback for a value the stack provides. Without the stack file the
   process stops at startup, before any connection, with a message naming the
   file and `local-stack/stack up`. A setup that writes the stack file itself
   keeps working. The app's container sets every value in `compose.yaml` and
   skips that check.
2. **Tests are isolated by design.** Tests never read the stack file or the
   local configuration. Each service they need comes from a throwaway instance,
   set once in the test configuration every test loads, never per test. When a
   service has no throwaway instance tests can start, the skill asks.
3. **A proof that cannot repeat the incident.** New proof step 7, "Isolation":
   the whole test suite and an app start without a stack file run in a
   container from a stock toolchain image. Inside it `localhost` is the
   container itself, so no usual port of the host answers, even while the
   developer's stack holds them. When that cannot run, the step is not proved;
   it never falls back to the host. Until it passes, the agent runs tests only
   that way. Cleanup moves to step 8.
4. **Changelog version 15** with these items and their checks, so the update
   flow applies them, test configuration included. It also tells older stacks
   to skip version 10's check that starts the app without a stack file.

## Files

- `references/stack-spec.md`: "The app's configuration" loses the fallback;
  new "Tests" section; the files rule covers the test configuration; README
  section 3 says the app stops without a stack and tests need none.
- `SKILL.md`: words (usual port, stack file, throwaway instance), discovery of
  tests, the design names the test configuration change, update flow covers
  it, proof step 7 and the rule to run tests only that way until it passes.
- `references/questions.md`: the question for a service without a throwaway
  instance.
- `references/agents-local-stack.md`: one line saying tests need no stack.
- `references/changelog.md`: version 15.

The script does not change.
