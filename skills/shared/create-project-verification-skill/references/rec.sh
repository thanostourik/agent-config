#!/usr/bin/env bash
# rec.sh <feature> start|pre|step|undo|show|finish ...: record a feature's Driving section into a staged copy of its file, one whole step per call, from blocks that pass under drive.sh's executor; step --keep also records one that fails.
# rec.sh install [feature...]: move staged feature files into features/ and check them with drive.sh --check.
set -uo pipefail
shopt -s nullglob

skill=$(cd "$(dirname "$0")/.." && pwd)
cd "$skill/../../.."
source "$skill/bin/steps.sh"

usage_all='usage: rec.sh <feature> start | pre <sentence> <block> | step [--keep] <Label> <sentence> <block> | undo | show | finish [--tool <tool>]
       rec.sh install [<feature>...]'
fail() { echo "rec.sh: $*" >&2; exit 1; }
usage() { echo "usage: rec.sh <feature> $1" >&2; exit 2; }
check_feature() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "a feature is the feature file name without .md"; }
relative() { echo "${1#"$PWD/"}"; }

if [[ "${1:-}" == install ]]; then
  shift
  features=("$@")
  if ((${#features[@]} == 0)); then
    for staged in "$skill"/.cache/record/*/*.md; do
      [[ "$(basename "$staged" .md)" == "$(basename "$(dirname "$staged")")" ]] && features+=("$(basename "$staged" .md)")
    done
  fi
  for feature in "${features[@]}"; do
    check_feature "$feature"
    rec="$skill/.cache/record/$feature"
    [[ -f "$rec/$feature.md" ]] || fail "$feature has no staged file; run rec.sh $feature finish first"
    [[ ! -f "$rec/state" ]] || fail "the recording of $feature is not finished; run rec.sh $feature finish, or remove $(relative "$rec") to drop it"
  done
  ((${#features[@]})) || { echo "rec.sh: nothing to install"; exit 0; }
  mkdir -p "$skill/features"
  for feature in "${features[@]}"; do
    mv "$skill/.cache/record/$feature/$feature.md" "$skill/features/$feature.md"
  done
  "$skill/bin/drive.sh" --check "${features[@]}"; status=$?
  for feature in "${features[@]}"; do
    rm -rf "$skill/.cache/record/$feature"
    echo "rec.sh: installed $(relative "$skill/features/$feature.md")"
  done
  exit $status
fi

(($# >= 2)) || { echo "$usage_all" >&2; exit 2; }
feature=$1 action=$2
shift 2
check_feature "$feature"
rec="$skill/.cache/record/$feature"
staged="$rec/$feature.md"
target="$skill/features/$feature.md"

step_of() { local step; for step in "$rec"/[0-9][0-9]; do [[ "$(< "$step/label")" == "$1" ]] && { echo "$step"; return 0; }; done; return 1; }
current_step() { local steps=("$rec"/[0-9][0-9]); ((${#steps[@]})) && echo "${steps[-1]}"; }

check_label() {
  [[ -n "$1" && "$1" != *[$'\n\t*']* ]] || fail "a label is one line without tabs or *"
  [[ "$1" != Preconditions ]] || fail "use rec.sh $feature pre for the Preconditions block"
}

record() {
  local label=$1 sentence=$2 block=$3 keep=${4:-} current step number script status
  local attempt="$rec/attempt.sh" log="$rec/attempt.log"
  [[ -n "$sentence" && "$sentence" != *$'\n'* ]] || fail "a sentence is one non-empty line"
  while [[ "$block" == *$'\n' ]]; do block=${block%$'\n'}; done
  [[ -n "${block//[[:space:]]/}" ]] || fail "the block is empty"
  grep -q '^```[[:space:]]*$' <<< "$block" && fail "a block may not contain a line that closes a fence"
  current=$(current_step)
  if [[ "$label" == Preconditions ]]; then
    [[ -z "$current" ]] || fail "Preconditions are recorded already; undo every step to record them again, or start again"
    step="$rec/00"
  else
    [[ -n "$current" ]] || fail "record the Preconditions block first with rec.sh $feature pre"
    step_of "$label" > /dev/null && fail "step \"$label\" is recorded already; undo back to it, or start again"
    number=$(( 10#${current##*/} + 1 ))
    ((number <= 99)) || fail "a recording holds at most 99 steps"
    step=$(printf '%s/%02d' "$rec" "$number")
  fi
  printf '%s\n' "$block" > "$rec/block.sh"
  if script=$(calls_run_script "$rec/block.sh"); then
    fail "the block calls $script; recipes may not start, check or clean up the whole run"
  fi
  { echo "PS4='+[rec] '"; echo 'set -x'; cat "$rec/block.sh"; } > "$attempt"
  cp "$rec/state" "$rec/state.before"
  run_step "$rec/state" "$attempt" "$log"; status=$?
  { echo "== $label"; cat "$log"; } >> "$rec/log"
  tail -n +$(( $(wc -l < "$attempt") + 2 )) "$log" | sed '/^+*\[rec\] __drive_save$/,/^exit=/{/^exit=/!d}' > "$rec/output"
  if ((status == 0)); then sed '/^+*\[rec\] /d' "$rec/output"; else cat "$rec/output"; fi
  if ((status != 0)) && [[ -z "$keep" ]]; then
    mv "$rec/state.before" "$rec/state"
    echo "rec.sh: not recorded"
    exit $status
  fi
  mkdir -p "$step"
  printf '%s\n' "$label" > "$step/label"
  printf '%s\n' "$sentence" > "$step/sentence"
  mv "$rec/block.sh" "$step/block.sh"
  mv "$rec/state.before" "$step/state"
  if ((status != 0)); then
    echo "$status" > "$step/failed"
    echo "rec.sh: recorded \"$label\" although it failed (exit=$status); finish accepts it only as the last step before \"Clean up\""
  else
    echo "rec.sh: recorded \"$label\""
  fi
}

