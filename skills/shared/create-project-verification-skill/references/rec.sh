#!/usr/bin/env bash
# rec.sh <feature> start: stage features/<feature>.md, or a skeleton for a new feature, as .cache/record/<feature>/<feature>.md and print that path; write the whole feature file there; it resets .cache/record/<feature>/reached.tsv. An installed feature keeps its attempts count.
# rec.sh <feature> run [--known-failure '<Label>']: check the staged file as drive.sh --check does, contract coverage included, refuse it while a step's current block has no line in reached.tsv, print attempt <n> of <feature>, counting runs since start that passed those checks, move the last run's step logs and .cache/evidence/<feature>/ to .cache/record/<feature>/previous/, then run its Driving section the way drive.sh runs an installed one; the flag lets the last step before Clean up fail. A failure ends with the failing step, its snapshot and its log, and adds a line to .cache/record/failures.txt; with bin/observe.sh, that snapshot is a fresh one of the state the failing step left, taken before Clean up as .cache/record/<feature>/failure.txt. Everything it prints also lands in .cache/record/<feature>/result.txt when it ends; .cache/record/<feature>/running holds its pid until then.
# rec.sh <feature> result: wait while a run of <feature> is going, then print its result.txt; a run whose process died first prints killed before it finished.
# rec.sh <feature> peek [--after '<Label>']... [--find '<expression>']...: run the staged file's Preconditions and the steps through the last <Label> as run does, save one snapshot with bin/observe.sh after Preconditions or after each <Label> to .cache/record/<feature>/peek.txt, peek-<n>.txt for the n-th of several flags, then evaluate each expression with bin/find.sh on the last state reached and print its match count and up to 3 matches, then run Clean up; a failing step stops the steps and its state goes to the next snapshot file. Each step it ran, failed ones and Clean up included, gets a line of its label and block hash in .cache/record/<feature>/reached.tsv.
# rec.sh <feature> facts: print .cache/record/<feature>/facts.tsv: attempts, passed_hash, last_result, last_log, last_snapshot and the verify- and Verify fixture names of the staged file; without one, attempts 0 and the other keys empty.
# rec.sh <feature> index '<index line>': replace the line linking ./<feature>.md in the ## Features list of features/README.md, or add it after the line of its parent, the listed feature whose name followed by - starts <feature>, the longest one, else at the end of that list.
# rec.sh affected: list in .cache/changed.txt the files changed since the commit in features/last-reviewed, write each matching ## Change triggers line's features with the file to .cache/triggered.tsv, and print and save to .cache/affected.txt the indexed features those files or a kept staged copy touch, how many were skipped and each unmapped change; with no such commit, say to record every feature.
# rec.sh common: write .cache/record/brief-common.md from features/README.md, the Helpers section of SKILL.md, the first steps of the shortest accepted recipe of at least five steps and .cache/record/main-screen.txt, cut to stay under 20,000 bytes, and print its size.
# rec.sh brief [<feature>...]: write .cache/record/contract-map.tsv from contract-words.tsv and the files listed in contract-sources.txt when it is missing, then each feature's contract.md, changes.diff and brief.md, the ### Recorder template of maintain-verify-<app>/SKILL.md filled from the index, mode.txt and convert.txt.
# rec.sh fix-brief <feature>...: write each feature's fix-read.md and fix-brief.md, the ### Fixer template filled from its failure in the summary of .cache/drive.txt.
# rec.sh sendback: print each feature whose report says no drift while its facts show no run.
# rec.sh reviewed '<message>': write the last commit outside features/last-reviewed to that file and commit it alone with that message, only when it changes.
# rec.sh install [<feature>...]: give a staged file with no ## Gotchas section one, holding each Gotchas line of the installed file that neither the staged file nor features/README.md Gotchas holds, move staged files that passed run into features/, check them with drive.sh --check and keep only facts.tsv of their record folders.
set -uo pipefail
shopt -s nullglob

fail_tail=60

skill=$(cd "$(dirname "$0")/.." && pwd)
cd "$skill/../../.."
source "$skill/bin/steps.sh"

usage_all="usage: rec.sh <feature> start
       rec.sh <feature> run [--known-failure '<Label>']
       rec.sh <feature> result
       rec.sh <feature> peek [--after '<Label>']... [--find '<expression>']...
       rec.sh <feature> facts
       rec.sh <feature> index '<index line>'
       rec.sh affected
       rec.sh common
       rec.sh brief [<feature>...]
       rec.sh fix-brief <feature>...
       rec.sh sendback
       rec.sh reviewed '<message>'
       rec.sh install [<feature>...]"
fail() { echo "rec.sh: $*" >&2; exit 1; }
usage() { echo "$usage_all" >&2; exit 2; }
check_feature() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "a feature is the feature file name without .md"; }
relative() { echo "${1#"$PWD/"}"; }

