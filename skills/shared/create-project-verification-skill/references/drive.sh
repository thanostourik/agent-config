#!/usr/bin/env bash
# drive.sh [--jobs N] [feature...]: run the bash blocks of feature recipes, N features at a time.
# drive.sh --check [feature...]: only list the steps drive.sh refuses to run and the findings rec.sh run refuses, coverage only when .cache/record/contract-map.tsv exists; exit 2 when there are any.
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
  dir="$work/$feature/run"
  mkdir -p "$dir" && : > "$dir/steps"
  split_steps "$skill/features/$feature.md" "$dir"
  checks=("$dir" "$skill/features/$feature.md")
  [[ -z "$check" ]] || checks+=("$feature" "$skill/.cache/record/contract-map.tsv")
  while IFS= read -r problem; do refusals+=("features/$feature.md: $problem"); done < <(check_steps "${checks[@]}")
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
  local feature=$1 dir="$work/$feature/run" logs="$work/$feature/steps" evidence="$skill/.cache/evidence/$feature"
  local number label block log status failed="" failed_log="" stopped="" ran="" cleanup="" cleanup_log=""
  : > "$dir/state"
  rm -rf "$evidence" && mkdir -p "$evidence" "$logs"
  export VERIFY_SESSION=$feature
  while IFS=$'\t' read -r -u 3 number label; do
    block="$dir/$number.sh"
    log="$logs/$number-$(slug "$label").log"
    if [[ "$label" == "Clean up" ]]; then cleanup=$block cleanup_log=$log; fi
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
      failed=$label failed_log=$log
    fi
  done 3< "$dir/steps"
  if [[ -n "$failed$stopped" && -n "$ran" && -n "$cleanup" && "$failed" != "Clean up" ]]; then
    if run_step "$dir/state" "$cleanup" "$cleanup_log"; then
      echo "$feature / Clean up: pass"
    else
      echo "$feature / Clean up: fail ($cleanup_log)"
      echo "$cleanup_log" > "$dir/cleanup-failed"
    fi
  fi
  if [[ -n "$failed" ]]; then
    printf '%s\t%s\n' "$failed" "$failed_log" > "$dir/failed"
    if [[ ! -e "$work/stop" ]]; then
      "$skill/bin/doctor.sh" 2>&1 < /dev/null 3<&- | tee "$logs/doctor.log" > /dev/null
      if ((PIPESTATUS[0])); then
        echo "doctor failed after $feature ($logs/doctor.log); stopping the run"
        echo "$feature" > "$work/stop"
      fi
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
  dir="$work/$feature/run"
  if [[ -e "$dir/failed" ]]; then
    IFS=$'\t' read -r label log < "$dir/failed"
    echo "$feature: fail at \"$label\" ($log)"
  elif [[ ! -e "$dir/done" ]]; then
    if [[ -s "$work/stop" ]]; then
      echo "$feature: not run (doctor failed after $(head -n 1 "$work/stop"))"
    else
      echo "$feature: not run (run stopped)"
    fi
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
rm -rf "$work"/*/run "$work/stop"
exit $result
