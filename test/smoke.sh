#!/bin/bash
#
# Lightweight smoke tests for Codex Alarm.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

export CODEX_HOME="$TMP_ROOT/codex"
export CODEX_ALARM_HOME="$CODEX_HOME/alarm"
export CODEX_ALARM_DRY_RUN=1

echo "version"
"$ROOT/bin/alarm" version | grep -q '^0\.1\.0$'

echo "test notification dry-run"
"$ROOT/bin/alarm" test 2>&1 | grep -q 'Codex Alarm test'

echo "hook dry-runs"
printf '{"cwd":"/tmp/project","last_assistant_message":"Done"}' | "$ROOT/bin/alarm" stop 2>&1 | grep -q 'Codex finished'
printf '{"cwd":"/tmp/project","tool_name":"Bash","tool_input":{"description":"Run tests"}}' | "$ROOT/bin/alarm" permission 2>&1 | grep -q 'Codex needs approval'

echo "backend and sound dry-runs"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping "$ROOT/bin/alarm" test 2>&1 | grep -q '"backend":"osascript"'
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":"Ping"'

mkdir -p "$TMP_ROOT/bin"
printf '#!/bin/sh\nexit 0\n' > "$TMP_ROOT/bin/terminal-notifier"
chmod +x "$TMP_ROOT/bin/terminal-notifier"
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=auto "$ROOT/bin/alarm" test 2>&1 | grep -q '"backend":"terminal-notifier"'
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_ACTIVATE_BUNDLE_ID=com.apple.Terminal "$ROOT/bin/alarm" test 2>&1 | grep -q '"activateBundleId":"com.apple.Terminal"'

mkdir -p "$CODEX_ALARM_HOME"
printf 'CODEX_ALARM_SOUND="Submarine"\n' > "$CODEX_ALARM_HOME/config"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":"Submarine"'
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":"Ping"'

echo "install"
"$ROOT/install.sh" --yes
test -x "$CODEX_ALARM_HOME/alarm"
test -f "$CODEX_ALARM_HOME/config"
test -f "$CODEX_HOME/hooks.json"
grep -q 'Codex Alarm:' "$CODEX_HOME/hooks.json"

echo "doctor"
"$CODEX_ALARM_HOME/alarm" doctor >/dev/null

echo "uninstall"
"$ROOT/uninstall.sh" --yes
test ! -e "$CODEX_ALARM_HOME/alarm"
if [ -f "$CODEX_HOME/hooks.json" ]; then
  if grep -q 'Codex Alarm:' "$CODEX_HOME/hooks.json"; then
    echo "Codex Alarm hooks still present after uninstall" >&2
    exit 1
  fi
fi

echo "ok"
