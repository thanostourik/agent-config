#!/usr/bin/env bash
# steps.sh: sourced by drive.sh and rec.sh; split_steps <feature file> <dir>, check_steps <dir> [<feature file> <feature> <contract map>], run_step <state> <block> <log>, calls_run_script <block>, fixture_names <file>...

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

check_steps() {
  local number label script syntax finding
  while IFS=$'\t' read -r number label; do
    if [[ ! -f "$1/$number.sh" ]]; then
      echo "step \"$label\" has no bash block; convert the recipe before driving"
      continue
    elif script=$(calls_run_script "$1/$number.sh"); then
      echo "step \"$label\" calls $script; recipes may not start, check or clean up the whole run"
    elif ! syntax=$(bash -n "$1/$number.sh" 2>&1); then
      syntax=$(head -n 1 <<< "$syntax")
      echo "step \"$label\" is not valid bash: ${syntax#"$1/$number.sh: "}"
    fi
    [[ -n "${3:-}" ]] || continue
    while IFS= read -r finding; do echo "step \"$label\" $finding"; done < <(lint_block "$1/$number.sh" "$3")
  done < "$1/steps"
  [[ -z "${3:-}" || ! -f "${4:-}" ]] || check_contract "$2" "$1/steps" "$3" "$4"
}

lint_block() {
  local first=${2%%[^A-Za-z0-9]*} name rest
  first=${first,,}
  awk '
    /waitForTimeout\(/ { waits["waitForTimeout"] }
    /(^|[^A-Za-z0-9_.\/-])sleep([[:space:]]|$)/ { waits["sleep"] }
    index($0, ".first()") { first = 1 }
    {
      line = $0
      while (match(line, /timeout:[[:space:]]*[0-9]+/)) {
        n = substr(line, RSTART, RLENGTH); sub(/^timeout:[[:space:]]*/, "", n)
        if (n + 0 < 5000 && !(n in short)) { short[n]; print "sets timeout: " n "; a timeout is at least 5000" }
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END {
      for (w in waits) print "waits with " w "; wait for the expected state instead"
      if (first) print "uses .first(); target the element by its role and name"
    }
  ' "$1"
  while IFS= read -r name; do
    if [[ "$name" == verify-* ]]; then rest=${name#verify-}; else rest=${name#Verify }; fi
    rest=${rest,,}
    [[ "$rest" == "$first" || "$rest" == "$first"[^a-z0-9]* ]] ||
      echo "names \"$name\"; a fixture name continues with the feature name: verify-$2-… or Verify ${first^} …"
  done < <(fixture_names "$1")
}

fixture_names() {
  awk '
    {
      line = $0
      while (match(line, /["\047`=](verify-|Verify )/)) {
        quote = substr(line, RSTART, 1)
        line = substr(line, RSTART + 1)
        end = quote == "=" ? match(line, /[[:space:]"\047`]/) : index(line, quote)
        name = end ? substr(line, 1, end - 1) : line
        if (!(name in seen)) { seen[name]; print name }
        line = end ? substr(line, end + 1) : ""
      }
    }
  ' "$@"
}

check_contract() {
  awk -F '\t' -v feature="$3" -v arrow=" → " '
    FILENAME == ARGV[1] { if ($1 == feature && !($2 in mapped)) { mapped[$2]; order[++n] = $2 }; next }
    FILENAME == ARGV[2] { steps[$2]; next }
    /^## / { contract = $0 == "## Contract"; next }
    !contract || !/^- / { next }
    {
      line = substr($0, 3)
      if (!(i = index(line, arrow))) { print "## Contract line \"" $0 "\" has no \"" arrow "\""; next }
      section = substr(line, 1, i - 1); target = substr(line, i + length(arrow))
      covered[section]
      if (target ~ /^not driven/) {
        if (target !~ /^not driven:[[:space:]]*[^[:space:]]/) print "## Contract line for " section " says not driven without a reason"
        next
      }
      if (target in steps) next
      k = split(target, labels, ",")
      for (j = 1; j <= k; j++) {
        label = labels[j]; gsub(/\*\*/, "", label); sub(/^[[:space:]]+/, "", label); sub(/[[:space:].]+$/, "", label)
        if (!(label in steps)) print "## Contract line for " section " names \"" label "\", which is no step of the Driving section"
      }
    }
    END { for (j = 1; j <= n; j++) if (!(order[j] in covered)) print "contract section " order[j] " has no line in ## Contract" }
  ' "$4" "$2" "$1"
}

run_step() {
  local state=$1 block=$2 log=$3 status
  { cat "$block"; echo "---"; } > "$log"
  timeout --kill-after=10 "$step_timeout" bash -c '
    __drive_state=$1 __drive_block=$2
    set --
    __drive_vars=$(compgen -v | sort) __drive_funcs=$(compgen -A function | sort)
    __drive_save() {
      set +eu
      {
        comm -13 <(echo "$__drive_vars") <(compgen -v | sort) | grep -v "^__drive_" | while read -r __drive_name; do declare -p "$__drive_name"; done
        comm -13 <(echo "$__drive_funcs") <(compgen -A function | sort) | grep -v "^__drive_" | while read -r __drive_name; do declare -f "$__drive_name"; done
      } > "$__drive_state.new"
      mv "$__drive_state.new" "$__drive_state"
      exit $__drive_status
    }
    trap "{ __drive_status=\$?; set +x; } 2> /dev/null; __drive_save" EXIT
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
  awk '
    {
      n = split($0, commands, /[;&|(`]/)
      for (i = 1; i <= n; i++) {
        command = commands[i]
        sub(/^[[:space:]]+/, "", command)
        while (match(command, /^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|bash|sh|source|\.|exec|env|nohup|setsid|sudo|timeout([[:space:]]+--kill-after=[0-9.]+[smhd]?)?[[:space:]]+[0-9.]+[smhd]?)[[:space:]]+/))
          command = substr(command, RLENGTH + 1)
        sub(/^["\047]/, "", command)
        sub(/["\047[:space:])].*/, "", command)
        sub(/.*\//, "", command)
        if (command ~ /^(launch|cleanup|doctor)\.sh$/) { print command; found = 1; exit }
      }
    }
    END { exit !found }
  ' "$1"
}
