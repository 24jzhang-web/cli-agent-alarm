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

line_count() {
  wc -l < "$1" | tr -d '[:space:]'
}

echo "version"
"$ROOT/bin/alarm" version | grep -q '^0\.1\.0$'

echo "test notification dry-run"
"$ROOT/bin/alarm" test 2>&1 | grep -q 'Codex Alarm test'

echo "hook dry-runs"
printf '{"cwd":"/tmp/project","last_assistant_message":"Done"}' | "$ROOT/bin/alarm" stop 2>&1 | grep -q 'Codex finished'
printf '{"cwd":"/tmp/project","tool_name":"Bash","tool_input":{"description":"Run tests"}}' | "$ROOT/bin/alarm" permission 2>&1 | grep -q 'Codex needs approval'

echo "config defaults and event toggles"
rm -f "$CODEX_ALARM_HOME/config"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":"Glass"'
mkdir -p "$CODEX_ALARM_HOME"
printf 'CODEX_ALARM_NOTIFY_ON_STOP="0"\nCODEX_ALARM_NOTIFY_ON_PERMISSION="1"\n' > "$CODEX_ALARM_HOME/config"
if printf '{"cwd":"/tmp/project","last_assistant_message":"Done"}' | PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript "$ROOT/bin/alarm" stop 2>&1 | grep -q .; then
  echo "stop notification was not disabled by config" >&2
  exit 1
fi
printf '{"cwd":"/tmp/project","tool_name":"Bash","tool_input":{"description":"Run tests"}}' | PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript "$ROOT/bin/alarm" permission 2>&1 | grep -q 'Codex needs approval'
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_NOTIFY_ON_STOP=1 "$ROOT/bin/alarm" stop 2>&1 | grep -q 'Codex finished'

printf 'CODEX_ALARM_NOTIFY_ON_STOP="1"\nCODEX_ALARM_NOTIFY_ON_PERMISSION="0"\n' > "$CODEX_ALARM_HOME/config"
if printf '{"cwd":"/tmp/project","tool_name":"Bash","tool_input":{"description":"Run tests"}}' | PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript "$ROOT/bin/alarm" permission 2>&1 | grep -q .; then
  echo "permission notification was not disabled by config" >&2
  exit 1
fi
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_NOTIFY_ON_PERMISSION=1 "$ROOT/bin/alarm" permission 2>&1 | grep -q 'Codex needs approval'

echo "backend and sound dry-runs"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping "$ROOT/bin/alarm" test 2>&1 | grep -q '"backend":"osascript"'
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":"Ping"'

mkdir -p "$TMP_ROOT/bin"
notifier_log="$TMP_ROOT/terminal-notifier.log"
printf '#!/bin/sh\nprintf "notify\\n" >> "%s"\n' "$notifier_log" > "$TMP_ROOT/bin/terminal-notifier"
chmod +x "$TMP_ROOT/bin/terminal-notifier"
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=auto "$ROOT/bin/alarm" test 2>&1 | grep -q '"backend":"terminal-notifier"'
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_ACTIVATE_BUNDLE_ID=com.apple.Terminal "$ROOT/bin/alarm" test 2>&1 | grep -q '"activateBundleId":"com.apple.Terminal"'

mkdir -p "$CODEX_ALARM_HOME"
printf 'CODEX_ALARM_SOUND="Submarine"\n' > "$CODEX_ALARM_HOME/config"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":"Submarine"'
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":"Ping"'

echo "permission dedupe and state tolerance"
printf 'CODEX_ALARM_BACKEND="terminal-notifier"\nCODEX_ALARM_NOTIFY_ON_PERMISSION="1"\n' > "$CODEX_ALARM_HOME/config"
: > "$notifier_log"
printf '{"cwd":"/tmp/project","tool_name":"Bash","tool_input":{"description":"Run tests"}}' | PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" permission
printf '{"cwd":"/tmp/project","tool_name":"Bash","tool_input":{"description":"Run tests"}}' | PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" permission
test "$(line_count "$notifier_log")" = "1"
printf '{"cwd":"/tmp/project","tool_name":"Bash","tool_input":{"description":"Run lint"}}' | PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" permission
test "$(line_count "$notifier_log")" = "2"

: > "$notifier_log"
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" test
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" test
test "$(line_count "$notifier_log")" = "4"

state_block="$TMP_ROOT/not-a-directory"
printf 'occupied\n' > "$state_block"
: > "$notifier_log"
printf '{"cwd":"/tmp/project","tool_name":"Bash","tool_input":{"description":"State failure"}}' | CODEX_HOME="$TMP_ROOT/state-codex" CODEX_ALARM_HOME="$state_block" PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" permission
test "$(line_count "$notifier_log")" = "1"

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
