#!/usr/bin/env bash
# rec.sh <feature> start: stage features/<feature>.md as .cache/record/<feature>/<feature>.md and print that path; write the whole feature file there.
# rec.sh <feature> run [--known-failure '<Label>']: empty .cache/evidence/<feature>/, then run the staged file's Driving section the way drive.sh runs an installed one; the flag lets the last step before Clean up fail.
# rec.sh install [<feature>...]: move staged files that passed run into features/ and check them with drive.sh --check.
set -uo pipefail
shopt -s nullglob

skill=$(cd "$(dirname "$0")/.." && pwd)
cd "$skill/../../.."
source "$skill/bin/steps.sh"

usage_all="usage: rec.sh <feature> start
       rec.sh <feature> run [--known-failure '<Label>']
       rec.sh install [<feature>...]"
fail() { echo "rec.sh: $*" >&2; exit 1; }
usage() { echo "$usage_all" >&2; exit 2; }
check_feature() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "a feature is the feature file name without .md"; }
relative() { echo "${1#"$PWD/"}"; }
hash_of() { sha256sum "$1" | cut -d' ' -f1; }

unpassed() {
  local rec="$skill/.cache/record/$1"
  [[ -f "$rec/$1.md" ]] || { echo "$1 has no staged file; run rec.sh $1 start"; return; }
  [[ -f "$rec/passed" ]] || { echo "$1 has not passed rec.sh $1 run"; return; }
  [[ "$(head -n 1 "$rec/passed")" == "$(hash_of "$rec/$1.md")" ]] || echo "$1 changed since it passed; run it again"
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
  for feature in "${features[@]}"; do
    mv "$skill/.cache/record/$feature/$feature.md" "$skill/features/$feature.md"
  done
  "$skill/bin/drive.sh" --check "${features[@]}"; status=$?
  for feature in "${features[@]}"; do
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
    echo "rec.sh: write the new feature file at $(relative "$staged")"
  fi
  exit 0
fi
[[ "$action" == run ]] || usage

known=""
if (($# == 2)) && [[ "$1" == --known-failure && -n "$2" ]]; then known=$2; elif (($# != 0)); then usage; fi
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
for ((i = 0; i < count; i++)); do
  if [[ ! -f "$work/${numbers[i]}.sh" ]]; then
    problems+=("step \"${labels[i]}\" has no bash block")
  elif script=$(calls_run_script "$work/${numbers[i]}.sh"); then
    problems+=("step \"${labels[i]}\" calls $script; recipes may not start, check or clean up the whole run")
  fi
done
if [[ -n "$known" ]]; then
  ((count >= 3)) && [[ "${labels[-1]}" == "Clean up" && "${labels[-2]}" == "$known" ]] ||
    problems+=("--known-failure \"$known\" is not the last step before \"Clean up\"; a known failure goes only there")
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
  tail -n +$(( $(wc -l < "$work/$1.attempt.sh") + 2 )) "$log" | sed '/^+*\[rec\] __drive_save$/,/^exit=/{/^exit=/!d}'
}

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
  echo "$feature / $label: fail ($(relative "$log"))"
  show_failure "${numbers[i]}"
  if [[ "$label" != "Clean up" ]]; then
    if attempt "${numbers[-1]}" "Clean up"; then
      echo "$feature / Clean up: pass"
    else
      echo "$feature / Clean up: fail ($(relative "$log"))"
      show_failure "${numbers[-1]}"
    fi
  fi
  exit 1
done
[[ -z "$known" || -n "$known_failed" ]] || fail "the known failure \"$known\" passed; drop the flag"
{ hash_of "$staged"; [[ -z "$known" ]] || echo "$known"; } > "$rec/passed"
echo "rec.sh: passed; rec.sh install $feature installs it"
