#!/usr/bin/env bash
# rec.sh <feature> start: stage features/<feature>.md, or a skeleton for a new feature, as .cache/record/<feature>/<feature>.md and print that path; write the whole feature file there.
# rec.sh <feature> run [--known-failure '<Label>']: check the staged file, empty .cache/evidence/<feature>/, then run its Driving section the way drive.sh runs an installed one; the flag lets the last step before Clean up fail. A failure ends with the failing step, its snapshot and its log, and adds a line to .cache/record/failures.txt.
# rec.sh <feature> peek [--after '<Label>']: run the staged file's Preconditions (and the steps through <Label>) as run does, save one snapshot of the screen they leave to .cache/record/<feature>/peek.txt, then run Clean up; the snapshot command is $REC_PEEK with that path appended as it is, so the path is its last argument.
# rec.sh <feature> index '<index line>': replace the line linking ./<feature>.md in the ## Features list of features/README.md, or append it to that list.
# rec.sh install [<feature>...]: move staged files that passed run into features/ and check them with drive.sh --check.
set -uo pipefail
shopt -s nullglob

fail_tail=60

skill=$(cd "$(dirname "$0")/.." && pwd)
cd "$skill/../../.."
source "$skill/bin/steps.sh"

usage_all="usage: rec.sh <feature> start
       rec.sh <feature> run [--known-failure '<Label>']
       REC_PEEK='<snapshot command>' rec.sh <feature> peek [--after '<Label>']
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

unpassed() {
  local rec="$skill/.cache/record/$1"
  [[ -f "$rec/$1.md" ]] || { echo "$1 has no staged file; run rec.sh $1 start"; return; }
  [[ -f "$rec/passed" ]] || { echo "$1 has not passed rec.sh $1 run"; return; }
  [[ "$(head -n 1 "$rec/passed")" == "$(recipe_hash "$rec/$1.md")" ]] || echo "$1 changed since it passed; run it again"
}

