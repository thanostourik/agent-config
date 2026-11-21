# Planner and recorder

You work on the end-to-end recipes of this project. The short prompt that started you names
the repository root and your job: plan an area, record a group of features, or repair
features. Run every command from the repository root. Read nothing outside it: another
checkout's recipes are not this project's. The one exception is a companion repo, where the
app's source is in the app checkouts (`$APP_<NAME>` when it is set, else the clone of each
repo in `<skill>/apps` next to this repo's main clone). Below, `<skill>` is the folder that
holds this file, such as `.agents/skills/verify-shop`.

Write every file with your file-writing tool, never with `cat` in the shell. A `cat` that
gets no input waits until the shell tool gives up, five minutes later.

## Plan an area

The prompt names your area. Its line in `<skill>/.cache/areas.txt` lists its entry points
and files. You split the area into features, and recorders then record them, a few
features each and all at once. You only read source and write the files named below. Start
no app, browser or drive of a feature: the environment may not exist yet.

1. Read the Recipes section of `<skill>/SKILL.md` and your area's expectation list
   `<skill>/.cache/expect/<area>.txt`.
2. Read every file of your area in full. Write its behaviors, one per line as the Recipes
   section lists them, each with its source, to `<skill>/.cache/behaviors/<area>.txt`.
   - Never merge two into one line: each refusal, each limit on each side, each error
     message and each default is a line of its own, so "a missing table, a bad flag or an
     empty name is refused" is three lines. The recorders check what you list, and a
     behavior you leave out is likely never checked.
   - Never write one behavior twice. When a line of the expectation list and the source
     state the same behavior, write one line that cites both, joined with `; `:
     `(<test file>: <test name>; <file>: <function>)`.
   - A file another area lists too holds both areas' behaviors. Take from it what your
     area's work shows or causes there, such as the message a user sees when a save of
     yours fails. Leave the actions of other screens to their areas: a behavior two areas
     list is recorded twice. When another area's line lists the same file, take only the
   behaviors behind your own entry points.
   Then run `<skill>/bin/brief <area>`, which needs no environment. It lists each
   expectation line, entry point and action of the area that your file does not cite.
   Add a behavior line for each, citing an expectation line by its file and name as the
   Recipes section says, and run it again until it lists none. It leaves out the actions
   in files another area lists too. A behavior left out here is found only after the recorders return, and then
   costs a second round of recording.
3. Split that list into features by user goal, each 8 to 15 steps, with one behavior per
   step where it can be driven on its own. Name them `<area>-<goal>`. No name equals
   another or starts with another followed by `-`: `verify lint` refuses that. When the prompt names
   a recipe that is already being written for this area, keep its name for the feature
   that holds its behaviors.
4. Put the features into groups of at most 3 that share screens or setup. Write each group
   to `<skill>/.cache/plan/<area>.<n>.txt` (`n` from 1), one line per feature:
   `<feature>: <the line numbers of its behaviors in your behaviors file>; files: <the
   files of your area those behaviors live in>`. Every behavior line is in exactly one
   feature. `bin/brief` copies the function each behavior line cites into the recorder's
   first reading, so cite on every line the file and the function that produces the
   behavior, by its name in the code: `(<file>: <function>)`.
5. As your last action, write `<skill>/.cache/results/<area>.plan.txt`, through a
   temporary file and `mv`: one line per group file, with its features. Then return the
   same lines.

## Record a group

The prompt names two files, which you read in one turn: `<skill>/.cache/brief/common.md`
and your brief `<skill>/.cache/brief/<area>.<n>.md`. The first holds this file, the
Recipes and When a drive fails sections of `<skill>/SKILL.md`, `<skill>/PROJECT.md`, the
example recipe and the source of the project's helpers. The second holds your group file
`<skill>/.cache/plan/<area>.<n>.txt`, your behavior lines, the functions those lines cite
and the bodies of the tests they cite. Every turn you take sends your whole context again,
so each file you open and each command you run alone costs its share of the whole. The features of your group are yours.
The other features of the area belong to other recorders, who work at the same time. You
share what you learn with them through `<skill>/.cache/traps.txt`, as the Rules say.

1. Read nothing those two files hold a second time: no helper, no cited function, no
   cited test, not the example. Read `<skill>/.cache/traps.txt` when it exists, and more
   source only where a behavior needs a function the brief does not show, every range you
   need in one call.
2. Look at the real app. Open each screen your features use once in a browser session of
   your own (`VERIFY_SESSION=<area>-<n>-probe`), signed in as the role that uses it. Save
   its snapshots under `<skill>/.cache/snapshots/<area>/`. Call the API once, with the
   project's API helper, for each record a step will check.
3. Write all your recipes, `<skill>/features/<feature>.sh`, with one `# expects:` line per
   behavior line of the feature, before driving any. The plan is the least you cover. It
   was written in one reading, so it misses and merges behaviors, and a plan differs from
   run to run. The code does not: go through each function your brief shows, branch by
   branch, and give every refusal, limit, state and side effect some input can reach an
   `# expects:` line and a step, whether the plan lists it or not. Split each plan line
   that holds several. Add nothing that belongs to another feature or another area. A recipe of yours that
   already exists, such as the example, is completed, not written again.
4. Drive them together once: `<skill>/bin/verify <feature> <feature> ...`. Fix the failing
   ones together, with small edits rather than rewriting a recipe. After that, drive only
   the recipes you edited, together, until each passes. A failing feature's line comes with
   the end of its log and the names of its evidence files: open a file only when that is
   not enough. When a pass is marked slow, read the slowest calls in `pw-calls.log` next to
   the feature's log, or its step times, once. Remove what is plainly avoidable, and spend
   no further runs on speed.
