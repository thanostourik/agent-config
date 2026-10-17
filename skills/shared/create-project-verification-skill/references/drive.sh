#!/usr/bin/env bash
# drive.sh [--jobs N] [feature...]: run the bash blocks of feature recipes, N features at a time.
set -uo pipefail

skill=$(cd "$(dirname "$0")/.." && pwd)
cd "$skill/../../.."
max_jobs=1
if [[ "${1:-}" == --jobs ]]; then max_jobs=${2:?--jobs needs a number}; shift 2; fi
[[ "$max_jobs" =~ ^[1-9][0-9]*$ ]] || { echo "drive.sh: --jobs must be a positive number" >&2; exit 2; }

features=("$@")
if ((${#features[@]} == 0)); then
  for file in "$skill"/features/*.md; do
    [[ "$(basename "$file")" == README.md ]] || features+=("$(basename "$file" .md)")
  done
fi
for feature in "${features[@]}"; do
  [[ -f "$skill/features/$feature.md" ]] || { echo "drive.sh: no feature file features/$feature.md" >&2; exit 2; }
done

export PATH="$skill/bin:$PATH"
work="$skill/.cache/drive"
rm -rf "$work"
mkdir -p "$work"
step_timeout=600

split_steps() {
  awk -v out="$2" '
    function start(label) { n++; file = sprintf("%s/%02d.sh", out, n); printf "%02d\t%s\n", n, label > (out "/steps") }
    /^## Driving it with/ { driving = 1; next }
    driving && /^## / { driving = 0 }
    !driving { next }
    in_block { if ($0 ~ /^```[[:space:]]*$/) in_block = 0; else print > file; next }
    /^Preconditions:/ { start("Preconditions"); next }
    /^- \*\*/ { label = $0; sub(/^- \*\*/, "", label); sub(/\*\*.*/, "", label); sub(/\.$/, "", label); start(label); next }
    /^```bash[[:space:]]*$/ && n { in_block = 1; printf "" > file }
  ' "$1"
}

run_step() {
  local state=$1 block=$2 log=$3 status
  { cat "$block"; echo "---"; } > "$log"
  timeout --kill-after=10 "$step_timeout" bash -c '
    __drive_state=$1 __drive_block=$2
    set --
    __drive_vars=$(compgen -v | sort) __drive_funcs=$(compgen -A function | sort)
    source "$__drive_state"
    set -euo pipefail
    source "$__drive_block"
    set +eu
    {
      comm -13 <(echo "$__drive_vars") <(compgen -v | sort) | grep -v "^__drive_" | while read -r name; do declare -p "$name"; done
      comm -13 <(echo "$__drive_funcs") <(compgen -A function | sort) | while read -r name; do declare -f "$name"; done
    } > "$__drive_state.new"
    mv "$__drive_state.new" "$__drive_state"
  ' _ "$state" "$block" >> "$log" 2>&1
  status=$?
  echo "exit=$status" >> "$log"
  ((status == 124)) && echo "timed out after ${step_timeout}s" >> "$log"
  return $status
}

drive_feature() {
  local feature=$1 dir="$work/$feature" evidence="$skill/.cache/evidence/$feature/steps"
  local number label block log status failed="" stopped="" ran="" cleanup=""
  mkdir -p "$dir" && : > "$dir/state" && : > "$dir/steps"
  rm -rf "$evidence" && mkdir -p "$evidence"
  split_steps "$skill/features/$feature.md" "$dir"
  export VERIFY_SESSION=$feature
  while IFS=$'\t' read -r number label; do
    block="$dir/$number.sh"
    log="$evidence/$number-$(tr 'A-Z' 'a-z' <<< "$label" | tr -cs 'a-z0-9' '-' | sed 's/-$//').log"
    if [[ "$label" == "Clean up" ]]; then cleanup="$block	$log"; fi
    [[ -e "$work/stop" ]] && stopped=1
    if [[ -n "$failed$stopped" ]]; then
      [[ "$label" == "Clean up" ]] || echo "$label" >> "$dir/not-run"
      continue
    fi
    if [[ ! -f "$block" ]]; then
      echo "no bash block under this step" > "$log"; status=1
    else
      run_step "$dir/state" "$block" "$log"; status=$?
    fi
    ran=1
    if ((status == 0)); then
      echo "$feature / $label: pass"
    else
      echo "$feature / $label: fail ($log)"
      failed="$label	$log"
    fi
  done < "$dir/steps"
  if [[ -n "$failed$stopped" && -n "$ran" && -n "$cleanup" && "${failed%%	*}" != "Clean up" ]]; then
    if run_step "$dir/state" "${cleanup%%	*}" "${cleanup#*	}"; then
      echo "$feature / Clean up: pass"
    else
      echo "$feature / Clean up: fail (${cleanup#*	})"
    fi
  fi
  if [[ -n "$failed" ]]; then
    echo "$failed" > "$dir/failed"
    if [[ ! -e "$work/stop" ]] && ! "$skill/bin/doctor.sh" > "$evidence/doctor.log" 2>&1; then
      echo "doctor failed after $feature ($evidence/doctor.log); stopping the run"
      : > "$work/stop"
    fi
  fi
  : > "$dir/done"
}

alone=() together=()
for feature in "${features[@]}"; do
  if awk '/^## Driving it with/ { d = 1 } d && /^- \*\*/ { exit } d && /Runs alone\./ { found = 1 } END { exit !found }' "$skill/features/$feature.md"; then
    alone+=("$feature")
  else
    together+=("$feature")
  fi
done

for feature in "${together[@]}"; do
  while (($(jobs -rp | wc -l) >= max_jobs)); do wait -n; done
  [[ -e "$work/stop" ]] && break
  drive_feature "$feature" &
done
wait
for feature in "${alone[@]}"; do
  [[ -e "$work/stop" ]] && break
  drive_feature "$feature"
done

echo
echo "Summary"
result=0
for feature in "${features[@]}"; do
  dir="$work/$feature"
  if [[ -e "$dir/failed" ]]; then
    IFS=$'\t' read -r label log < "$dir/failed"
    echo "$feature: fail at \"$label\" ($log)"
  elif [[ ! -e "$dir/done" ]]; then
    echo "$feature: not run"
  elif [[ -e "$dir/not-run" ]]; then
    echo "$feature: stopped"
  else
    echo "$feature: pass"
    continue
  fi
  result=1
  [[ -e "$dir/not-run" ]] && echo "  not run: $(paste -sd ',' "$dir/not-run" | sed 's/,/, /g')"
done
exit $result