if [[ "${1:-}" == install ]]; then
  shift
  features=()
  if (($#)); then
    for feature in "$@"; do
      check_feature "$feature"
      problem=$(unpassed "$feature")
      [[ -z "$problem" ]] || fail "$problem"
      features+=("$feature")
    done
  else
    for staged in "$skill"/.cache/record/*/*.md; do
      feature=$(basename "$staged" .md)
      [[ "$feature" == "$(basename "$(dirname "$staged")")" ]] || continue
      problem=$(unpassed "$feature")
      if [[ -n "$problem" ]]; then echo "rec.sh: skipped: $problem"; else features+=("$feature"); fi
    done
  fi
  ((${#features[@]})) || { echo "rec.sh: nothing to install"; exit 0; }
  mkdir -p "$skill/features"
  moved=() status=0
  for feature in "${features[@]}"; do
    target="$skill/features/$feature.md"
    if [[ ! -d "$target" ]] && mv "$skill/.cache/record/$feature/$feature.md" "$target"; then
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
    rm -rf "$rec"
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
  exit 0
fi

if [[ "$action" == index ]]; then
  (($# == 1)) || usage
  [[ "$1" == "- "* && "$1" == *"](./$feature.md)"* && "$1" != *$'\n'* ]] || fail "an index line is one list item that links ./$feature.md"
  readme="$skill/features/README.md"
  [[ -f "$readme" ]] || fail "no $(relative "$readme")"
  {
    flock 9
    read -r found last heading < <(awk -v link="](./$feature.md)" '/^## /{s = $0 == "## Features"; if (s) h = NR} s && !m && index($0, link) {m = NR} s && /^- / {l = NR} END {print m + 0, l + 0, h + 0}' "$readme")
    ((heading)) || fail "$(relative "$readme") has no ## Features section"
    updated=$(LINE=$1 awk -v m="$found" -v l="$last" -v h="$heading" '
      NR == m { print ENVIRON["LINE"]; next }
      { print }
      !m && NR == (l ? l : h) { if (!l) print ""; print ENVIRON["LINE"] }
    ' "$readme")
    printf '%s\n' "$updated" > "$readme"
  } 9< "$readme"
  if ((found)); then echo "rec.sh: replaced the index line of $feature"; else echo "rec.sh: added the index line of $feature"; fi
  exit 0
fi
[[ "$action" == run || "$action" == peek ]] || usage

known="" after=""
if (($# == 0)); then
  :
elif (($# == 2)) && [[ "$action" == run && "$1" == --known-failure && -n "$2" ]]; then
  known=$2
elif (($# == 2)) && [[ "$action" == peek && "$1" == --after && -n "$2" ]]; then
  after=$2
else
  usage
fi
[[ "$action" == run || -n "${REC_PEEK:-}" ]] || fail "set REC_PEEK to the snapshot command the maintenance skill names; peek appends the output path to it"
[[ -f "$staged" ]] || fail "$feature has no staged file; run rec.sh $feature start"

work="$rec/run" logs="$rec/steps"
rm -rf "$work"
mkdir -p "$work" && : > "$work/steps"
split_steps "$staged" "$work"
mapfile -t numbers < <(cut -f1 "$work/steps")
mapfile -t labels < <(cut -f2 "$work/steps")
count=${#labels[@]}

problems=()
((count)) && [[ "${labels[0]}" == Preconditions ]] || problems+=("$(relative "$staged") has no Preconditions block under \"## Driving it with\"")
((count)) && [[ "${labels[-1]}" == "Clean up" ]] || problems+=("the last step is not \"Clean up\"")
mapfile -t -O "${#problems[@]}" problems < <(check_steps "$work")
if [[ -n "$known" ]]; then
  ((count >= 3)) && [[ "${labels[-1]}" == "Clean up" && "${labels[-2]}" == "$known" ]] ||
    problems+=("--known-failure \"$known\" is not the last step before \"Clean up\"; a known failure goes only there")
fi
last=0
if [[ -n "$after" ]]; then
  for ((last = 1; last < count - 1; last++)); do [[ "${labels[last]}" == "$after" ]] && break; done
  ((last < count - 1)) || problems+=("--after \"$after\" names no step between Preconditions and \"Clean up\"")
fi
if ((${#problems[@]})); then
  printf 'rec.sh: %s\n' "${problems[@]}" >&2
  exit 2
fi

rm -rf "$logs" "$rec/passed" "$skill/.cache/evidence/$feature"
mkdir -p "$logs" "$skill/.cache/evidence/$feature"
export PATH="$skill/bin:$PATH" VERIFY_SESSION=$feature
: > "$work/state"

attempt() {
  local number=$1 label=$2
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

if [[ "$action" == peek ]]; then
  peek="$rec/peek.txt" status=0
  rm -f "$peek"
  for ((i = 0; i <= last; i++)); do
    if attempt "${numbers[i]}" "${labels[i]}"; then
      echo "$feature / ${labels[i]}: pass"
    else
      echo "$feature / ${labels[i]}: fail ($(relative "$log"))"
      show_failure "${numbers[i]}"
      status=1
      break
    fi
  done
  printf '%s%q\n' "$REC_PEEK" "$(relative "$peek")" > "$work/peek.sh"
  if attempt peek Snapshot && [[ -s "$peek" ]]; then
    echo "rec.sh: peek written to $(relative "$peek")"
  else
    echo "rec.sh: the peek command wrote no $(relative "$peek") ($(relative "$log"))"
    show_failure peek
    status=1
  fi
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
  [[ "$label" == "Clean up" ]] || clean_up
  echo "failing step: $label"
  [[ -z "$snapshot" ]] || echo "snapshot: $(relative "$snapshot")"
  echo "full log: $(relative "$failed_log")"
  exit 1
done
[[ -z "$known" || -n "$known_failed" ]] || fail "the known failure \"$known\" passed; drop the flag"
{ steps_hash "$work"; [[ -z "$known" ]] || echo "$known"; } > "$rec/passed"
echo "rec.sh: passed; rec.sh install $feature installs it"
