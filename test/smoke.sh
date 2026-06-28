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

echo "install dry-run"
dry_codex_home="$TMP_ROOT/dry-codex"
dry_alarm_home="$dry_codex_home/alarm"
dry_log="$TMP_ROOT/install-dry-run.log"
CODEX_HOME="$dry_codex_home" CODEX_ALARM_HOME="$dry_alarm_home" "$ROOT/install.sh" --dry-run > "$dry_log" 2>&1
grep -q 'DRY-RUN: would install' "$dry_log"
grep -q 'DRY-RUN: would write Codex Alarm hooks' "$dry_log"
test ! -e "$dry_alarm_home"
test ! -e "$dry_codex_home/hooks.json"

echo "install invalid hooks"
bad_codex_home="$TMP_ROOT/bad-codex"
bad_alarm_home="$bad_codex_home/alarm"
bad_log="$TMP_ROOT/install-bad-hooks.log"
mkdir -p "$bad_codex_home"
printf '{' > "$bad_codex_home/hooks.json"
if CODEX_HOME="$bad_codex_home" CODEX_ALARM_HOME="$bad_alarm_home" "$ROOT/install.sh" --yes > "$bad_log" 2>&1; then
  echo "install succeeded with invalid hooks JSON" >&2
  exit 1
fi
grep -q 'invalid JSON' "$bad_log"
test ! -e "$bad_alarm_home/alarm"
test ! -e "$bad_alarm_home/config"

echo "install"
install_codex_home="$TMP_ROOT/install-codex"
install_alarm_home="$install_codex_home/alarm"
install_path="$TMP_ROOT/install-path"
install_brew_log="$TMP_ROOT/install-brew.log"
mkdir -p "$install_codex_home" "$install_alarm_home" "$install_path"
printf 'CODEX_ALARM_SOUND="Submarine"\n' > "$install_alarm_home/config"
cat > "$install_codex_home/hooks.json" <<'JSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo keep-stop",
            "timeout": 1,
            "statusMessage": "Keep stop"
          },
          {
            "type": "command",
            "command": "/old/alarm/alarm stop",
            "timeout": 1,
            "statusMessage": "Codex Alarm: old stop"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/old/alarm/alarm permission",
            "timeout": 1,
            "statusMessage": "Codex Alarm: old permission"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/old/alarm/alarm pre",
            "timeout": 1,
            "statusMessage": "Codex Alarm: old other event"
          },
          {
            "type": "command",
            "command": "echo keep-other",
            "timeout": 1,
            "statusMessage": "Keep other"
          }
        ]
      }
    ]
  }
}
JSON
printf '#!/bin/sh\nprintf "brew %%s\\n" "$*" >> "%s"\nexit 99\n' "$install_brew_log" > "$install_path/brew"
chmod +x "$install_path/brew"
PATH="$install_path:/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$ROOT/install.sh" --yes
test -x "$install_alarm_home/alarm"
grep -q 'CODEX_ALARM_SOUND="Submarine"' "$install_alarm_home/config"
test "$(find "$install_codex_home" -name 'hooks.json.codex-alarm-backup-*' -type f | wc -l | tr -d '[:space:]')" = "1"
grep -q 'Keep stop' "$install_codex_home/hooks.json"
grep -q 'Keep other' "$install_codex_home/hooks.json"
if grep -q 'old stop\|old permission\|old other event' "$install_codex_home/hooks.json"; then
  echo "stale Codex Alarm hooks were not removed" >&2
  exit 1
fi
test "$(grep -c 'Codex Alarm: notifying completion' "$install_codex_home/hooks.json")" = "1"
test "$(grep -c 'Codex Alarm: notifying approval request' "$install_codex_home/hooks.json")" = "1"
test ! -e "$install_brew_log"

echo "doctor"
CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$install_alarm_home/alarm" doctor >/dev/null

echo "uninstall"
CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$ROOT/uninstall.sh" --yes
test ! -e "$install_alarm_home/alarm"
if [ -f "$install_codex_home/hooks.json" ]; then
  if grep -q 'Codex Alarm:' "$install_codex_home/hooks.json"; then
    echo "Codex Alarm hooks still present after uninstall" >&2
    exit 1
  fi
fi

echo "ok"