steps_hash() {
  local number label
  while IFS=$'\t' read -r number label; do
    echo "$label"
    [[ ! -f "$1/$number.sh" ]] || { cat "$1/$number.sh"; echo '```'; }
  done < "$1/steps" | sha256sum | cut -d' ' -f1
}

recipe_hash() {
  local dir
  dir=$(mktemp -d)
  : > "$dir/steps"
  split_steps "$1" "$dir"
  steps_hash "$dir"
  rm -rf "$dir"
}

blank_facts() { printf '%s\t\n' attempts passed_hash last_result last_log last_snapshot names | sed '1s/$/0/'; }

set_facts() {
  local file="$rec/facts.tsv"
  [[ -f "$file" ]] || blank_facts > "$file"
  awk -F '\t' -v OFS='\t' 'BEGIN { for (i = 2; i < ARGC; i += 2) value[ARGV[i]] = ARGV[i + 1]; ARGC = 2 } $1 in value { $0 = $1 OFS value[$1] } { print }' "$file" "$@" > "$file.new"
  mv "$file.new" "$file"
}

fact() { awk -F '\t' -v k="$1" '$1 == k { print $2 }' "$rec/facts.tsv" 2>/dev/null; }

staged_names() { fixture_names "$1" | awk 'NR > 1 { printf ", " } { printf "%s", $0 }'; }

lost_gotchas() {
  local readme="$skill/features/README.md"
  [[ -f "$skill/features/$1.md" ]] || return 0
  [[ -f "$readme" ]] || readme=/dev/null
  awk '
    FNR == 1 { gotchas = 0 }
    { sub(/[[:space:]]+$/, "") }
    /^## / { gotchas = $0 == "## Gotchas"; next }
    FILENAME == ARGV[1] { kept[$0]; next }
    !gotchas { next }
    FILENAME == ARGV[2] { kept[$0]; next }
    /[^[:space:]]/ && !($0 in kept)
  ' "$skill/.cache/record/$1/$1.md" "$readme" "$skill/features/$1.md"
}

not_ready() {
  local rec="$skill/.cache/record/$1"
  [[ -f "$rec/$1.md" ]] || { echo "$1 has no staged file; run rec.sh $1 start"; return; }
  [[ -f "$rec/passed" ]] || { echo "$1 has not passed rec.sh $1 run"; return; }
  [[ "$(head -n 1 "$rec/passed")" == "$(recipe_hash "$rec/$1.md")" ]] || echo "$1 changed since it passed; run it again"
}

carry_gotchas() {
  local staged="$skill/.cache/record/$1/$1.md" lost
  grep -q '^## Gotchas[[:space:]]*$' "$staged" && return 0
  lost=$(lost_gotchas "$1")
  [[ -n "$lost" ]] || return 0
  printf '\n## Gotchas\n\n%s\n' "$lost" >> "$staged"
  echo "rec.sh: carried $(wc -l <<< "$lost") gotcha lines into $1"
}

section() { awk -v h="## $1" '/^## /{p = $0 == h; next} p' "$2"; }

block() {
  local text
  text=$(sed '/[^[:space:]]/,$!d' <<< "$2")
  [[ -z "$text" ]] || printf '\n## %s\n\n%s\n' "$1" "$text"
}

template() { awk -v h="### $1" '$0 == h {s = 1; next} s && /^```/ {if (f) exit; f = 1; next} f' "$skill/../maintain-$(basename "$skill")/SKILL.md"; }

fill() { awk '{o = ""; while (match($0, /[{][{][a-z_]+[}][}]/)) {o = o substr($0, 1, RSTART - 1) ENVIRON[substr($0, RSTART + 2, RLENGTH - 4)]; $0 = substr($0, RSTART + RLENGTH)} print o $0}'; }

