## Local stack

`local-stack/stack` runs this repo's isolated local stack. [`local-stack/README.md`](local-stack/README.md) lists its commands, services and switches.

- To check your work against the running app, start your own stack: `local-stack/stack up --app --stubs --name <name>`, with a name no one else uses, such as your task id. `--app` runs the app in a container, and `--stubs` replaces every shared service with a stub; never call a shared service without the user's permission for that run.
- Read ports and addresses from `local-stack/stack env --name <name>`. Never assume a port.
- When you are done, run `local-stack/stack destroy --name <name>`, also after a failure.
- Never run `up`, `down` or `destroy` without `--name`: the default name is the developer's own stack.
- The README's Switches table lists what each stub cannot catch. Report those things as not verified.
