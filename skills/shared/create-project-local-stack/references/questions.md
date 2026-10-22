# Questions

Which questions to ask and how. Ask about every fact the code cannot show, and about every choice where more than one option would work (see "Ask, never guess" in `SKILL.md`). Skip a question when the fact file already answers it.

## How to ask

- One decision per question. The same decision for several services may be one multi-select question.
- Show the evidence: what you found and where, such as "`config/services.php:12` sends mail through `smtp.example.com`".
- Give the options, put your recommendation first and say why. Say what each answer changes in the stack.
- Send the questions in rounds, as many at once as your question tool allows, the most important first. A later round may depend on an earlier answer.
- Write each question so the user understands it on the first read, without knowing this skill's words: say "fake", not "stub", and never use "shared", "mode" or "switch" without saying what they mean there. Name the service the way the code or docs name it, and give a concrete example of what the answer changes. Reread it as the user before sending; if it needs a second read, rewrite it.
- When the user answers with a question, or says they don't understand, answer that first. Explain in plain words what the question is about, why it matters, and what each option would do, with an example. Then ask the same decision again. Never replace it with a different question, never move on, and never act as if it were answered.
- If a question you asked turns out to be unnecessary, tell the user why before going on.

## Always asked

About the app:

1. What one action proves the app works end to end, and what result shows it worked? Propose one from the code, such as an HTTP call and its response, a command and its output, or a message and the row it writes. The proof in step 6 runs this action.
2. Does anyone run the app on their own machine, from an IDE or a terminal? If no, the stack only ever runs it in a container.

For each outside service:

3. Do other people use this same service, such as colleagues on a shared test server, or customers? If yes, an agent's test requests would reach them, so agents get a fake by default.
   Example: "The app sends order emails through `smtp.example.com` (`config/mail.php:12`). Do your colleagues use that same server? If yes, agents' test emails would reach real inboxes."
4. Does calling it cost money, send mail or messages, change data that others see, or count against a limit? If yes, agents get a fake by default.
5. When you start the stack yourself to try something by hand, should the app talk to the real service or to a fake one that the stack runs on your machine?
6. To prove the real connection works, may I send it one test request now? Say what that request would be.

For each address that may belong to another repo of this project:

7. Is it another repo of this project? If so, where is its checkout on this machine? Propose the name of the environment variable that will hold that path.
8. When this stack starts, should it also start that repo's own local stack, so the app talks to the real thing, or run a small fake of it instead, or offer both? Which one by default?

## Asked when the code does not settle it

- How the app runs locally, when the build files define several ways or none.
- Which configuration profile or environment a local run uses.
- Whether something the app talks to runs in the stack or outside it.
- Where the starting data comes from: migrations alone, a seed script, a dump, or records the stack creates.
- How an account, tenant or API key comes to exist, and which roles a developer needs to try the app.
- Where a developer gets each secret that a `real` mode needs.
- How the app should read the stack file on the host, when more than one way fits (`stack-spec.md`, "The app's configuration").
- Whether a client on another device, such as a phone, must reach the stack, when the code shows such a client.

## Asked on a conflict

When two sources disagree, ask which one is right and show both. Example: "`README.md:40` says the app listens on 8080, `config/app.yaml:3` sets 8200. Which does a local run use?"

## Asked after the offline proof

Each address the offline proof found unreachable that is not a stack service is a new outside service or another repo. Ask the questions for it.
