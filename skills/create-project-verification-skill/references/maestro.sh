#!/usr/bin/env bash
# maestro.sh <maestro command> [args]: Maestro on the run's Android emulator, for example `maestro.sh test flow.yaml`.
# `maestro.sh flow [name] <<'EOF'` runs the flow commands on stdin against $MAESTRO_APP_ID, so a recipe step keeps its
# flow inline.
# Maestro always uses the ADB server on port 5037 and forwards its driver through port 7001. It runs here in a private
# network namespace whose port 5037 leads to the run's ADB server ($ANDROID_ADB_SERVER_PORT) and whose emulator ports lead
# to the run's emulator ($ANDROID_SERIAL, emulator-<port>), so it never starts or uses another ADB server. `test` writes
# screenshots and debug output under $VERIFY_DIR. Each call costs 5 to 7 s to start: put a step's taps and checks in one
# flow. The Maestro version is in ../maestro-version; the first call downloads it under .cache/ and checks its checksum.
# Needs Java 17+, socat and unprivileged user namespaces. Shipped by create-project-verification-skill; never edit it in
# the project.
set -euo pipefail
: "${VERIFY_SKILL:=$(cd "$(dirname "$0")/.." && pwd)}"
cache=$VERIFY_SKILL/.cache
: "${VERIFY_SESSION:=manual}"
: "${VERIFY_DIR:=$cache/manual/$VERIFY_SESSION}"
: "${ANDROID_ADB_SERVER_PORT:?maestro.sh: env.sh must export the run ADB server port}"
: "${ANDROID_SERIAL:?maestro.sh: env.sh must export the run emulator serial, emulator-<port>}"
mkdir -p "$VERIFY_DIR"
version=$(cat "$VERIFY_SKILL/maestro-version")
install=$cache/maestro-$version
if [[ ! -x $install/maestro/bin/maestro ]]; then
  (
    flock 8
    [[ -x $install/maestro/bin/maestro ]] && exit 0
    download=$(mktemp -d "$cache/maestro-download.XXXXXX")
    trap 'rm -rf "$download"' EXIT
    url=https://github.com/mobile-dev-inc/maestro/releases/download/cli-$version
    curl -fsSL --max-time 300 -o "$download/maestro.zip" "$url/maestro.zip"
    curl -fsSL --max-time 60 -o "$download/checksums_sha256.txt" "$url/checksums_sha256.txt"
    (cd "$download" && grep ' maestro.zip$' checksums_sha256.txt | sha256sum -c --quiet -)
    unzip -q "$download/maestro.zip" -d "$download/unpacked"
    mv "$download/unpacked" "$install"
  ) 8> "$cache/maestro-install.lock"
fi

emulator_port=${ANDROID_SERIAL#emulator-}
sockets=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/verify-maestro.XXXXXX")
bridges=()
trap 'kill "${bridges[@]}" 2> /dev/null; rm -rf "$sockets"' EXIT
bridge() {
  socat UNIX-LISTEN:"$sockets/$1",fork TCP:127.0.0.1:"$2" 2> /dev/null &
  bridges+=($!)
}
bridge 5037 "$ANDROID_ADB_SERVER_PORT"
bridge "$emulator_port" "$emulator_port"
bridge $((emulator_port + 1)) $((emulator_port + 1))
for port in 5037 "$emulator_port" $((emulator_port + 1)); do
  until [[ -S $sockets/$port ]]; do sleep 0.05; done
done

args=("$@")
if [[ ${1:-} == flow ]]; then
  : "${MAESTRO_APP_ID:?maestro.sh: env.sh must export the app id}"
  flow=$(mktemp "$VERIFY_DIR/flow-${2:-step}.XXXXXX.yaml")
  { printf 'appId: %s\n---\n' "$MAESTRO_APP_ID"; cat; } > "$flow"
  args=(test "$flow")
fi
[[ ${args[0]:-} == test ]] && args=(test --test-output-dir "$VERIFY_DIR" --debug-output "$VERIFY_DIR/maestro-debug" --flatten-debug-output "${args[@]:1}")
export SOCKETS=$sockets MAESTRO=$install/maestro/bin/maestro
export JAVA_TOOL_OPTIONS="-Duser.home=$cache/maestro-home" MAESTRO_CLI_NO_ANALYTICS=1 MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
start=$(date +%s.%N)
status=0
# Inside the namespace the process is root, so Java would use /root as its home; JAVA_TOOL_OPTIONS points it at .cache.
unshare --user --map-root-user --net bash -c '
  ip link set lo up
  inner=()
  for socket in "$SOCKETS"/*; do
    socat TCP-LISTEN:"${socket##*/}",bind=127.0.0.1,fork,reuseaddr UNIX-CONNECT:"$socket" 2> /dev/null &
    inner+=($!)
  done
  trap "kill ${inner[*]} 2> /dev/null" EXIT
  for socket in "$SOCKETS"/*; do
    until (exec 3<> "/dev/tcp/127.0.0.1/${socket##*/}") 2> /dev/null; do sleep 0.05; done
  done
  "$MAESTRO" --device "$ANDROID_SERIAL" "$@" 2>&1 | grep -v "^Picked up JAVA_TOOL_OPTIONS"
  exit "${PIPESTATUS[0]}"' maestro "${args[@]}" || status=$?
LC_ALL=C printf '%s %.1fs %s\n' "$(date +%T)" "$(echo "$(date +%s.%N) - $start" | bc)" "${args[*]:0:2}" | cut -c1-300 >> "$VERIFY_DIR/maestro-calls.log"
exit "$status"
