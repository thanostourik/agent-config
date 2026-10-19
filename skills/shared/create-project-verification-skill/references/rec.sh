#!/usr/bin/env bash
# rec.sh <feature> start: stage features/<feature>.md as .cache/record/<feature>/<feature>.md and print that path; write the whole feature file there.
# rec.sh <feature> run [--known-failure '<Label>']: empty .cache/evidence/<feature>/, then run the staged file's Driving section the way drive.sh runs an installed one; the flag lets the last step before Clean up fail.
# rec.sh <feature> peek [--after '<Label>']: run the staged file's Preconditions (and the steps through <Label>) as run does, save one snapshot of the screen they leave to .cache/record/<feature>/peek.txt, then run Clean up; the snapshot command is $REC_PEEK with that path appended as it is, so the path is its last argument.
# rec.sh install [<feature>...]: move staged files that passed run into features/ and check them with drive.sh --check.
set -uo pipefail
shopt -s nullglob

skill=$(cd "$(dirname "$0")/.." && pwd)
cd "$skill/../../.."
source "$skill/bin/steps.sh"

usage_all="usage: rec.sh <feature> start
       rec.sh <feature> run [--known-failure '<Label>']
       REC_PEEK='<snapshot command>' rec.sh <feature> peek [--after '<Label>']
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
    echo "rec.sh: write the new feature file at $(relative "$staged")"
  fi
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
  tail -n +$(( $(wc -l < "$work/$1.attempt.sh") + 2 )) "$log" | sed '/^+*\[rec\] __drive_save$/,/^exit=/{/^exit=/!d}'
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
  echo "$feature / $label: fail ($(relative "$log"))"
  show_failure "${numbers[i]}"
  [[ "$label" == "Clean up" ]] || clean_up
  exit 1
done
[[ -z "$known" || -n "$known_failed" ]] || fail "the known failure \"$known\" passed; drop the flag"
{ hash_of "$staged"; [[ -z "$known" ]] || echo "$known"; } > "$rec/passed"
echo "rec.sh: passed; rec.sh install $feature installs it"
