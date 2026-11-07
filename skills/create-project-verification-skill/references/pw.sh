#!/usr/bin/env bash
# pw.sh <playwright-cli command> [args]: the Playwright CLI in this feature's browser session ($VERIFY_SESSION).
# Every session of a run is a context of its own (cookies, storage) in one shared browser. `pw.sh open [url]` attaches
# one; every run-code function ends by loading a hidden frame of the page's origin, so the CLI stops waiting for requests
# at once. Output is raw; an error arrives as "### Error" on stdout and exits 1. The Playwright version is in ../pw-version.
# Shipped by create-project-verification-skill; never edit it in the project. bin/pw-close closes sessions.
set -uo pipefail
: "${VERIFY_SKILL:=$(cd "$(dirname "$0")/.." && pwd)}"
cache=$VERIFY_SKILL/.cache
: "${VERIFY_RUN_ID:=$(cat "$cache/run-id" 2> /dev/null || echo manual)}"
: "${VERIFY_SESSION:=manual}"
: "${VERIFY_DIR:=$cache/manual/$VERIFY_SESSION}"
mkdir -p "$VERIFY_DIR" "$cache/pw-out" "$cache/pw-idle"
modules=$cache/pw/node_modules
cli=$modules/playwright-core/lib/tools/cli-client/cli.js
if [[ ! -f $cli ]]; then
  (flock 8 && { [[ -f $cli ]] || npm install --silent --prefix "$cache/pw" "playwright@$(cat "$VERIFY_SKILL/pw-version")" > /dev/null; }) 8> "$cache/pw-install.lock" || exit 1
fi
session=$VERIFY_RUN_ID-$VERIFY_SESSION
cli_in() { (cd "$cache/pw-out" && node "$cli" -s="$1" "${@:2}" 2>&1); }

for marker in "$cache/pw-idle"/*; do
  [[ -f $marker ]] && ((EPOCHSECONDS - $(stat -c %Y "$marker") > 120)) || continue
  cli_in "${marker##*/}" close > /dev/null
  rm -f "$marker"
done

# A server whose endpoint stops answering is replaced; every server's pid is kept so pw-close stops them all.
endpoint() {
  local base=$cache/pw-server-$VERIFY_RUN_ID ws port until=$((SECONDS + 30))
  exec 9> "$base.lock"
  flock 9
  if [[ -s $base.ws ]]; then
    ws=$(cat "$base.ws") port=${ws#ws://*:} port=${port%%/*}
    if (exec 3<> "/dev/tcp/127.0.0.1/$port") 2> /dev/null; then echo "$ws"; exec 9>&-; return; fi
  fi
  NODE_PATH=$modules setsid node -e "require('playwright-core').chromium.launchServer({ host: '127.0.0.1' }).then(s => console.log(s.wsEndpoint()))" \
    > "$base.out" 2>&1 < /dev/null 9>&- &
  echo $! >> "$base.pids"
  until grep -q '^ws://' "$base.out" 2> /dev/null; do
    ((SECONDS < until)) || { echo "### Error"; echo "pw.sh: the browser server did not start: $(cat "$base.out")"; exec 9>&-; return 1; }
    sleep 0.2
  done
  grep -m1 '^ws://' "$base.out" > "$base.ws"
  cat "$base.ws"
  exec 9>&-
}

args=("$@")
if [[ ${1:-} == run-code ]]; then
  args=(run-code "async page => { try { return await ($2)(page); } finally { await page.evaluate(() => { const frame = document.createElement('iframe'); frame.hidden = true; frame.src = '/favicon.ico?verify-settle=' + Date.now(); document.body.append(frame); }).catch(() => {}); } }" "${@:3}")
fi
start=$(date +%s.%N)
if [[ ${1:-} == open ]]; then
  [[ -z ${VERIFY_FEATURE:-} ]] && "$VERIFY_SKILL/bin/verify" room
  grep -qxF "$session" "$VERIFY_DIR/pw-sessions" 2> /dev/null || echo "$session" >> "$VERIFY_DIR/pw-sessions"
  grep -qxF "$session" "$cache/pw-sessions-$VERIFY_RUN_ID" 2> /dev/null || echo "$session" >> "$cache/pw-sessions-$VERIFY_RUN_ID"
  ws=$(endpoint) || { echo "$ws"; exit 1; }
  out=$(cli_in "$session" attach --endpoint="$ws")
  # attach, unlike open, does not grant clipboard-write; a Copy button's check fails without it
  out+=$'\n'$(cli_in "$session" --raw run-code "async page => page.context().grantPermissions(['clipboard-write'])")
  [[ -n ${2:-} && $2 != about:blank ]] && out+=$'\n'$(cli_in "$session" --raw goto "$2")
  status=0
else
  out=$(cli_in "$session" --raw "${args[@]}")
  status=$?
fi
[[ -z ${VERIFY_FEATURE:-} ]] && touch "$cache/pw-idle/$session"
LC_ALL=C printf '%s %.1fs %s\n' "$(date +%T)" "$(echo "$(date +%s.%N) - $start" | bc)" "${args[*]:0:2}" | tr '\n' ' ' | cut -c1-300 >> "$VERIFY_DIR/pw-calls.log"
echo >> "$VERIFY_DIR/pw-calls.log"
if [[ ${1:-} == open ]]; then printf '%s\n' "$out" > "$VERIFY_DIR/pw-open.out"; else printf '%s\n' "$out"; fi
if grep -q '^### Error' <<< "$out"; then
  [[ ${1:-} == open ]] && cat "$VERIFY_DIR/pw-open.out"
  exit 1
fi
exit "$status"
