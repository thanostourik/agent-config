# Questions

The stack depends on facts that the code cannot show. This file says which questions to ask and how. Ask every question that applies. Skip one only when the fact file already holds its answer with a source.

## How to ask

- One decision per question.
- Show the evidence: what you found and where, such as "`application-dev.yml:17` sends chat requests to `https://chatbot.example.com`".
- Give the options, put your recommendation first and say why. Say what each answer changes in the stack.
- Send the questions in rounds, as many at once as your question tool allows, the most important first. A later round may depend on an earlier answer.
- Use the words the user uses. When you must use a term they may not know, explain it in the question.
- An answer that leaves the decision open is not an answer: ask again, narrower.

## Always asked

For each external service:

1. Is it shared with other people, so that an agent's test traffic would reach them?
2. Does calling it have effects that matter, such as cost, sent mail, changed data or rate limits?
3. Which mode does a developer's plain `up` use: `real` or `stub`?
4. May this run call it once to prove `real` mode?

For each address that may belong to another repo of this project:

5. Is it another repo of this project? If so, where is its checkout, and which variable should hold that path?
6. Does this stack start that repo's stack (`stack` mode), use a stub of it (`stub` mode), or offer both? Which one is the default?

## Asked when the code does not settle it

- How the app runs locally, when the build files define several ways or none.
- Which configuration profile or environment a local run uses.
- Whether something the app talks to runs in the stack or is external.
- Where the starting data comes from: migrations alone, a seed script, a dump, or fixtures the stack creates.
- How a user, tenant or API key comes to exist, and which roles a developer needs to try the app.
- Where a developer gets each secret that a `real` mode needs. Never invent one, and never write one into the repo.
- How the developer runs the app from the IDE, when the app has no way to read a configuration file.
- Which switches mark a service people use when testing by hand, if that differs from what they use day to day.

## Asked on a conflict

When two sources disagree, ask which one is right and show both. Example: "`README.md:40` says the app listens on 8080, `application.yml:3` sets 8200. Which does a local run use?"

## Asked after the offline proof

Each address the offline proof found unreachable that is not a stack service is a new external service or another repo. Ask the always-asked questions for it.
