#!/usr/bin/env bash
# rec.sh <feature> start|pre|step|say|undo|show|finish ...: record a feature's Driving section from commands that pass under drive.sh's executor.
set -uo pipefail
shopt -s nullglob

skill=$(cd "$(dirname "$0")/.." && pwd)
cd "$skill/../../.."
source "$skill/bin/steps.sh"

usage_all='usage: rec.sh <feature> start | pre <command> | step <Label> <command> | say <Label> <sentence> | undo | show | finish [--tool <tool>]'
fail() { echo "rec.sh: $*" >&2; exit 1; }
usage() { echo "usage: rec.sh <feature> $1" >&2; exit 2; }

(($# >= 2)) || { echo "$usage_all" >&2; exit 2; }
feature=$1 action=$2
shift 2
[[ "$feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "feature must be the feature file name without .md"
rec="$skill/.cache/record/$feature"
target="$skill/features/$feature.md"

step_of() { local step; for step in "$rec"/[0-9][0-9]; do [[ "$(< "$step/label")" == "$1" ]] && { echo "$step"; return 0; }; done; return 1; }
current_step() { local steps=("$rec"/[0-9][0-9]); ((${#steps[@]})) && echo "${steps[-1]}"; }

check_label() {
  [[ -n "$1" && "$1" != *[$'\n\t*']* ]] || fail "a label is one line without tabs or *"
  [[ "$1" != Preconditions ]] || fail "use rec.sh $feature pre for the Preconditions block"
}

record() {
  local label=$1 command=$2 current step attempt="$rec/attempt.sh" log="$rec/attempt.log" status number script file
  [[ -n "${command//[[:space:]]/}" ]] || fail "the command is empty"
  grep -q '^```[[:space:]]*$' <<< "$command" && fail "a command may not contain a line that closes a fence"
  current=$(current_step)
  if [[ -n "$current" && "$(< "$current/label")" == "$label" ]]; then
    step=$current
  elif step=$(step_of "$label"); then
    fail "step \"$label\" comes before the current step \"$(< "$current/label")\"; steps run in order (undo back to it, or start again)"
  elif [[ "$label" == Preconditions ]]; then
    [[ -z "$current" ]] || fail "Preconditions come before every step; start again"
    step="$rec/00"
  else
    number=1
    [[ -n "$current" ]] && number=$(( 10#${current##*/} + 1 ))
    ((number <= 99)) || fail "a recording holds at most 99 steps"
    step=$(printf '%s/%02d' "$rec" "$number")
  fi
  printf '%s\n' "$command" > "$attempt"
  if script=$(calls_run_script "$attempt"); then
    fail "the command calls $script; recipes may not start, check or clean up the whole run"
  fi
  cp "$rec/state" "$rec/state.before"
  run_step "$rec/state" "$attempt" "$log"; status=$?
  tail -n +$(( $(wc -l < "$attempt") + 2 )) "$log"
  { echo "== $label"; cat "$log"; } >> "$rec/log"
  if ((status != 0)); then
    mv "$rec/state.before" "$rec/state"
    echo "rec.sh: not recorded"
    exit $status
  fi
  mkdir -p "$step"
  [[ -f "$step/label" ]] || printf '%s\n' "$label" > "$step/label"
  number=1
  for file in "$step"/*.sh; do number=$(( 10#$(basename "$file" .sh) + 1 )); done
  number=$(printf '%03d' "$number")
  mv "$attempt" "$step/$number.sh"
  mv "$rec/state.before" "$step/$number.state"
  echo "rec.sh: recorded as command $((10#$number)) of \"$label\""
}

render() {
  local step label sentence separator=""
  for step in "$rec"/[0-9][0-9]; do
    label=$(< "$step/label")
    sentence="(no sentence yet)"
    [[ -s "$step/sentence" ]] && sentence=$(< "$step/sentence")
    printf '%s' "$separator"
    separator=$'\n'
    if [[ "$label" == Preconditions ]]; then echo "Preconditions: $sentence"; else echo "- **$label.** $sentence"; fi
    echo
    echo '```bash'
    cat "$step"/*.sh
    echo '```'
  done
}

if [[ "$action" == start ]]; then
  (($# == 0)) || usage start
  rm -rf "$rec"
  mkdir -p "$rec"
  : > "$rec/state"
  echo "rec.sh: recording $feature in ${rec#"$PWD/"}"
  exit 0
fi
case "$action" in pre | step | say | undo | show | finish) ;; *) echo "$usage_all" >&2; exit 2 ;; esac
[[ -f "$rec/state" ]] || fail "no recording for $feature; run rec.sh $feature start first"
export PATH="$skill/bin:$PATH" VERIFY_SESSION=$feature

case "$action" in
  pre)
    (($# == 1)) || usage "pre <command>"
    record Preconditions "$1"
    ;;
  step)
    (($# == 2)) || usage "step <Label> <command>"
    check_label "$1"
    record "$1" "$2"
    ;;
  say)
    (($# == 2)) || usage "say <Label> <sentence>"
    [[ -n "$2" && "$2" != *$'\n'* ]] || fail "a sentence is one non-empty line"
    step=$(step_of "$1") || fail "no step \"$1\" yet; record a command for it first"
    printf '%s\n' "$2" > "$step/sentence"
    ;;
  undo)
    (($# == 0)) || usage undo
    step=$(current_step)
    [[ -n "$step" ]] || fail "nothing recorded"
    commands=("$step"/*.sh)
    last=${commands[-1]}
    echo "rec.sh: removed from \"$(< "$step/label")\":"
    cat "$last"
    mv "${last%.sh}.state" "$rec/state"
    rm "$last"
    if ((${#commands[@]} == 1)); then
      echo "rec.sh: step \"$(< "$step/label")\" is empty and was removed"
      rm -rf "$step"
    fi
    ;;
  show)
    (($# == 0)) || usage show
    render
    ;;
  finish)
    tool=""
    if (($# == 2)) && [[ "$1" == --tool && -n "$2" ]]; then tool=$2; elif (($# != 0)); then usage "finish [--tool <tool>]"; fi
    problems=()
    [[ -d "$rec/00" ]] || problems+=("no Preconditions block")
    for step in "$rec"/[0-9][0-9]; do
      [[ -s "$step/sentence" ]] || problems+=("step \"$(< "$step/label")\" has no sentence")
    done
    current=$(current_step)
    [[ -n "$current" && "$(< "$current/label")" == "Clean up" ]] || problems+=("the last step is not \"Clean up\"")
    if [[ -f "$target" ]]; then
      grep -q '^## Driving it with' "$target" || problems+=("features/$feature.md has no \"## Driving it with\" section")
    else
      [[ -n "$tool" ]] || problems+=("features/$feature.md does not exist; pass --tool <tool> to create it")
    fi
    if ((${#problems[@]})); then
      printf 'rec.sh: %s\n' "${problems[@]}" >&2
      exit 1
    fi
    render > "$rec/section.md"
    if [[ -f "$target" ]]; then
      awk -v section="$rec/section.md" '
        /^## Driving it with/ && !done { print; print ""; while ((getline line < section) > 0) print line; skipping = 1; done = 1; next }
        skipping && /^## / { skipping = 0; print "" }
        !skipping { print }
      ' "$target" > "$rec/written.md"
    else
      { echo "## Driving it with $tool"; echo; cat "$rec/section.md"; } > "$rec/written.md"
    fi
    rm -rf "$rec/check" && mkdir -p "$rec/check" && : > "$rec/check/steps"
    split_steps "$rec/written.md" "$rec/check"
    if ! diff <(cat "$rec"/[0-9][0-9]/label) <(cut -f2 "$rec/check/steps") > /dev/null; then
      fail "the written section does not parse back to the recorded labels; features/$feature.md is unchanged (see ${rec#"$PWD/"}/written.md)"
    fi
    while IFS=$'\t' read -r step number; do
      cat "$step"/*.sh | cmp -s - "$rec/check/$number.sh" || fail "the block of step \"$(< "$step/label")\" does not parse back; features/$feature.md is unchanged (see ${rec#"$PWD/"}/written.md)"
    done < <(paste <(printf '%s\n' "$rec"/[0-9][0-9]) <(cut -f1 "$rec/check/steps"))
    mv "$rec/written.md" "$target"
    echo "rec.sh: wrote the Driving section of features/$feature.md"
    ;;
esac
