#!/usr/bin/env bash
# rec.sh <feature> start: stage features/<feature>.md, or a skeleton for a new feature, as .cache/record/<feature>/<feature>.md and print that path; write the whole feature file there. An installed feature keeps its attempts count.
# rec.sh <feature> run [--known-failure '<Label>']: print attempt <n> of <feature>, counting runs since start, check the staged file as drive.sh --check does, contract coverage included, move the last run's step logs and .cache/evidence/<feature>/ to .cache/record/<feature>/previous/, then run its Driving section the way drive.sh runs an installed one; the flag lets the last step before Clean up fail. A failure ends with the failing step, its snapshot and its log, and adds a line to .cache/record/failures.txt; with a snapshot command, that snapshot is a fresh one of the failing screen, taken before Clean up as .cache/record/<feature>/failure.txt. Everything it prints also lands in .cache/record/<feature>/result.txt when it ends; .cache/record/<feature>/running holds its pid until then.
# rec.sh <feature> result: wait while a run of <feature> is going, then print its result.txt; a run whose process died first prints killed before it finished.
# rec.sh <feature> peek [--after '<Label>']... [--find '<locator>']...: run the staged file's Preconditions and the steps through the last <Label> as run does, save one snapshot after Preconditions or after each <Label> to .cache/record/<feature>/peek.txt, peek-<n>.txt for the n-th of several flags, then evaluate each Playwright locator on the last screen reached and print its match count and up to 3 matches, then run Clean up; a failing step stops the steps and its screen goes to the next snapshot file. The snapshot command is $REC_PEEK, else .cache/record/peek-command.txt, with the path appended as it is, so the path is its last argument.
# rec.sh <feature> facts: print .cache/record/<feature>/facts.tsv: attempts, passed_hash, last_result, last_log, last_snapshot and the verify- and Verify fixture names of the staged file; without one, attempts 0 and the other keys empty.
# rec.sh <feature> index '<index line>': replace the line linking ./<feature>.md in the ## Features list of features/README.md, or add it after the line of its parent, the listed feature whose name followed by - starts <feature>, the longest one, else at the end of that list.
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
       rec.sh <feature> peek [--after '<Label>']... [--find '<locator>']...
       rec.sh <feature> facts
       rec.sh <feature> index '<index line>'
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

set_facts() {
  local file="$rec/facts.tsv"
  [[ -f "$file" ]] || printf '%s\t\n' attempts passed_hash last_result last_log last_snapshot names > "$file"
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
  [[ -f "$rec/facts.tsv" ]] || { printf 'attempts\t0\n'; printf '%s\t\n' passed_hash last_result last_log last_snapshot names; exit 0; }
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
peek_command=${REC_PEEK:-$(cat "$skill/.cache/record/peek-command.txt" 2>/dev/null)}
[[ "$action" == run || -n "$peek_command" ]] || fail "set REC_PEEK or write .cache/record/peek-command.txt"
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
  attempts=$(( $(fact attempts) + 1 ))
  echo "attempt $attempts of $feature"
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
  set_facts attempts "$attempts" names "$(staged_names "$staged")"
  mapfile -t -O "${#problems[@]}" problems < <(check_steps "$work" "$staged" "$feature" "$skill/.cache/record/contract-map.tsv")
else
  mapfile -t -O "${#problems[@]}" problems < <(check_steps "$work" "$staged")
fi
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
  log="$logs/$number-$(tr 'A-Z' 'a-z' <<< "$label" | tr -cs 'a-z0-9' '-' | sed 's/-$//').log"
  { echo "PS4='+[rec] '; set -x"; cat "$work/$number.sh"; } > "$work/$number.attempt.sh"
  run_step "$work/state" "$work/$number.attempt.sh" "$log"
}

