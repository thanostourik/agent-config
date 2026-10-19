#!/usr/bin/env bash
# drive.sh [--jobs N] [feature...]: run the bash blocks of feature recipes, N features at a time.
# drive.sh --check [feature...]: only list the steps drive.sh refuses to run; exit 2 when there are any.
set -uo pipefail

skill=$(cd "$(dirname "$0")/.." && pwd)
cd "$skill/../../.."
max_jobs=1 check=""
if [[ "${1:-}" == --check ]]; then check=1; shift
elif [[ "${1:-}" == --jobs ]]; then max_jobs=${2:?--jobs needs a number}; shift 2; fi
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
if [[ -n "$check" ]]; then
  work=$(mktemp -d)
else
  work="$skill/.cache/drive"
  rm -rf "$work"
  mkdir -p "$work"
fi
source "$skill/bin/steps.sh"

refusals=()
for feature in "${features[@]}"; do
  dir="$work/$feature"
  mkdir -p "$dir" && : > "$dir/steps"
  split_steps "$skill/features/$feature.md" "$dir"
  while IFS=$'\t' read -r number label; do
    if [[ ! -f "$dir/$number.sh" ]]; then
      refusals+=("features/$feature.md: step \"$label\" has no bash block; convert the recipe before driving")
    elif script=$(calls_run_script "$dir/$number.sh"); then
      refusals+=("features/$feature.md: step \"$label\" calls $script; recipes may not start, check or clean up the whole run")
    fi
  done < "$dir/steps"
done
if ((${#refusals[@]})); then
  printf 'drive.sh: %s\n' "${refusals[@]}" >&2
  rm -rf "$work"
  exit 2
fi
if [[ -n "$check" ]]; then
  rm -rf "$work"
  exit 0
fi

drive_feature() {
  local feature=$1 dir="$work/$feature" evidence="$skill/.cache/evidence/$feature/steps"
  local number label block log status failed="" stopped="" ran="" cleanup=""
  : > "$dir/state"
  rm -rf "$skill/.cache/evidence/$feature" && mkdir -p "$evidence"
  export VERIFY_SESSION=$feature
  while IFS=$'\t' read -r -u 3 number label; do
    block="$dir/$number.sh"
    log="$evidence/$number-$(tr 'A-Z' 'a-z' <<< "$label" | tr -cs 'a-z0-9' '-' | sed 's/-$//').log"
    if [[ "$label" == "Clean up" ]]; then cleanup="$block	$log"; fi
    [[ -e "$work/stop" ]] && stopped=1
    if [[ -n "$failed$stopped" ]]; then
      [[ "$label" == "Clean up" ]] || echo "$label" >> "$dir/not-run"
      continue
    fi
    run_step "$dir/state" "$block" "$log"; status=$?
    ran=1
    if ((status == 0)); then
      echo "$feature / $label: pass"
    else
      echo "$feature / $label: fail ($log)"
      failed="$label	$log"
    fi
  done 3< "$dir/steps"
  if [[ -n "$failed$stopped" && -n "$ran" && -n "$cleanup" && "${failed%%	*}" != "Clean up" ]]; then
    if run_step "$dir/state" "${cleanup%%	*}" "${cleanup#*	}"; then
      echo "$feature / Clean up: pass"
    else
      echo "$feature / Clean up: fail (${cleanup#*	})"
      echo "${cleanup#*	}" > "$dir/cleanup-failed"
    fi
  fi
  if [[ -n "$failed" ]]; then
    echo "$failed" > "$dir/failed"
    if [[ ! -e "$work/stop" ]] && ! "$skill/bin/doctor.sh" > "$evidence/doctor.log" 2>&1 < /dev/null 3<&-; then
      echo "doctor failed after $feature ($evidence/doctor.log); stopping the run"
      : > "$work/stop"
    fi
  fi
  : > "$dir/done"
}

alone=() together=()
for feature in "${features[@]}"; do
  if awk '/^## Driving it with/ { d = 1 } d && /^- \*\*/ { exit } d && /Runs alone/ { found = 1 } END { exit !found }' "$skill/features/$feature.md"; then
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
  [[ -e "$dir/cleanup-failed" ]] && echo "  clean up: fail ($(cat "$dir/cleanup-failed"))"
done
rm -rf "$work"
exit $result
