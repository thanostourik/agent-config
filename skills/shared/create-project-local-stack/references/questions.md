# Questions

The stack depends on facts that the code cannot show. This file says which questions to ask and how. Ask every question that applies. Skip one only when the fact file already holds its answer with a source.

## How to ask

- One decision per question. The same decision for several services may be one multi-select question.
- Show the evidence: what you found and where, such as "`application-dev.yml:17` sends chat requests to `https://chatbot.example.com`".
- Give the options, put your recommendation first and say why. Say what each answer changes in the stack.
- Send the questions in rounds, as many at once as your question tool allows, the most important first. A later round may depend on an earlier answer.
- Write each question so the user understands it on the first read, without knowing this skill's words. Never use "shared", "mode", "stub", "switch" or "real mode" without saying what they mean in that question. Name the service the way the code or docs name it, and give a concrete example of what the answer changes.
- When the user answers with a question, or says they don't understand, answer that first. Explain in plain words what the question is about, why it matters, and what each option would do, with an example. Then ask the same decision again. Never replace it with a different question, never move on, and never act as if it were answered.
- If a question you asked turns out to be unnecessary, tell the user why before going on.
- Before sending, reread each question as the user: if it uses a word from this skill without saying what it means, or needs a second read, rewrite it.

## Always asked

For each external service:

1. Do other people use this same service, such as colleagues on a shared test server, or customers? If yes, an agent's test requests would reach them, so agents get a fake by default.
   Example: "The app sends chat questions to `chatbot.example.com` (`application.yml:17`). Do your colleagues use that same server? If yes, agents' test questions would show up there."
2. Does calling it cost money, send mail or messages, change data that others see, or count against a limit?
3. When you start the stack yourself to try something by hand, should the app talk to the real service or to a fake one that the stack runs on your machine?
4. To prove the real connection works, may I send it one test request now? Say what that request would be.

For each address that may belong to another repo of this project:

5. Is it another repo of this project? If so, where is its checkout on this machine? Propose the name of the environment variable that will hold that path.
6. When this stack starts, should it also start that repo's own local stack, so the app talks to the real thing, or run a small fake of it instead, or offer both? Which one by default?

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
