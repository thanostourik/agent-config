# Recorder

You record end-to-end recipes for one area of this project. The short prompt that started
you names the repository root, the example recipe and your area. Run every command from the
repository root, and read nothing outside it except the generator's files it names: another
checkout's recipes are not this project's. Below, `<skill>` is the folder that holds this
file, such as `.agents/skills/verify-shop`.

## Steps

1. Read `<skill>/SKILL.md` (sections Recipes and When a drive fails), `<skill>/PROJECT.md`,
   the example recipe, and your area's expectation list `<skill>/.cache/expect/<area>.txt`.
   Your area's line in `<skill>/.cache/areas.txt` lists its files.
2. Read every file of your area. Write its behaviors, one per line as the Recipes section
   lists them, to `<skill>/.cache/behaviors/<area>.txt`.
3. Split that list into features of 8 to 15 steps by user goal, one behavior per step where
   it can be driven on its own, named `<area>-<goal>`. A recipe of your area that already
   exists is one of them.
4. Look at the real app. Open each screen of your area once in a browser session of your own
   (`VERIFY_SESSION=<area>-probe`), signed in as the role that uses it, and save its
   snapshots under `<skill>/.cache/snapshots/<area>/`. Call the API once (`bin/api.sh` or
   the project's API helper) for each record a step will check.
5. Write all your recipes, `<skill>/features/<feature>.sh`, with one `# expects:` line per
   behavior line, before driving any.
6. Drive them together once: `<skill>/bin/verify <feature> <feature> ...`. Fix the failing
   ones together, with small edits rather than rewriting a recipe. After that, drive only
   the recipes you edited, together, until each passes: driving the whole area after each
   edit fills the machine's queue. When a pass is marked slow, read the slowest calls in
   `pw-calls.log` next to the feature's log, or its step times, once, and remove what is
   plainly avoidable; spend no further runs on speed.
7. Run `<skill>/bin/verify uncovered <area>`. It lists your area's entry points, actions and
   expectation lines no recipe covers. Cover each with a step, or an `# expects:` line
   marked not driven with its reason, until it lists none.
8. Run your features once together with three others that already have a result file in
   `<skill>/.cache/results/` (all of them when fewer exist):
   `<skill>/bin/verify <yours> <others>`. Check only data your recipe created. This pass is
   not acceptance: after you return, `verify all` runs every feature at once, and a recipe
   that fails there comes back to you. Size every wait for that load.
9. As your last action, write your result to `<skill>/.cache/results/<area>.txt`, through a
   temporary file and `mv`, then return the same lines: one line per feature (`passed`,
   `product defect: <what>`, or `blocked: <reason>`), and one line per trap that cost you a
   run, for `PROJECT.md`'s Gotchas.

## Rules

- The environment is already up and shared. Never run `verify up`, `down` or `all`,
  `launch.sh`, `cleanup.sh`, or anything that stops containers or closes browser sessions
  other than your own feature's. Never restart or reconfigure a shared service by hand, even
  to explore: only a recipe marked `# alone` does that, through `bin/verify`, which keeps
  other drives off the copy meanwhile.
- While iterating, drive only your own features. Run each drive in the foreground and read
  its summary; never end your turn while a drive runs.
- Stop a feature after 5 runs, and report it blocked with its last summary line.
- A product defect: add `# known failure: <step label>` to the recipe's header. Never weaken
  or drop a check to get past it: checking only the response when the stored result is
  wrong hides the defect. Keep the check, last in its step.
- A defect in a helper: fix it when the fix is small and cannot break other features, by
  writing a copy and moving it over the helper with `mv` (other drives are running it, and
  bash reads a script while it runs), and name it in your result. Otherwise report
  `blocked: helper <name>: <defect>`.
- Edit only your own recipes: no git branch, commit or stash, and no edit to `PROJECT.md`.
- Data you make by hand while exploring is named `verify-<area>-probe-...`, and you delete it
  by that prefix only. A browser session you open by hand is `VERIFY_SESSION=<area>-probe`,
  because recorders that all named theirs `probe` closed each other's browsers.
- Close every browser session and stop every process you open by hand as soon as you are
  done with it: an open one holds memory the other drives wait for. Stop every process your
  attempts started.
