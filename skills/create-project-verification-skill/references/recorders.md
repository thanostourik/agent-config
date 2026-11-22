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

The prompt names your area and your plan brief `<skill>/.cache/brief/<area>.plan.md`. Read
that file first: it already holds these instructions, your area's entry points, own actions,
numbered expectations (`E1..En`), and a deterministic code inventory of its primary and
shared files with line and branch counts. You only read source and write the map below.
Start no app, browser or drive of a feature: the environment may not exist yet.

1. Read `<skill>/.cache/brief/<area>.plan.md`. Inspect source files only where the inventory
   signatures are not enough to group functions or decide what belongs to your area in a
   shared file (read only the linked line ranges of shared files, batched in one turn).
2. Write ONE structured feature map to `<skill>/.cache/plan/<area>.map.txt`. Do not write
   prose behavior lists, and do not split features into recorder groups (`bin/brief` packs
   groups deterministically by shared files and weight).
   - Group entry points, primary functions, linked shared-file functions, own actions and
     expectations into features by user goal, aiming for **15 to 30 weight**
     (`branches + 2 * expectations`) per feature (roughly 8 to 15 steps).
   - Name features `<area>-<goal>`. No name equals another or starts another followed by
     `-` (`verify lint` refuses that). When the prompt names a recipe that is already
     written or being written for this area, keep its name for that feature.
   - Use this exact format:

     ```
     feature <area>-<goal>
     covers: <comma-separated entry points, or none>
     functions: <file>: <func1>, <func2>; <other_file>: <func3>
     expectations: E1, E2, E5
     notes: <optional 1-line scope note: dispatcher branch, shared-file boundary, or # alone/# shares hint>

     ignored: <file>: <func> (<reason: internal helper | other area | dead code>)
     ```

   - Rules:
     - Every entry point of the area goes in `covers:` of at least one feature.
     - Every expectation `E#` goes in `expectations:` of **exactly one** feature.
     - Every non-trivial function of a primary file goes in `functions:` of a feature OR in
       `ignored:` with a short reason.
     - A dispatcher function (such as `cli.py: main` or `server.py: do_POST`) may be cited
       by each feature that exercises one of its branches, with `notes:` naming that branch.
     - In a shared file (listed by other areas too), cite only the functions behind your
       area's work (what your area triggers, saves, syncs or displays there), with `notes:`
       saying what your area owns. Leave other screens' actions to their areas.
3. Run `<skill>/bin/brief <area>` (needs no environment). It checks every entry point,
   expectation `E#`, own action, primary function, symbol resolution and feature name
   prefix. Fix every reported issue in `<skill>/.cache/plan/<area>.map.txt` and run
   `<skill>/bin/brief <area>` again until it reports complete and exits 0.
4. As your last action, write `<skill>/.cache/results/<area>.plan.txt`, through a temporary
   file and `mv`: one line per feature (`<feature>: <covers or none>; expectations: <E#s>`).
   Then return the same lines.

## Record a group

The prompt names two files, which you read in one turn: `<skill>/.cache/brief/common.md`
and your brief `<skill>/.cache/brief/<area>.<n>.md`. The first holds this file, the Recipes
and When a drive fails sections of `<skill>/SKILL.md`, `<skill>/PROJECT.md`, the example
recipe and the source of the project's helpers. The second holds your group's feature map,
their `# covers:` and `# touches:` hints, full assigned expectation lines, the complete
source of every assigned function (with decorators), referenced constants and schemas, and
the bodies of cited tests. Every turn you take sends your whole context again, so batch
reads, writes and drives. The features of your group are yours; other recorders work on the
rest of the area at the same time, sharing what they learn in `<skill>/.cache/traps.txt`.

1. Read nothing those two files hold a second time: no helper, no cited function, no cited
   test, not the example. Read `<skill>/.cache/traps.txt` when it exists, and extra source
   only if the brief lists an omitted/unfound citation or a needed helper function, every
   range in one call.