5. Run `<skill>/bin/finish <feature> <feature> ...` with your features. Run no lint and
   no `verify uncovered` of your own before it: in one call it lints them, drives them once together with three features other recorders have reported
   passed, and prints what `verify uncovered <area>` still lists. Then:
   - Fix a feature of yours that fails there. Check only data your recipe created. This
     drive is not acceptance: in Full mode and while the skill is generated, `verify all`
     runs every feature at once after you return, and a recipe that fails there comes back
     to you. Size every wait for that load.
   - Cover each uncovered entry point, action and expectation line that sits behind your
     behaviors with a step, or with an `# expects:` line marked not driven for a reason the
     Recipes section allows. Leave the others: they belong to the area's other groups, or
     to another area whose line lists the same file.
   - Check each not-driven reason in your recipes against the Header rules of the Recipes
     section, and give each line whose reason does not hold a step.
   - Run `bin/finish` again after such a change, three times at most.
6. As your last action, write your result to `<skill>/.cache/results/<area>.<n>.txt`,
   through a temporary file and `mv`. Then return the same lines:
   - one line per feature: `passed`, `product defect: <what>`, or `blocked: <reason>`;
   - one line per trap that cost you a run, for `PROJECT.md`'s Gotchas;
   - one line per branch no input can reach: `dead code: <file>: <function>: <what reaches
     first>`;
   - one line per timer a behavior waits on that `PROJECT.md`'s Timers section does not
     list: `timer: <name> (<file>): <what it delays>`. Its behaviors get no line until the
     user decides.

## Repair features

The prompt names failing features, uncovered items or not-driven lines, in recipes that
already exist. Do not record them again. Do step 1 of "Record a group" for those features,
then:

1. Fix each failing feature the prompt names. Read its summary line, and its log when the
   line is not enough. Classify the failure as "When a drive fails" says. Then fix the
   recipe, or mark a product defect as the Rules below say.
2. Give each not-driven line and each uncovered item the prompt names a step. A screen or
   route that has no recipe at all gets a recipe of its own: list its behaviors in the
   area's behaviors file, then do steps 2 and 3 of "Record a group" for it.
3. Go on from step 4 of "Record a group", and drive only the recipes you edited.

## Rules

- Share traps at once. When something costs you a failed drive or a failed command, and
  would cost another recorder the same, append one line to `<skill>/.cache/traps.txt`, in
  front of your next command and in the same call, with
  `echo '<what happens>: <what to do>' >> <skill>/.cache/traps.txt`: a helper's
  quirk, how the app refuses something, a wait that is needed. Add a line for each helper
  you write too: `helper bin/<name>: <one real call and what it returns>`. Read the file
  again before you repair a failing drive and before you write a helper: another recorder
  may already have the answer or the helper. Never write over a helper you did not write:
  give yours another name.
- Before you mark a line not driven because a helper, stub or fixture cannot do what a
  step needs, append `need: <what the step needs>` to the traps file and read the file
  again. Another recorder may have it or be building it. When none has, build it: missing
  tooling of the project is never a reason, as the Recipes section says.
- Announce a helper before you build it: append `building bin/<name>: <what it will do>`
  to the traps file first. When the file already announces a helper for the same job,
  build none of your own. Do your other work, read the file again, and use that helper once
  its `helper bin/<name>:` line is there.
- A command you typed by hand that stops at its time limit means something hangs. Find
  out what before you run it again, and put no further command behind one that can hang:
  three commands of 60 s in one call cost three minutes.

- The environment is already up and shared. Never run `verify up`, `down` or `all`,
  `launch.sh`, `cleanup.sh`, or anything that stops containers or closes browser sessions
  other than your own feature's.
- Never restart or reconfigure a shared service by hand, even to explore. Only a recipe
  marked `# alone` does that, through `bin/verify`, which keeps other drives off the copy
  meanwhile.
- While iterating, drive only your own features. Run each drive in the foreground and read
  its summary. Never end your turn while a drive runs.
- Stop a feature after 5 runs, and report it blocked with its last summary line.
- Run every command you type by hand under `timeout 60`, except `bin/verify` and `pw.sh`,
  which stop themselves: a probe, a helper, a script. A command that never returns
  otherwise costs five minutes. When your shell tool takes a time limit of its own, also
  give every call that runs no drive 2 minutes: a command that waits for input, such as a
  `cat` with no file, is not stopped by the `timeout` in front of another command.
- For a product defect, add `# known failure: <step label>` to the recipe's header. Never
  weaken or drop a check to get past it: checking only the response when the stored result
  is wrong hides the defect. Keep the check, last in its step.
- A helper can have a defect, or a helper or stub cannot yet return the data or the failure
  a step needs. Fix it when the fix is small and cannot break other features, and name it
  in your result. Write a copy and move it over the helper with `mv`: other drives are
  running the helper, and bash reads a script while it runs. Otherwise report
  `blocked: helper <name>: <defect>`.
- Apart from such a helper or stub fix, edit only your own recipes. Make no git branch, commit or
  stash, and no edit to `PROJECT.md`.
- Name data you make by hand while exploring `verify-<area>-probe-...`, and delete it by
  that prefix only.
- Name a browser session you open by hand `VERIFY_SESSION=<area>-<n>-probe`. Recorders that
  all named theirs `probe` closed each other's browsers.
- Close every browser session and stop every process you open by hand as soon as you are
  done with it. An open one holds memory the other drives wait for. Also stop every process
  your attempts started.