affected() {
  local v b
  set +u +o pipefail
  v=$(relative "$skill") b=$(cat "$v/features/last-reviewed")
  git cat-file -e "$b^{commit}" 2>/dev/null || { echo "no commit $b: record every feature"; return; }
  { git diff --name-only "$b"; git ls-files -o --exclude-standard; } | grep -v -e "^$v/features/last-reviewed$" -e "^$v/[.]cache/" | sort -u > "$v/.cache/changed.txt"
  awk -v b="$b" -v d="$v/features/" -v p="$v/.cache/triggered.tsv" -v kept="$(printf '%s\n' "$v"/.cache/record/*/*.md)" '
    BEGIN { printf "" > p }
    FNR == 1 { n++ }
    n == 1 && /^## / { t = /^## Change triggers$/; x = /^## Features$/ }
    n == 1 && t && match($0, /: [a-z0-9][a-z0-9, -]*$/) {
      f[++nt] = substr($0, RSTART + 2); r[nt] = "^$"; h = substr($0, 1, RSTART - 1)
      while (match(h, /`[^`]+`/)) {
        g = substr(h, RSTART + 1, RLENGTH - 2); h = substr(h, RSTART + RLENGTH)
        for (e = ""; g != ""; g = substr(g, 2)) { c = substr(g, 1, 1); e = e (c == "*" ? ".*" : c == "?" ? "." : c ~ /[\\^]/ ? "\\" c : "[" c "]") }
        r[nt] = r[nt] "|^" e "$"
      }
    }
    n == 1 && x && (i = index($0, "](./")) { s = substr($0, i + 4); all[substr(s, 1, index(s, ".md)") - 1)]; total++ }
    n == 2 && index($0, d) == 1 && /[.]md$/ && !/README.md$/ { hit[substr($0, length(d) + 1, length($0) - length(d) - 3)]; next }
    n == 2 && !/^[.](agents|claude)\// {
      m = 0
      for (i = 1; i <= nt; i++) if ($0 ~ r[i]) { m = split(f[i], a, /, */); for (j in a) { hit[a[j]]; print a[j] "\t" $0 > p } }
      if (!m) u = u "unmapped change: " $0 "\n"
    }
    END {
      split(kept, k, "\n")
      for (j in k) if ((z = split(k[j], q, "/")) > 1 && q[z] == q[z - 1] ".md") hit[q[z - 1]]
      for (s in all) if (s in hit) o = o " " s
      printf "affected:%s\nskipped: %d of %d features, unchanged since %s\n%s", o, total - split(o, a, " "), total, b, u
    }
  ' "$v/features/README.md" "$v/.cache/changed.txt" | tee "$v/.cache/affected.txt"
}

example_file() {
  local file feature dir best="" size least=""
  dir=$(mktemp -d)
  for file in "$skill"/features/*.md; do
    feature=$(basename "$file" .md)
    [[ "$feature" != README ]] || continue
    rm -f "$dir"/* && : > "$dir/steps"
    split_steps "$file" "$dir"
    (( $(cut -f2 "$dir/steps" | grep -c -v -x Preconditions) >= 5 )) || continue
    [[ -z "$(check_steps "$dir" "$file" "$feature" "$skill/.cache/record/contract-map.tsv")" ]] || continue
    size=$(wc -c < "$file")
    [[ -n "$least" ]] && ((size >= least)) || { best=$file least=$size; }
  done
  if [[ -z "$best" ]]; then
    for file in "$skill"/.cache/record/*/*.md; do
      feature=$(basename "$file" .md)
      [[ "$feature" == "$(basename "$(dirname "$file")")" && -z "$(not_ready "$feature")" ]] || continue
      rm -f "$dir"/* && : > "$dir/steps"
      split_steps "$file" "$dir"
      (( $(cut -f2 "$dir/steps" | grep -c -v -x Preconditions) >= 5 )) || continue
      size=$(wc -c < "$file")
      [[ -n "$least" ]] && ((size >= least)) || { best=$file least=$size; }
    done
  fi
  rm -rf "$dir"
  echo "$best"
}

recipe_start() { awk -v keep="$2" '/^## /{d = /^## Driving it with/; next} d && /^Preconditions:/ {p = 1} d && /^- \*\*/ && ++n > keep {exit} p' "$1"; }

common_file() {
  local v readme name
  v=$(relative "$skill") readme="$skill/features/README.md"
  echo "# Common brief for $(basename "$skill") recorders and fixers"
  printf '\n## From %s\n' "$v/features/README.md"
  for name in Baseline "Driving conventions" "Feature file shape"; do block "$name" "$(section "$name" "$readme")"; done
  block "Helpers, from $v/SKILL.md; call them by name, they are on PATH inside a run" "$(section Helpers "$skill/SKILL.md")"
  block "Example recipe, from this project" "$1"
  block "The app's main screen: the role-and-name lines of an accessibility snapshot taken after the baseline sign-in" "$2"
  block "Gotchas, from $v/features/README.md" "$(section Gotchas "$readme")"
}

common() {
  local out="$skill/.cache/record/brief-common.md" file example screen
  file=$(example_file)
  [[ -z "$file" ]] || example=$(recipe_start "$file" 2)
  screen=$(cat "$skill/.cache/record/main-screen.txt" 2>/dev/null)
  mkdir -p "$skill/.cache/record"
  common_file "${example:-}" "$screen" > "$out"
  if (($(wc -c < "$out") >= 20000)); then
    screen=$(grep -E '^[[:space:]]*- (heading|link|tab) ' <<< "$screen")
    common_file "${example:-}" "$screen" > "$out"
  fi
  if (($(wc -c < "$out") >= 20000)) && [[ -n "$file" ]]; then
    common_file "$(recipe_start "$file" 1)" "$screen" > "$out"
  fi
  wc -c "$(relative "$out")"
  (($(wc -c < "$out") < 20000)) || fail "$(relative "$out") is still 20,000 bytes or more"
}

brief() {
  local v r b c d h p sources
  v=$(relative "$skill") r=$(relative "$skill")/.cache/record
  if [[ ! -f $r/contract-map.tsv ]]; then
    [[ -f $r/contract-sources.txt ]] || fail "write $r/contract-sources.txt or $r/contract-map.tsv"
    mapfile -t sources < <(grep . "$r/contract-sources.txt")
    contract_map "$r/contract-words.tsv" "${sources[@]}" > "$r/contract-map.tsv"
  fi
  (($#)) || return 0
  set +u +o pipefail
  export root=$PWD feature index_line other_features new convert read_commands conventions_changed=none GIT_LITERAL_PATHSPECS=1
  b=$(cat "$v/features/last-reviewed" 2>/dev/null)
  test -f "$v/.cache/starting-README.md" && test "$(cat "$r/mode.txt")" = changed && conventions_changed=$(diff <(section "Driving conventions" "$v/.cache/starting-README.md") <(section "Driving conventions" "$v/features/README.md") | grep '^[<>]' || echo none)
  test "$(printf '%s\n' "$conventions_changed" | wc -l)" -gt 8 && conventions_changed='the Driving conventions were rewritten; follow the current ones in the common file'
  for feature in "$@"; do
    check_feature "$feature"
    index_line=$(awk -v f="$feature" '/^## /{p = /^## Features$/} p && index($0, "](./" f ".md)") {print; exit}' "$v/features/README.md")
    other_features=$(awk -v f="$feature" '/^## /{p = /^## Features$/} p && (i = index($0, "](./")) {n = substr($0, i + 4); n = substr(n, 1, index(n, ".md)") - 1); if (n != f) o = o (o == "" ? "" : ", ") n} END {print o}' "$v/features/README.md")
    new=$(test -f "$v/features/$feature.md" && echo no || echo yes)
    convert=$(grep -qsx "$feature" "$r/convert.txt" && echo yes || echo no)
    c=$r/$feature/contract.md d=$r/$feature/changes.diff h="   cat $r/brief-common.md $r/traps.md $r/failures.txt"
    mkdir -p "$r/$feature" && contract_bundle "$r/contract-words.tsv" "$r/contract-map.tsv" "$feature" "$v/features/$feature.md" > "$c"
    test -n "$index_line" && grep -q '^== ' "$c" || echo "$feature: no index line or no contract sections"
    rm -f "$d"
    if test "$(cat "$r/mode.txt")$new" = changedno && git cat-file -e "$b^{commit}" 2>/dev/null; then
      mapfile -t p < <(awk -F'\t' -v f="$feature" '$1 == f {print $2}' "$v/.cache/triggered.tsv"; echo "$v/features/$feature.md")
      { git diff "$b" -- "${p[@]}"; git ls-files -o --exclude-standard -- "${p[@]}" | while read -r u; do git diff --no-index -- /dev/null "$u"; done; } > "$d.full"
      head -c 19980 "$d.full" > "$d"; test "$(wc -c < "$d.full")" -le 19980 || printf '\n(truncated)\n' >> "$d"; rm "$d.full"; test -s "$d" || rm "$d"
    fi
    read_commands=$(test "$($h "$c" | wc -c)" -le 20000 && echo "$h $c" || { echo "$h"; for o in $(seq 1 20000 "$(wc -c < "$c")"); do echo "   tail -c +$o $c | head -c 20000"; done; }; test -f "$d" && echo "   cat $d")
    template Recorder | fill > "$r/$feature/brief.md"
  done
}

fix_brief() {
  local v r
  set +u +o pipefail
  v=$(relative "$skill") r=$(relative "$skill")/.cache/record
  export root=$PWD feature label log
  for feature in "$@"; do
    check_feature "$feature"
    IFS=$'\t' read -r label log < <(awk -v p="$feature: fail at \"" 'index($0, p) == 1 {s = substr($0, length(p) + 1); i = index(s, "\" ("); print substr(s, 1, i - 1) "\t" substr(s, i + 3, length(s) - i - 3)}' "$v/.cache/drive.txt")
    test -n "$log" || echo "$feature: no failure in the drive summary"
    mkdir -p "$r/$feature" && fix_read "$log" "$v/features/$feature.md" "$r/traps.md" "$v/SKILL.md" > "$r/$feature/fix-read.md" && template Fixer | fill > "$r/$feature/fix-brief.md"
  done
}

sendback() {
  local rec
  for rec in "$skill"/.cache/record/*/; do
    rec=${rec%/}
    [[ -f "$rec/changes.diff" ]] && grep -qis '^- Files:.*no drift' "$rec/report.md" || continue
    [[ -f "$rec/facts.tsv" && "$(fact attempts)" != 0 ]] || basename "$rec"
  done
}

reviewed() {
  local l c
  l=$(relative "$skill")/features/last-reviewed
  c=$(git log -1 --format=%H -- . ":(exclude)$l")
  [[ "$c" != "$(cat "$l" 2>/dev/null)" ]] || return 0
  echo "$c" > "$l" && git add "$l" && git commit -m "$1" -- "$l"
}

case "${1:-}" in
  affected | common | sendback) (($# == 1)) || usage; "$1"; exit ;;
  brief) shift; brief "$@"; exit 0 ;;
  fix-brief) shift; (($#)) || usage; fix_brief "$@"; exit 0 ;;
  reviewed) [[ $# == 2 && -n "$2" ]] || usage; reviewed "$2"; exit ;;
esac

if [[ "${1:-}" == install ]]; then
  shift
  features=()
  if (($#)); then
    for feature in "$@"; do
      check_feature "$feature"
      problem=$(not_ready "$feature")
      [[ -z "$problem" ]] || fail "$problem"
      features+=("$feature")
    done
  else
    for staged in "$skill"/.cache/record/*/*.md; do
      feature=$(basename "$staged" .md)
      [[ "$feature" == "$(basename "$(dirname "$staged")")" ]] || continue
      problem=$(not_ready "$feature")
      if [[ -n "$problem" ]]; then echo "rec.sh: skipped: $problem"; else features+=("$feature"); fi
    done
  fi
  ((${#features[@]})) || { echo "rec.sh: nothing to install"; exit 0; }
  mkdir -p "$skill/features"
  moved=() status=0
  for feature in "${features[@]}"; do
    target="$skill/features/$feature.md"
    if [[ ! -d "$target" ]] && carry_gotchas "$feature" && mv "$skill/.cache/record/$feature/$feature.md" "$target"; then
      moved+=("$feature")
    else
      echo "rec.sh: could not install $feature; its staged file is unchanged" >&2
      status=1
    fi
  done
  ((${#moved[@]})) || exit 1
  "$skill/bin/drive.sh" --check "${moved[@]}"; check=$?
  ((status)) || status=$check
  for feature in "${moved[@]}"; do
    rec="$skill/.cache/record/$feature"
    known=$(sed -n '2p' "$rec/passed")
    if [[ -n "$known" ]]; then
      echo "rec.sh: installed $(relative "$skill/features/$feature.md"), known failure at \"$known\""
    else
      echo "rec.sh: installed $(relative "$skill/features/$feature.md")"
    fi
    find "$rec" -mindepth 1 -maxdepth 1 ! -name facts.tsv -exec rm -rf {} +
    set_facts last_log "" last_snapshot ""
  done
  exit $status
fi

(($# >= 2)) || usage
feature=$1 action=$2
shift 2
check_feature "$feature"
rec="$skill/.cache/record/$feature"
staged="$rec/$feature.md"
target="$skill/features/$feature.md"

if [[ "$action" == start ]]; then
  (($# == 0)) || usage
  mkdir -p "$rec"
  rm -f "$rec/reached.tsv"
  if [[ -f "$staged" ]]; then
    echo "rec.sh: kept the staged file $(relative "$staged")"
  elif [[ -f "$target" ]]; then
    cp "$target" "$staged"
    echo "rec.sh: staged $(relative "$target") as $(relative "$staged")"
  else
    features=("$skill"/features/*.md)
    driver=$( ((${#features[@]})) && sed -n 's/^## Driving it with //p' "${features[@]}" | sort | uniq -c | sort -rn | sed -n '1s/^ *[0-9]* //p')
    [[ -n "$driver" ]] || driver=$(sed -n 's/^The user explicitly requests \(.*\) for every step of this skill.*/\1/p' "$skill/SKILL.md")
    printf '# %s\n\n## Sub-features\n\n## How to get to it (user POV)\n\n## Driving it with %s\n\nPreconditions:\n\n- **Clean up.**\n\n## Gotchas\n' "$feature" "$driver" > "$staged"
    echo "rec.sh: write the new feature file over the skeleton at $(relative "$staged")"
  fi
  attempts=0
  [[ ! -f "$target" ]] || attempts=$(fact attempts)
  set_facts attempts "${attempts:-0}" passed_hash "$(head -n 1 "$rec/passed" 2>/dev/null)" names "$(staged_names "$staged")"
  exit 0
fi

if [[ "$action" == index ]]; then
  (($# == 1)) || usage
  [[ "$1" == "- "* && "$1" == *"](./$feature.md)"* && "$1" != *$'\n'* ]] || fail "an index line is one list item that links ./$feature.md"
  readme="$skill/features/README.md"
  [[ -f "$readme" ]] || fail "no $(relative "$readme")"
  {
    flock 9
    read -r found anchor heading < <(awk -v f="$feature" '/^## /{s = $0 == "## Features"; if (s) h = NR} s && !m && index($0, "](./" f ".md)") {m = NR} s && /^- / {l = NR; if (i = index($0, "](./")) {n = substr($0, i + 4); n = substr(n, 1, index(n, ".md)") - 1); if (n != "" && index(f, n "-") == 1 && length(n) > b) {b = length(n); p = NR}}} END {print m + 0, (p ? p : l) + 0, h + 0}' "$readme")
    ((heading)) || fail "$(relative "$readme") has no ## Features section"
    updated=$(LINE=$1 awk -v m="$found" -v a="$anchor" -v h="$heading" '
      NR == m { print ENVIRON["LINE"]; next }
      { print }
      !m && NR == (a ? a : h) { if (!a) print ""; print ENVIRON["LINE"] }
    ' "$readme")
    printf '%s\n' "$updated" > "$readme"
  } 9< "$readme"
  if ((found)); then echo "rec.sh: replaced the index line of $feature"; else echo "rec.sh: added the index line of $feature"; fi
  exit 0
fi
if [[ "$action" == facts ]]; then
  (($# == 0)) || usage
  [[ -f "$rec/facts.tsv" ]] || { blank_facts; exit 0; }
  cat "$rec/facts.tsv"
  exit 0
fi
if [[ "$action" == result ]]; then
  (($# == 0)) || usage
  while [[ -e "$rec/running" ]]; do
    pid=$(cat "$rec/running" 2>/dev/null)
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      if [[ -f "$rec/result.new" ]]; then
        { cat "$rec/result.new"; echo "$feature: killed before it finished"; } > "$rec/result.txt"
        rm -f "$rec/result.new"
      elif [[ ! -f "$rec/result.txt" ]]; then
        echo "$feature: killed before it finished" > "$rec/result.txt"
      fi
      rm -f "$rec/running"
      break
    fi
    sleep 2
  done
  [[ -f "$rec/result.txt" ]] || { echo "no run yet for $feature"; exit 1; }
  cat "$rec/result.txt"
  exit 0
fi
[[ "$action" == run || "$action" == peek ]] || usage

known="" afters=() finds=()
while (($#)); do
  if [[ "$action" == run && -z "$known" && "$1" == --known-failure && -n "${2:-}" ]]; then
    known=$2
  elif [[ "$action" == peek && "$1" == --after && -n "${2:-}" ]]; then
    afters+=("$2")
  elif [[ "$action" == peek && "$1" == --find && -n "${2:-}" ]]; then
    finds+=("$2")
  else
    usage
  fi
  shift 2
done
[[ "$action" == run || -f "$skill/bin/observe.sh" ]] || fail "write bin/observe.sh; see verify-skill-spec.md Helpers"
((${#finds[@]} == 0)) || [[ -f "$skill/bin/find.sh" ]] || fail "write bin/find.sh; see verify-skill-spec.md Helpers"
[[ -f "$staged" ]] || fail "$feature has no staged file; run rec.sh $feature start"
finish() {
  exec >&- 2>&-
  wait "$out_tee" "$err_tee"
  mv "$rec/result.new" "$rec/result.txt"
  rm -f "$rec/running"
}

killed() {
  if [[ -n "${current:-}" ]]; then
    printf '%s / %s: killed\nfailing step: %s\n' "$feature" "$current" "$current"
    set_facts last_result "killed: $current" last_log "$(relative "${log:-}")" last_snapshot ""
  fi
  exit "$1"
}

if [[ "$action" == run ]]; then
  : > "$rec/result.new"
  echo $$ > "$rec/running"
  trap finish EXIT
  trap 'killed 130' INT
  trap 'killed 143' TERM
  exec > >(trap '' INT TERM HUP; exec tee -p -a "$rec/result.new"); out_tee=$!
  exec 2> >(trap '' INT TERM HUP; exec tee -p -a "$rec/result.new" >&2); err_tee=$!
fi

work="$rec/run" logs="$rec/steps" evidence="$skill/.cache/evidence/$feature"
[[ "$action" == run ]] || logs="$rec/peek-steps"
rm -rf "$work"
mkdir -p "$work" && : > "$work/steps"
split_steps "$staged" "$work"
mapfile -t numbers < <(cut -f1 "$work/steps")
mapfile -t labels < <(cut -f2 "$work/steps")
count=${#labels[@]}

problems=()
((count)) && [[ "${labels[-1]}" == "Clean up" ]] || problems+=("the last step is not \"Clean up\"")
if [[ "$action" == run ]]; then
  mapfile -t -O "${#problems[@]}" problems < <(check_steps "$work" "$staged" "$feature" "$skill/.cache/record/contract-map.tsv")
else
  mapfile -t -O "${#problems[@]}" problems < <(check_steps "$work" "$staged")
fi
block_hash() { sha256sum < "$work/$1.sh" | cut -d' ' -f1; }
unpeeked() {
  local i
  for ((i = 0; i < count; i++)); do
    [[ ! -f "$work/${numbers[i]}.sh" ]] || grep -qxF "${labels[i]}"$'\t'"$(block_hash "${numbers[i]}")" "$rec/reached.tsv" 2>/dev/null ||
      echo "step \"${labels[i]}\" has not been peeked since its block changed"
  done
}
[[ "$action" != run ]] || mapfile -t -O "${#problems[@]}" problems < <(unpeeked)
if [[ -n "$known" ]]; then
  ((count >= 3)) && [[ "${labels[-1]}" == "Clean up" && "${labels[-2]}" == "$known" ]] ||
    problems+=("--known-failure \"$known\" is not the last step before \"Clean up\"; a known failure goes only there")
fi
stops=() last=0
for after in "${afters[@]}"; do
  for ((i = 1; i < count - 1; i++)); do [[ "${labels[i]}" == "$after" ]] && break; done
  if ((i < count - 1)); then
    stops+=("$i")
    ((i > last)) && last=$i
  else
    problems+=("--after \"$after\" names no step between Preconditions and \"Clean up\"")
  fi
done
if ((${#problems[@]})); then
  printf 'rec.sh: %s\n' "${problems[@]}" >&2
  exit 2
fi

if [[ "$action" == run ]]; then
  attempts=$(( $(fact attempts) + 1 ))
  echo "attempt $attempts of $feature"
  set_facts attempts "$attempts" names "$(staged_names "$staged")"
  rm -rf "$rec/passed" "$rec/failure.txt"
  if [[ -d "$logs" || -d "$evidence" ]]; then
    rm -rf "$rec/previous" && mkdir -p "$rec/previous"
    [[ ! -d "$logs" ]] || mv "$logs" "$rec/previous/steps"
    [[ ! -d "$evidence" ]] || mv "$evidence" "$rec/previous/evidence"
  fi
fi
rm -rf "$logs"
mkdir -p "$logs" "$evidence"
export PATH="$skill/bin:$PATH" VERIFY_SESSION=$feature
: > "$work/state"

attempt() {
  local number=$1 label=$2
  current=$label
  log="$logs/$number-$(slug "$label").log"
  { echo "PS4='+[rec] '; set -x"; cat "$work/$number.sh"; } > "$work/$number.attempt.sh"
  run_step "$work/state" "$work/$number.attempt.sh" "$log"
}

step_output() { tail -n +$(( $(wc -l < "$work/$1.attempt.sh") + 2 )) "$log"; }

show_failure() {
  step_output "$1" | awk -v keep="$fail_tail" '
    function scan(s,   i, c) {
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (q == 1) { if (c == "\047") q = 0 }
        else if (q == 2) { if (c == "\\") i++; else if (c == "\047") q = 0 }
        else if (c == "\\") i++
        else if (c == "$" && substr(s, i + 1, 1) == "\047") { q = 2; i++ }
        else if (c == "\047") q = 1
      }
    }
    /^exit=/ { done = 1 }
    done { rest = rest $0 "\n"; next }
    q || /^\++\[rec\] / { print; scan($0); next }
    { out[++n] = $0 }
    END { for (i = n > keep ? n - keep + 1 : 1; i <= n; i++) print out[i]; printf "%s", rest }
  '
}

reach() {
  { awk -F '\t' -v label="$1" '$1 != label' "$rec/reached.tsv" 2>/dev/null; printf '%s\t%s\n' "$1" "$(block_hash "$2")"; } > "$rec/reached.new"
  mv "$rec/reached.new" "$rec/reached.tsv"
}

step_snapshot() { step_output "$1" | snapshot_path; }

record_failure() {
  local fields
  fields=$(step_output "$2" | sed '/^exit=/,$d' | awk '
    /^\++\[rec\] / { command = $0; sub(/^\++\[rec\] /, "", command); next }
    /[^[:space:]]/ { output = $0 }
    END { gsub(/\t/, " ", command); gsub(/\t/, " ", output); print command "\t" output }
  ')
  printf '%s\t%s\t%s\n' "$feature" "$1" "$fields" >> "$skill/.cache/record/failures.txt"
}

clean_up() {
  if attempt "${numbers[-1]}" "Clean up"; then
    echo "$feature / Clean up: pass"
  else
    echo "$feature / Clean up: fail ($(relative "$log"))"
    show_failure "${numbers[-1]}"
    return 1
  fi
}

peek_into() {
  rm -f "$2"
  printf 'observe.sh %q\n' "$(relative "$2")" > "$work/$1.sh"
  attempt "$1" Snapshot && [[ -s "$2" ]]
}

snapshot() {
  local peek="$rec/peek.txt"
  ((${#stops[@]} < 2)) || peek="$rec/peek-$1.txt"
  if peek_into "peek-$1" "$peek"; then
    echo "rec.sh: peek written to $(relative "$peek")${2:+ (the state where \"$2\" failed)}"
  else
    echo "rec.sh: observe.sh wrote no $(relative "$peek") ($(relative "$log"))"
    show_failure "peek-$1"
    status=1
  fi
}

find_expressions() {
  local n=0 expression
  for expression in "${finds[@]}"; do
    n=$((n + 1))
    printf 'find.sh %q\n' "$expression" > "$work/find-$n.sh"
    attempt "find-$n" Find
    step_output "find-$n" | sed '/^exit=/,$d' | grep -v '^+*\[rec\] ' | awk -v expression="$expression" '
      NR == 1 && /^[0-9]+ match/ { print "find " expression ": " ($1 == 1 ? "" : "!! ") $0; next }
      NR == 1 { print "find " expression ": " (/^error / ? "" : "error ") $0; exit }
      { print "  " $0 }
      END { if (!NR) print "find " expression ": error find.sh printed nothing" }
    '
  done
}

if [[ "$action" == peek ]]; then
  ((${#stops[@]})) || stops=(0)
  status=0 failed=""
  rm -f "$rec"/peek.txt "$rec"/peek-*.txt
  for ((i = 0; i <= last; i++)); do
    attempt "${numbers[i]}" "${labels[i]}"; step_status=$?
    reach "${labels[i]}" "${numbers[i]}"
    if ((step_status)); then
      echo "$feature / ${labels[i]}: fail ($(relative "$log"))"
      show_failure "${numbers[i]}"
      status=1 failed=${labels[i]}
      break
    fi
    echo "$feature / ${labels[i]}: pass"
    for n in "${!stops[@]}"; do
      ((stops[n] != i)) || snapshot $((n + 1))
    done
  done
  if [[ -n "$failed" ]]; then
    reached="" missed=""
    for n in "${!stops[@]}"; do
      if ((stops[n] < i)); then reached+=" \"${labels[stops[n]]}\""; else missed+=" \"${labels[stops[n]]}\""; fi
    done
    for n in "${!stops[@]}"; do ((stops[n] < i)) || { snapshot $((n + 1)) "$failed"; break; }; done
    echo "rec.sh: reached:${reached:- none}; not reached:$missed"
  fi
  find_expressions
  clean_up || status=1
  reach "Clean up" "${numbers[-1]}"
  exit $status
fi

known_failed=""
for ((i = 0; i < count; i++)); do
  label=${labels[i]}
  if attempt "${numbers[i]}" "$label"; then
    echo "$feature / $label: pass"
    continue
  fi
  if [[ "$label" == "$known" ]]; then
    echo "$feature / $label: known failure, failed as expected"
    known_failed=1
    continue
  fi
  echo "$feature / $label: fail"
  show_failure "${numbers[i]}"
  failed_log=$log snapshot=$(step_snapshot "${numbers[i]}")
  record_failure "$label" "${numbers[i]}"
  [[ ! -f "$skill/bin/observe.sh" ]] || ! peek_into failure "$rec/failure.txt" || snapshot=$rec/failure.txt
  set_facts last_result "failed: $label" last_log "$(relative "$failed_log")" last_snapshot "${snapshot:+$(relative "$snapshot")}"
  [[ "$label" == "Clean up" ]] || clean_up
  echo "failing step: $label"
  [[ -z "$snapshot" ]] || echo "snapshot: $(relative "$snapshot")"
  echo "full log: $(relative "$failed_log")"
  exit 1
done
[[ -z "$known" || -n "$known_failed" ]] || fail "the known failure \"$known\" passed; drop the flag"
{ steps_hash "$work"; [[ -z "$known" ]] || echo "$known"; } > "$rec/passed"
set_facts passed_hash "$(head -n 1 "$rec/passed")" last_result passed last_log "" last_snapshot ""
echo "rec.sh: passed; rec.sh install $feature installs it"