show_failure() {
  tail -n +$(( $(wc -l < "$work/$1.attempt.sh") + 2 )) "$log" | awk -v keep="$fail_tail" '
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

step_snapshot() {
  tail -n +$(( $(wc -l < "$work/$1.attempt.sh") + 2 )) "$log" | grep -o '\[Snapshot\]([^)]*)' | tail -n 1 | sed 's/^\[Snapshot\](//; s/)$//'
}

record_failure() {
  local fields
  fields=$(tail -n +$(( $(wc -l < "$work/$2.attempt.sh") + 2 )) "$log" | sed '/^exit=/,$d' | awk '
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
  printf '%s%q\n' "$peek_command" "$(relative "$2")" > "$work/$1.sh"
  attempt "$1" Snapshot && [[ -s "$2" ]]
}

snapshot() {
  local peek="$rec/peek.txt"
  ((${#stops[@]} < 2)) || peek="$rec/peek-$1.txt"
  if peek_into "peek-$1" "$peek"; then
    echo "rec.sh: peek written to $(relative "$peek")${2:+ (the screen where \"$2\" failed)}"
  else
    echo "rec.sh: the peek command wrote no $(relative "$peek") ($(relative "$log"))"
    show_failure "peek-$1"
    status=1
  fi
}

find_locators() {
  local n=0 locator
  ((${#finds[@]})) || return 0
  [[ "$(sed -n 's/^## Driving it with //p' "$staged" | head -n 1)" == *"Playwright CLI"* ]] || { echo "find needs a Playwright CLI driver"; return 0; }
  for locator in "${finds[@]}"; do
    n=$((n + 1))
    printf 'pw.sh run-code %q\n' 'async page => { try { const l = page.'"${locator#page.}"'; const n = await l.count(); const out = [String(n)]; for (let i = 0; i < Math.min(n, 3); i++) { const m = l.nth(i); const a = (await m.ariaSnapshot({ timeout: 5000 })).split("\n")[0].match(/^- \x27?([\w-]+)(?: "((?:[^"\\]|\\.)*)")?/); const role = a ? a[1] : await m.evaluate(e => e.tagName.toLowerCase()); const text = (await m.innerText({ timeout: 5000 })).replace(/\s+/g, " ").trim().slice(0, 80); out.push(`${role} "${a && a[2] || ""}" | ${text}`); } return out.join("\n"); } catch (e) { return `error ${String(e.message).split("\n")[0]}`; } }' > "$work/find-$n.sh"
    attempt "find-$n" Find
    tail -n +$(( $(wc -l < "$work/find-$n.attempt.sh") + 2 )) "$log" | awk -v locator="$locator" '
      function decode(s,   out, i, c) {
        s = substr(s, 2, length(s) - 2)
        for (i = 1; i <= length(s); i++) {
          c = substr(s, i, 1)
          if (c == "\\") { c = substr(s, ++i, 1); if (c == "n") c = "\n"; else if (c == "t") c = "\t" }
          out = out c
        }
        return out
      }
      result { text = decode($0); found = 1; result = 0; next }
      /^### Result$/ { result = 1; next }
      error { message = $0; error = 0; next }
      /^### Error$/ { error = 1; next }
      first == "" && /[^[:space:]]/ && !/^\++\[rec\] / && !/^exit=/ { first = $0 }
      END {
        if (!found) { print "find " locator ": error " (message != "" ? message : first); exit }
        n = split(text, lines, "\n")
        if (lines[1] ~ /^error /) { print "find " locator ": " lines[1]; exit }
        print "find " locator ": " (lines[1] == 1 ? "" : "!! ") lines[1] " match" (lines[1] == 1 ? "" : "es")
        for (i = 2; i <= n; i++) print "  " lines[i]
      }
    '
  done
}

if [[ "$action" == peek ]]; then
  ((${#stops[@]})) || stops=(0)
  status=0 failed=""
  rm -f "$rec"/peek.txt "$rec"/peek-*.txt
  for ((i = 0; i <= last; i++)); do
    if ! attempt "${numbers[i]}" "${labels[i]}"; then
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
  find_locators
  clean_up || status=1
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
  [[ -z "$peek_command" ]] || ! peek_into failure "$rec/failure.txt" || snapshot=$rec/failure.txt
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