render() {
  local mark=${1:-} step label sentence separator=""
  for step in "$rec"/[0-9][0-9]; do
    label=$(< "$step/label")
    sentence=$(< "$step/sentence")
    [[ -n "$mark" && -f "$step/failed" ]] && sentence+=" (known failure)"
    printf '%s' "$separator"
    separator=$'\n'
    if [[ "$label" == Preconditions ]]; then echo "Preconditions: $sentence"; else echo "- **$label.** $sentence"; fi
    echo
    echo '```bash'
    cat "$step/block.sh"
    echo '```'
  done
}

remove_recording() {
  local entry
  for entry in "$rec"/*; do [[ "$entry" == "$staged" ]] || rm -rf "$entry"; done
}

if [[ "$action" == start ]]; then
  (($# == 0)) || usage start
  mkdir -p "$rec"
  remove_recording
  : > "$rec/state"
  if [[ -f "$staged" ]]; then
    echo "rec.sh: recording $feature; edit only the staged file $(relative "$staged"), kept from before"
  elif [[ -f "$target" ]]; then
    cp "$target" "$staged"
    echo "rec.sh: recording $feature; edit only the staged file $(relative "$staged")"
  else
    echo "rec.sh: recording $feature; finish --tool creates the staged file $(relative "$staged")"
  fi
  exit 0
fi
case "$action" in pre | step | undo | show | finish) ;; *) echo "$usage_all" >&2; exit 2 ;; esac
[[ -f "$rec/state" ]] || fail "no recording for $feature; run rec.sh $feature start first"
export PATH="$skill/bin:$PATH" VERIFY_SESSION=$feature

case "$action" in
  pre)
    (($# == 2)) || usage "pre <sentence> <block>"
    record Preconditions "$1" "$2"
    ;;
  step)
    keep=""
    [[ "${1:-}" == --keep ]] && { keep=1; shift; }
    (($# == 3)) || usage "step [--keep] <Label> <sentence> <block>"
    check_label "$1"
    record "$1" "$2" "$3" "$keep"
    ;;
  undo)
    (($# == 0)) || usage undo
    step=$(current_step)
    [[ -n "$step" ]] || fail "nothing recorded"
    mv "$step/state" "$rec/state"
    echo "rec.sh: removed \"$(< "$step/label")\" and restored the shell state from before it"
    rm -rf "$step"
    ;;
  show)
    (($# == 0)) || usage show
    render --mark
    ;;
  finish)
    tool=""
    if (($# == 2)) && [[ "$1" == --tool && -n "$2" ]]; then tool=$2; elif (($# != 0)); then usage "finish [--tool <tool>]"; fi
    problems=()
    [[ -d "$rec/00" ]] || problems+=("no Preconditions block")
    known=""
    for step in "$rec"/[0-9][0-9]; do
      label=$(< "$step/label")
      [[ -z "$known" || "$label" == "Clean up" ]] || problems+=("step \"$label\" comes after \"$known\", whose kept failure stops drive.sh before it; a known failure goes in the last step before \"Clean up\"")
      [[ -f "$step/failed" ]] || continue
      [[ "$label" == "Clean up" ]] && problems+=("\"Clean up\" keeps a failure; Clean up must pass")
      known=$label
    done
    current=$(current_step)
    [[ -n "$current" && "$(< "$current/label")" == "Clean up" ]] || problems+=("the last step is not \"Clean up\"")
    if [[ -f "$staged" ]]; then
      grep -q '^## Driving it with' "$staged" || problems+=("$(relative "$staged") has no \"## Driving it with\" section")
    else
      [[ -n "$tool" ]] || problems+=("$feature has no feature file yet; pass --tool <tool> to create it")
    fi
    if ((${#problems[@]})); then
      printf 'rec.sh: %s\n' "${problems[@]}" >&2
      exit 1
    fi
    render > "$rec/section.md"
    if [[ -f "$staged" ]]; then
      awk -v section="$rec/section.md" '
        /^## Driving it with/ && !done { print; print ""; while ((getline line < section) > 0) print line; skipping = 1; done = 1; next }
        skipping && /^## / { skipping = 0; print "" }
        !skipping { print }
      ' "$staged" > "$rec/written.md"
    else
      { echo "## Driving it with $tool"; echo; cat "$rec/section.md"; } > "$rec/written.md"
    fi
    rm -rf "$rec/check" && mkdir -p "$rec/check" && : > "$rec/check/steps"
    split_steps "$rec/written.md" "$rec/check"
    if ! diff <(cat "$rec"/[0-9][0-9]/label) <(cut -f2 "$rec/check/steps") > /dev/null; then
      fail "the written section does not parse back to the recorded labels; the staged file is unchanged (see $(relative "$rec/written.md"))"
    fi
    while IFS=$'\t' read -r step number; do
      cmp -s "$step/block.sh" "$rec/check/$number.sh" || fail "the block of step \"$(< "$step/label")\" does not parse back; the staged file is unchanged (see $(relative "$rec/written.md"))"
    done < <(paste <(printf '%s\n' "$rec"/[0-9][0-9]) <(cut -f1 "$rec/check/steps"))
    mv "$rec/written.md" "$staged"
    remove_recording
    echo "rec.sh: wrote the Driving section into $(relative "$staged")"
    ;;
esac
