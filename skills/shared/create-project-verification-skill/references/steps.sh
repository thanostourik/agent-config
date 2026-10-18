#!/usr/bin/env bash
# steps.sh: sourced by drive.sh and rec.sh; split_steps <feature file> <dir>, run_step <state> <block> <log>, calls_run_script <block>.

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
    __drive_save() {
      local __drive_status=$?
      set +eu
      {
        comm -13 <(echo "$__drive_vars") <(compgen -v | sort) | grep -v "^__drive_" | while read -r name; do declare -p "$name"; done
        comm -13 <(echo "$__drive_funcs") <(compgen -A function | sort) | grep -v "^__drive_" | while read -r name; do declare -f "$name"; done
      } > "$__drive_state.new"
      mv "$__drive_state.new" "$__drive_state"
      exit $__drive_status
    }
    trap __drive_save EXIT
    source "$__drive_state"
    set -euo pipefail
    source "$__drive_block"
  ' _ "$state" "$block" >> "$log" 2>&1 < /dev/null 3<&-
  status=$?
  echo "exit=$status" >> "$log"
  ((status == 124)) && echo "timed out after ${step_timeout}s" >> "$log"
  return $status
}

calls_run_script() {
  grep -Ewo -m1 '(launch|cleanup|doctor)\.sh' "$1" | head -n1
}