2. Look at the real app only where needed. If `<skill>/.cache/snapshots/<area>/` already
   has snapshots for your screens, read them instead of opening a browser probe. Otherwise
   open each screen your features use once in a browser session of your own
   (`VERIFY_SESSION=<area>-<n>-probe`), save its snapshots under
   `<skill>/.cache/snapshots/<area>/`, and close the probe session. On Android, the run has
   one shared emulator (and when phone recipes use `# needs: phone`, `verify up` has not
   started it), so do not probe the emulator by hand while other phone drives run: write
   your recipes from the source and existing snapshots first, then read any needed hierarchy
   or screenshot from the drive's evidence (or run `bin/maestro.sh hierarchy` only when no
   other phone drive is running and the phone side is up). Call the API once with the
   project's API helper for any response shape not clear from the brief.
3. Write **all** recipes of your group, `<skill>/features/<feature>.sh`, in **one turn**
   (parallel Write calls) before driving any of them.
   - Every assigned expectation `E#` gets at least one `# expects:` line citing it verbatim
     (splitting a multi-case test into one line per case, each citing that test).
   - Go through every function your brief shows, branch by branch, and give every reachable
     refusal, limit, state, default and side effect its own `# expects:` line and step,
     citing `<file>: <function>`. Never merge two behaviors into one line, and never write
     two lines for one behavior (when a test and a function state the same behavior, write
     one line citing both joined with `; `).
   - Respect `notes:` for dispatcher branches and shared files; add nothing that belongs to
     another feature or another area. A recipe that already exists (such as the example) is
     completed, not rewritten from scratch.
   - Keep recipes fast (under 45 s) and parallel-safe: never write a loop of hundreds of
     live requests just to hit an in-memory cache eviction cap or fill a huge fixed limit
     (if no env setting lowers a cap of hundreds, mark that cap not driven), and mark a
     feature `# alone` only when it genuinely restarts or breaks a shared service for
     other features.
4. Drive all your features together once: `<skill>/bin/verify <feature> <feature> ...`.
   Fix all failing recipes together in one turn (parallel Edit calls) rather than one at a
   time. After that, drive only the recipes you edited, together in one call, until each
   passes. A failing feature's line comes with the end of its log and evidence excerpts:
   open a log or evidence file only when that is not enough. When a pass is marked slow,
   check `pw-calls.log` or `maestro-calls.log` or step times once, remove what is plainly
   avoidable, and spend no further runs on speed.
5. Run `<skill>/bin/finish <feature> <feature> ...` with all your features. Run no lint and
   no `verify uncovered` of your own before it: in one call it lints them, flags invalid
   not-driven reasons, drives them once together with up to three other passed features,
   and prints what `verify uncovered <area>` still lists. Then:
   - Fix any lint error, invalid not-driven reason, or failed feature of yours. Check only
     data your recipe created and size waits for `verify all` load.
   - Cover each uncovered entry point, action and expectation line that belongs to your
     group's features with a step (or a valid not-driven reason). Leave items belonging to
     other groups or other areas.
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

The prompt names a slim repair brief `<skill>/.cache/brief/<id>.md` and the failing
features, uncovered items or not-driven lines to repair. Read that single file first: it
already holds these instructions, `When a drive fails`, the relevant sections of
`PROJECT.md`, `.cache/traps.txt`, each recipe, its last failure log, its evidence excerpts,
and the source of the failing step. Do not re-read files it already shows, and do not
record the area again.

1. Fix each failing feature the prompt names. Classify the failure as "When a drive fails"
   says. Then fix the recipe with small targeted edits, or mark a product defect as the
   Rules below say.
2. Give each not-driven line and each uncovered item the prompt names a step. A screen or
   route that has no recipe at all gets a recipe of its own: do steps 2 and 3 of "Record a
   group" for it.
3. Drive all edited recipes together in one `bin/verify <feature>...` call until each
   passes, then run `<skill>/bin/finish <feature>...` once.
4. As your last action, write your result to the result path your prompt names
   (`<skill>/.cache/results/<id>.txt`) through a temporary file and `mv`, then return the
   same lines.

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
- Apart from such a helper or stub fix, edit only your own recipes. Make no git branch,
  commit or stash, and no edit to `PROJECT.md`.
- Name data you make by hand while exploring `verify-<area>-probe-...`, and delete it by
  that prefix only.
- Name a browser session you open by hand `VERIFY_SESSION=<area>-<n>-probe`. Recorders that
  all named theirs `probe` closed each other's browsers.
- Close every browser session and stop every process you open by hand as soon as you are
  done with it. An open one holds memory the other drives wait for. Also stop every process
  your attempts started.
