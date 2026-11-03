#!/usr/bin/env bash
# lib.sh <recipe>: run one feature recipe for bin/verify. Shipped by create-project-verification-skill; never edit it in the project.
# A recipe gets: step <label>, wait_for <seconds> <command...>, a cleanup function it may define, $EVIDENCE, $VERIFY_FEATURE, $VERIFY_RUN_ID, bin/ on PATH.
set -Eeuo pipefail
cd "$VERIFY_ROOT"
export PATH="$VERIFY_SKILL/bin:$PATH"
verify_step=Start

step() {
  verify_step=$1
  printf '%s\n' "$1" > "$VERIFY_DIR/step"
  printf '\n== %s (%ss)\n' "$1" "$SECONDS"
}

wait_for() {
  local seconds=$1 out=$VERIFY_DIR/wait.out
  shift
  local until=$((SECONDS + seconds))
  until "$@" > "$out" 2>&1; do
    if ((SECONDS >= until)); then
      echo "wait_for: not met within ${seconds}s: $*"
      tail -n 20 "$out"
      return 1
    fi
    sleep 0.5
  done
  cat "$out"
}

cleanup() { :; }

verify_end() {
  local status=$? cleanup_status
  trap - EXIT TERM INT ERR
  set +e
  if ((status)); then
    printf 'fail\n' > "$VERIFY_DIR/result"
    [[ -x "$VERIFY_SKILL/bin/observe.sh" ]] && timeout 30 "$VERIFY_SKILL/bin/observe.sh" "$EVIDENCE/failure.txt" > /dev/null 2>&1
  else
    printf 'pass\n' > "$VERIFY_DIR/result"
  fi
  printf '\n== Clean up (%ss)\n' "$SECONDS"
  (set -e; cleanup)
  cleanup_status=$?
  if [[ -x "$VERIFY_SKILL/bin/after-feature.sh" ]]; then
    timeout 60 "$VERIFY_SKILL/bin/after-feature.sh" || cleanup_status=1
  fi
  ((cleanup_status == 0)) || printf 'cleanup-failed\n' >> "$VERIFY_DIR/result"
  exit "$status"
}

trap 'printf "%s (line %s, exit %s)\n" "$BASH_COMMAND" "$LINENO" "$?" > "$VERIFY_DIR/error"' ERR
trap verify_end EXIT
trap 'exit 143' TERM INT
[[ -f "$VERIFY_SKILL/bin/env.sh" ]] && source "$VERIFY_SKILL/bin/env.sh"
source "$1"
