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
mkdir -p "$TMP_ROOT/bin"
notifier_log="$TMP_ROOT/terminal-notifier.log"
printf '#!/bin/sh\nprintf "notify\\n" >> "%s"\n' "$notifier_log" > "$TMP_ROOT/bin/terminal-notifier"
chmod +x "$TMP_ROOT/bin/terminal-notifier"

line_count() {
  wc -l < "$1" | tr -d '[:space:]'
}

echo "version"
"$ROOT/bin/alarm" version | grep -q '^1\.2\.0$'

echo "test notification dry-run"
test_log="$TMP_ROOT/alarm-test.log"
PATH="$TMP_ROOT/bin:/usr/bin:/bin" "$ROOT/bin/alarm" test > "$test_log" 2>&1
grep -q 'Codex Alarm test: osascript fallback disabled' "$test_log"
grep -q 'Codex Alarm test' "$test_log"
grep -q 'Codex needs approval' "$test_log"
fallback_enabled_log="$TMP_ROOT/fallback-enabled-dry-run.log"
if PATH="/usr/bin:/bin" CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK=1 "$ROOT/bin/alarm" test > "$fallback_enabled_log" 2>&1; then
  echo "alarm test succeeded even though the primary terminal-notifier backend was unavailable" >&2
  exit 1
fi
grep -q 'Codex Alarm test: osascript fallback enabled' "$fallback_enabled_log"
grep -q 'WARN terminal-notifier not found; retrying osascript fallback' "$fallback_enabled_log"
grep -q '"backend":"osascript"' "$fallback_enabled_log"
grep -q 'WARN osascript fallback delivered after primary backend terminal-notifier was unavailable; alarm test will still fail' "$fallback_enabled_log"

echo "hook dry-runs"
printf '{"cwd":"/tmp/project","last_assistant_message":"Done"}' | "$ROOT/bin/alarm" stop 2>&1 | grep -q 'Codex finished'
printf '{"cwd":"/tmp/project","tool_name":"Bash","tool_input":{"description":"Run tests"}}' | "$ROOT/bin/alarm" permission 2>&1 | grep -q 'Codex needs approval'

echo "config defaults and event toggles"
rm -f "$CODEX_ALARM_HOME/config"
rm -f "$CODEX_ALARM_HOME/state.json"
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
custom_sound="$TMP_ROOT/custom-sound.mp3"
custom_sound_override="$TMP_ROOT/custom-sound-override.mp3"
custom_sound_log="$TMP_ROOT/custom-sound.log"
missing_sound_log="$TMP_ROOT/missing-sound.log"
fallback_sound_log="$TMP_ROOT/fallback-sound.log"
printf 'fake audio for dry-run\n' > "$custom_sound"
printf 'fake override audio for dry-run\n' > "$custom_sound_override"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping "$ROOT/bin/alarm" test 2>&1 | grep -q '"backend":"osascript"'
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":"Ping"'
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND= "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":""'
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping CODEX_ALARM_SOUND_FALLBACK=1 "$ROOT/bin/alarm" test > "$fallback_sound_log" 2>&1
grep -q 'sound fallback: /System/Library/Sounds/Ping.aiff (afplay)' "$fallback_sound_log"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=NotASound CODEX_ALARM_SOUND_FALLBACK=1 "$ROOT/bin/alarm" test > "$fallback_sound_log" 2>&1
grep -q 'WARN sound fallback unavailable: NotASound' "$fallback_sound_log"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping CODEX_ALARM_SOUND_FILE="$custom_sound" "$ROOT/bin/alarm" test > "$custom_sound_log" 2>&1
grep -q '"sound":""' "$custom_sound_log"
grep -q "custom sound file: $custom_sound (afplay)" "$custom_sound_log"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping CODEX_ALARM_SOUND_FILE="$custom_sound" CODEX_ALARM_SOUND_FALLBACK=1 "$ROOT/bin/alarm" test > "$custom_sound_log" 2>&1
grep -q "custom sound file: $custom_sound (afplay)" "$custom_sound_log"
if grep -q 'sound fallback:' "$custom_sound_log"; then
  echo "sound fallback ran while custom sound file was configured" >&2
  exit 1
fi
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND_FILE="$TMP_ROOT/missing.mp3" "$ROOT/bin/alarm" test > "$missing_sound_log" 2>&1
grep -q "WARN custom sound file unavailable: $TMP_ROOT/missing.mp3" "$missing_sound_log"

PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=auto "$ROOT/bin/alarm" test 2>&1 | grep -q '"backend":"terminal-notifier"'
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_ACTIVATE_BUNDLE_ID=com.apple.Terminal "$ROOT/bin/alarm" test 2>&1 | grep -q '"activateBundleId":"com.apple.Terminal"'
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier TERM_PROGRAM=Apple_Terminal "$ROOT/bin/alarm" test 2>&1 | grep -q '"activateBundleId":"com.apple.Terminal"'
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier TERM_PROGRAM=iTerm2 "$ROOT/bin/alarm" test 2>&1 | grep -q '"activateBundleId":"com.googlecode.iterm2"'
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier TERM_PROGRAM=Warp "$ROOT/bin/alarm" test 2>&1 | grep -q '"activateBundleId":"dev.warp.Warp-Stable"'
PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier TERM_PROGRAM=Apple_Terminal CODEX_ALARM_ACTIVATE_BUNDLE_ID=com.example.Custom "$ROOT/bin/alarm" test 2>&1 | grep -q '"activateBundleId":"com.example.Custom"'

mkdir -p "$CODEX_ALARM_HOME"
printf 'CODEX_ALARM_SOUND="Submarine"\n' > "$CODEX_ALARM_HOME/config"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":"Submarine"'
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND=Ping "$ROOT/bin/alarm" test 2>&1 | grep -q '"sound":"Ping"'
printf 'CODEX_ALARM_SOUND_FILE="%s"\n' "$custom_sound" > "$CODEX_ALARM_HOME/config"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript "$ROOT/bin/alarm" test > "$custom_sound_log" 2>&1
grep -q "custom sound file: $custom_sound (afplay)" "$custom_sound_log"
PATH="/usr/bin:/bin" CODEX_ALARM_BACKEND=osascript CODEX_ALARM_SOUND_FILE="$custom_sound_override" "$ROOT/bin/alarm" test > "$custom_sound_log" 2>&1
grep -q "custom sound file: $custom_sound_override (afplay)" "$custom_sound_log"

echo "sound command config UX"
sound_cmd_codex_home="$TMP_ROOT/sound-command-codex"
sound_cmd_alarm_home="$sound_cmd_codex_home/alarm"
sound_cmd_config="$sound_cmd_alarm_home/config"
sound_cmd_log="$TMP_ROOT/sound-command.log"
sound_cmd_test_log="$TMP_ROOT/sound-command-test.log"
unsafe_sound_source="$TMP_ROOT/..;evil name#.mp3"
missing_sound_source="$TMP_ROOT/missing-import.mp3"
safe_imported_sound="$sound_cmd_alarm_home/sounds/_evil_name_.mp3"
mkdir -p "$sound_cmd_alarm_home"
printf 'fake audio for sound command\n' > "$unsafe_sound_source"
printf 'CODEX_ALARM_BACKEND="osascript"\nKEEP_ME="yes"\nCODEX_ALARM_SOUND="Glass"\nCODEX_ALARM_SOUND_FILE="/old/custom.mp3"\n' > "$sound_cmd_config"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_cmd_codex_home" CODEX_ALARM_HOME="$sound_cmd_alarm_home" "$ROOT/bin/alarm" sound import "$unsafe_sound_source" > "$sound_cmd_log" 2>&1
grep -q "Imported sound file: $safe_imported_sound" "$sound_cmd_log"
test -f "$safe_imported_sound"
grep -q "CODEX_ALARM_SOUND_FILE=\"$safe_imported_sound\"" "$sound_cmd_config"
grep -q 'KEEP_ME="yes"' "$sound_cmd_config"
grep -q 'CODEX_ALARM_BACKEND="osascript"' "$sound_cmd_config"
if grep -q '\.\.' "$sound_cmd_config"; then
  echo "sound import wrote a traversal-looking path" >&2
  exit 1
fi
if PATH="/usr/bin:/bin" CODEX_HOME="$sound_cmd_codex_home" CODEX_ALARM_HOME="$sound_cmd_alarm_home" "$ROOT/bin/alarm" sound import "$missing_sound_source" > "$sound_cmd_log" 2>&1; then
  echo "sound import succeeded for a missing file" >&2
  exit 1
fi
grep -q "ERROR sound file does not exist: $missing_sound_source" "$sound_cmd_log"
grep -q "CODEX_ALARM_SOUND_FILE=\"$safe_imported_sound\"" "$sound_cmd_config"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_cmd_codex_home" CODEX_ALARM_HOME="$sound_cmd_alarm_home" "$ROOT/bin/alarm" sound set Ping > "$sound_cmd_log" 2>&1
grep -q 'Sound set: Ping' "$sound_cmd_log"
grep -q 'CODEX_ALARM_SOUND="Ping"' "$sound_cmd_config"
grep -q 'CODEX_ALARM_SOUND_FILE=""' "$sound_cmd_config"
grep -q 'KEEP_ME="yes"' "$sound_cmd_config"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_cmd_codex_home" CODEX_ALARM_HOME="$sound_cmd_alarm_home" CODEX_ALARM_BACKEND=osascript "$ROOT/bin/alarm" sound test > "$sound_cmd_test_log" 2>&1
grep -q '"sound":"Ping"' "$sound_cmd_test_log"
grep -q 'Codex needs approval' "$sound_cmd_test_log"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_cmd_codex_home" CODEX_ALARM_HOME="$sound_cmd_alarm_home" "$ROOT/bin/alarm" sound off > "$sound_cmd_log" 2>&1
grep -q 'Sound disabled' "$sound_cmd_log"
grep -q 'CODEX_ALARM_SOUND=""' "$sound_cmd_config"
grep -q 'CODEX_ALARM_SOUND_FILE=""' "$sound_cmd_config"
grep -q 'CODEX_ALARM_SOUND_FALLBACK="0"' "$sound_cmd_config"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_cmd_codex_home" CODEX_ALARM_HOME="$sound_cmd_alarm_home" CODEX_ALARM_BACKEND=osascript "$ROOT/bin/alarm" sound test > "$sound_cmd_test_log" 2>&1
grep -q '"sound":""' "$sound_cmd_test_log"

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

echo "hook audit logging"
audit_home="$TMP_ROOT/audit-codex/alarm"
audit_stop_out="$TMP_ROOT/audit-stop.out"
audit_stop_err="$TMP_ROOT/audit-stop.err"
audit_permission_out="$TMP_ROOT/audit-permission.out"
audit_permission_err="$TMP_ROOT/audit-permission.err"
mkdir -p "$audit_home"
: > "$notifier_log"
printf '{"cwd":"/tmp/project-alpha","last_assistant_message":"Done now"}' | CODEX_ALARM_HOME="$audit_home" PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" stop > "$audit_stop_out" 2> "$audit_stop_err"
test ! -s "$audit_stop_out"
test ! -s "$audit_stop_err"
grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[-+][0-9]{4} event=stop backend=terminal-notifier project=project-alpha tool=- detail=Done now$' "$audit_home/alarm.log"
printf '{"cwd":"/tmp/project-alpha","tool_name":"Bash","tool_input":{"description":"Run tests"}}' | CODEX_ALARM_HOME="$audit_home" PATH="$TMP_ROOT/bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" permission > "$audit_permission_out" 2> "$audit_permission_err"
test ! -s "$audit_permission_out"
test ! -s "$audit_permission_err"
grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[-+][0-9]{4} event=permission backend=terminal-notifier project=project-alpha tool=Bash detail=Run tests$' "$audit_home/alarm.log"

echo "hung backend cleanup"
hung_bin="$TMP_ROOT/hung-bin"
hung_home="$TMP_ROOT/hung-codex/alarm"
hung_notifier_pid="$TMP_ROOT/hung-notifier.pid"
hung_child_pid="$TMP_ROOT/hung-child.pid"
hung_stop_out="$TMP_ROOT/hung-stop.out"
hung_stop_err="$TMP_ROOT/hung-stop.err"
hung_permission_out="$TMP_ROOT/hung-permission.out"
hung_permission_err="$TMP_ROOT/hung-permission.err"
hung_test_home="$TMP_ROOT/hung-test-codex/alarm"
hung_test_out="$TMP_ROOT/hung-test.out"
hung_test_err="$TMP_ROOT/hung-test.err"
mkdir -p "$hung_bin" "$hung_home"
cat > "$hung_bin/terminal-notifier" <<EOF
#!/bin/sh
printf '%s\n' "\$\$" >> "$hung_notifier_pid"
sleep 20 &
printf '%s\n' "\$!" >> "$hung_child_pid"
wait
EOF
chmod +x "$hung_bin/terminal-notifier"
mkdir -p "$hung_test_home"
if CODEX_ALARM_HOME="$hung_test_home" PATH="$hung_bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_BACKEND_TIMEOUT_SECONDS=1 CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK=0 CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" test > "$hung_test_out" 2> "$hung_test_err"; then
  echo "alarm test succeeded even though terminal-notifier timed out" >&2
  exit 1
fi
grep -q 'Codex Alarm test: osascript fallback disabled' "$hung_test_out"
grep -q 'ERROR backend=terminal-notifier event=test timed out after 1s' "$hung_test_err"
grep -q 'ERROR osascript fallback is disabled by CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK=0' "$hung_test_err"
grep -q "See $hung_test_home/alarm.log for details." "$hung_test_err"
grep -q 'backend=terminal-notifier event=test timed out after 1s' "$hung_test_home/alarm.log"
grep -q 'backend=terminal-notifier event=test failed; osascript fallback disabled' "$hung_test_home/alarm.log"

printf '{"cwd":"/tmp/project","last_assistant_message":"Done"}' | CODEX_ALARM_HOME="$hung_home" PATH="$hung_bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_BACKEND_TIMEOUT_SECONDS=3 CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" stop > "$hung_stop_out" 2> "$hung_stop_err"
test ! -s "$hung_stop_out"
test ! -s "$hung_stop_err"
grep -q 'backend=terminal-notifier event=stop timed out after 3s' "$hung_home/alarm.log"
grep -q 'event=stop backend=terminal-notifier project=project tool=- detail=Done' "$hung_home/alarm.log"
grep -q 'backend=terminal-notifier event=stop failed; osascript fallback disabled' "$hung_home/alarm.log"
if grep -q 'fallback_backend=osascript' "$hung_home/alarm.log"; then
  echo "osascript fallback ran even though it is disabled by default" >&2
  exit 1
fi
notifier_pid="$(tail -n 1 "$hung_notifier_pid")"
child_pid="$(tail -n 1 "$hung_child_pid")"
sleep 0.5
if ps -p "$notifier_pid" >/dev/null 2>&1; then
  echo "hung terminal-notifier process was not cleaned up" >&2
  exit 1
fi
if ps -p "$child_pid" >/dev/null 2>&1; then
  echo "hung terminal-notifier child process was not cleaned up" >&2
  exit 1
fi

printf '{"cwd":"/tmp/project","tool_name":"Bash","tool_input":{"description":"Hung approval"}}' | CODEX_ALARM_HOME="$hung_home" PATH="$hung_bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_BACKEND_TIMEOUT_SECONDS=3 CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" permission > "$hung_permission_out" 2> "$hung_permission_err"
test ! -s "$hung_permission_out"
test ! -s "$hung_permission_err"
grep -q 'backend=terminal-notifier event=permission timed out after 3s' "$hung_home/alarm.log"
grep -q 'event=permission backend=terminal-notifier project=project tool=Bash detail=Hung approval' "$hung_home/alarm.log"
grep -q 'backend=terminal-notifier event=permission failed; osascript fallback disabled' "$hung_home/alarm.log"
if grep -q 'fallback_backend=osascript' "$hung_home/alarm.log"; then
  echo "permission osascript fallback ran even though it is disabled by default" >&2
  exit 1
fi
notifier_pid="$(tail -n 1 "$hung_notifier_pid")"
child_pid="$(tail -n 1 "$hung_child_pid")"
sleep 0.5
if ps -p "$notifier_pid" >/dev/null 2>&1; then
  echo "hung permission terminal-notifier process was not cleaned up" >&2
  exit 1
fi
if ps -p "$child_pid" >/dev/null 2>&1; then
  echo "hung permission terminal-notifier child process was not cleaned up" >&2
  exit 1
fi

echo "osascript fallback policy"
fallback_bin="$TMP_ROOT/fallback-bin"
fallback_home="$TMP_ROOT/fallback-codex/alarm"
fallback_test_out="$TMP_ROOT/fallback-test.out"
fallback_test_err="$TMP_ROOT/fallback-test.err"
fallback_stop_out="$TMP_ROOT/fallback-stop.out"
fallback_stop_err="$TMP_ROOT/fallback-stop.err"
mkdir -p "$fallback_bin" "$fallback_home"
cat > "$fallback_bin/terminal-notifier" <<'EOF'
#!/bin/sh
exit 42
EOF
chmod +x "$fallback_bin/terminal-notifier"
if CODEX_ALARM_HOME="$fallback_home" PATH="$fallback_bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK=0 CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" test > "$fallback_test_out" 2> "$fallback_test_err"; then
  echo "alarm test succeeded even though terminal-notifier failed and fallback was disabled" >&2
  exit 1
fi
grep -q 'Codex Alarm test: osascript fallback disabled' "$fallback_test_out"
grep -q 'ERROR osascript fallback is disabled by CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK=0' "$fallback_test_err"
grep -q "See $fallback_home/alarm.log for details." "$fallback_test_err"
grep -q 'backend=terminal-notifier event=test failed with exit 42' "$fallback_home/alarm.log"
grep -q 'backend=terminal-notifier event=test failed; osascript fallback disabled' "$fallback_home/alarm.log"
if grep -q 'fallback_backend=osascript' "$fallback_home/alarm.log"; then
  echo "osascript fallback ran even though it was disabled" >&2
  exit 1
fi

printf '{"cwd":"/tmp/project","last_assistant_message":"Done"}' | CODEX_ALARM_HOME="$fallback_home" PATH="$fallback_bin:/usr/bin:/bin" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK=0 CODEX_ALARM_DRY_RUN=0 "$ROOT/bin/alarm" stop > "$fallback_stop_out" 2> "$fallback_stop_err"
test ! -s "$fallback_stop_out"
test ! -s "$fallback_stop_err"
grep -q 'backend=terminal-notifier event=stop failed with exit 42' "$fallback_home/alarm.log"
grep -q 'backend=terminal-notifier event=stop failed; osascript fallback disabled' "$fallback_home/alarm.log"

echo "install dry-run"
dry_codex_home="$TMP_ROOT/dry-codex"
dry_alarm_home="$dry_codex_home/alarm"
dry_home="$TMP_ROOT/dry-home"
dry_shell_config="$dry_home/.zshrc"
dry_log="$TMP_ROOT/install-dry-run.log"
HOME="$dry_home" CODEX_ALARM_SHELL_CONFIG="$dry_shell_config" CODEX_HOME="$dry_codex_home" CODEX_ALARM_HOME="$dry_alarm_home" "$ROOT/install.sh" --dry-run > "$dry_log" 2>&1
grep -q 'DRY-RUN: would install' "$dry_log"
grep -q "DRY-RUN: would create or refresh $dry_home/.local/bin/agent-alarm symlink" "$dry_log"
grep -q "DRY-RUN: would add $dry_home/.local/bin to PATH in $dry_shell_config" "$dry_log"
grep -q 'DRY-RUN: would write Codex Alarm hooks' "$dry_log"
test ! -e "$dry_alarm_home"
test ! -e "$dry_codex_home/hooks.json"
test ! -e "$dry_home/.local/bin/agent-alarm"
test ! -e "$dry_shell_config"
mkdir -p "$dry_alarm_home"
printf 'CODEX_ALARM_SOUND="Glass"\n' > "$dry_alarm_home/config"
HOME="$dry_home" CODEX_ALARM_SHELL_CONFIG="$dry_shell_config" CODEX_HOME="$dry_codex_home" CODEX_ALARM_HOME="$dry_alarm_home" "$ROOT/install.sh" --dry-run > "$dry_log" 2>&1
grep -q "DRY-RUN: would append CODEX_ALARM_SOUND_FILE to $dry_alarm_home/config" "$dry_log"
grep -q "DRY-RUN: would append CODEX_ALARM_SOUND_FALLBACK to $dry_alarm_home/config" "$dry_log"
if grep -q "DRY-RUN: would append CODEX_ALARM_SOUND to $dry_alarm_home/config" "$dry_log"; then
  echo "install dry-run would append an existing config key" >&2
  exit 1
fi

echo "install invalid hooks"
bad_codex_home="$TMP_ROOT/bad-codex"
bad_alarm_home="$bad_codex_home/alarm"
bad_home="$TMP_ROOT/bad-home"
bad_log="$TMP_ROOT/install-bad-hooks.log"
mkdir -p "$bad_codex_home"
printf '{' > "$bad_codex_home/hooks.json"
if HOME="$bad_home" CODEX_HOME="$bad_codex_home" CODEX_ALARM_HOME="$bad_alarm_home" "$ROOT/install.sh" --yes > "$bad_log" 2>&1; then
  echo "install succeeded with invalid hooks JSON" >&2
  exit 1
fi
grep -q 'invalid JSON' "$bad_log"
test ! -e "$bad_alarm_home/alarm"
test ! -e "$bad_alarm_home/config"

echo "install fresh bundle detection"
fresh_codex_home="$TMP_ROOT/fresh-install-codex"
fresh_alarm_home="$fresh_codex_home/alarm"
fresh_home="$TMP_ROOT/fresh-home"
fresh_shell_config="$fresh_home/.zshrc"
TERM_PROGRAM=Ghostty PATH="$TMP_ROOT/bin:/usr/bin:/bin" HOME="$fresh_home" CODEX_ALARM_SHELL_CONFIG="$fresh_shell_config" CODEX_HOME="$fresh_codex_home" CODEX_ALARM_HOME="$fresh_alarm_home" "$ROOT/install.sh" --yes
grep -q 'CODEX_ALARM_ACTIVATE_BUNDLE_ID="com.mitchellh.ghostty"' "$fresh_alarm_home/config"
test -x "$fresh_alarm_home/alarm"
test "$(readlink "$fresh_home/.local/bin/agent-alarm")" = "$fresh_alarm_home/alarm"
grep -q 'Codex Alarm agent-alarm PATH' "$fresh_shell_config"
(HOME="$fresh_home" PATH="/usr/bin:/bin"; . "$fresh_shell_config"; agent-alarm version) | grep -q '^1\.2\.0$'

echo "install"
install_codex_home="$TMP_ROOT/install-codex"
install_alarm_home="$install_codex_home/alarm"
install_home="$TMP_ROOT/install-home"
install_shell_config="$install_home/.zshrc"
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
PATH="$install_path:$install_home/.local/bin:/usr/bin:/bin" HOME="$install_home" CODEX_ALARM_SHELL_CONFIG="$install_shell_config" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$ROOT/install.sh" --yes
test -x "$install_alarm_home/alarm"
test "$(readlink "$install_home/.local/bin/agent-alarm")" = "$install_alarm_home/alarm"
grep -q 'Codex Alarm agent-alarm PATH' "$install_shell_config"
PATH="$install_home/.local/bin:/usr/bin:/bin" agent-alarm version | grep -q '^1\.2\.0$'
grep -q 'CODEX_ALARM_SOUND="Submarine"' "$install_alarm_home/config"
grep -q 'CODEX_ALARM_SOUND_FILE=""' "$install_alarm_home/config"
grep -q 'CODEX_ALARM_SOUND_FALLBACK="0"' "$install_alarm_home/config"
grep -q 'CODEX_ALARM_BACKEND_TIMEOUT_SECONDS="3"' "$install_alarm_home/config"
grep -q 'CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="0"' "$install_alarm_home/config"
test "$(find "$install_codex_home" -name 'hooks.json.codex-alarm-backup-*' -type f | wc -l | tr -d '[:space:]')" = "1"
grep -q 'Keep stop' "$install_codex_home/hooks.json"
grep -q 'Keep other' "$install_codex_home/hooks.json"
if grep -q 'old stop\|old permission\|old other event' "$install_codex_home/hooks.json"; then
  echo "stale Codex Alarm hooks were not removed" >&2
  exit 1
fi
test "$(grep -c 'Codex Alarm: notifying completion' "$install_codex_home/hooks.json")" = "1"
test "$(grep -c 'Codex Alarm: notifying approval request' "$install_codex_home/hooks.json")" = "1"
test "$(grep -c '"timeout": 10' "$install_codex_home/hooks.json")" = "2"
test ! -e "$install_brew_log"

echo "doctor"
doctor_log="$TMP_ROOT/doctor.log"
cp "$install_codex_home/hooks.json" "$TMP_ROOT/hooks-before-doctor.json"
cp "$install_alarm_home/config" "$TMP_ROOT/config-before-doctor"
PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$install_alarm_home/alarm" doctor > "$doctor_log" 2>&1
grep -q 'version: 1.2.0' "$doctor_log"
grep -q 'platform: macOS supported' "$doctor_log"
grep -q 'local-only: no telemetry, no network requests' "$doctor_log"
grep -q "CODEX_HOME: $install_codex_home" "$doctor_log"
grep -q "CODEX_ALARM_HOME: $install_alarm_home" "$doctor_log"
grep -q "config file: $install_alarm_home/config" "$doctor_log"
grep -q "hooks file: $install_codex_home/hooks.json" "$doctor_log"
grep -q 'backend configured: auto' "$doctor_log"
grep -q 'backend resolved: terminal-notifier' "$doctor_log"
grep -q 'notify on stop: 1' "$doctor_log"
grep -q 'notify on permission: 1' "$doctor_log"
grep -q 'sound: Submarine' "$doctor_log"
grep -q 'sound status: built-in macOS sound found' "$doctor_log"
grep -q 'custom sound file: <not configured>' "$doctor_log"
grep -q 'custom sound file status: <not configured>' "$doctor_log"
grep -q 'sound fallback: disabled' "$doctor_log"
grep -q 'sound fallback playback: disabled' "$doctor_log"
grep -q 'activate bundle ID: <not configured>' "$doctor_log"
grep -q 'backend timeout seconds: 3' "$doctor_log"
grep -q 'osascript fallback: disabled' "$doctor_log"
grep -q "log file: $install_alarm_home/alarm.log" "$doctor_log"
grep -q "hooks scope: user-level global hooks may notify from any active Codex session using $install_codex_home" "$doctor_log"
grep -q 'diagnostic flow: hooks -> backend resolution -> backend availability -> macOS presentation' "$doctor_log"
grep -q 'WARN terminal-notifier missing: default notification backend unavailable' "$doctor_log"
grep -q 'Install manually with: brew install terminal-notifier' "$doctor_log"
if grep -q 'WARN osascript backend: notification identity and click-to-focus are degraded' "$doctor_log"; then
  echo "doctor warned about osascript backend even though auto selected terminal-notifier" >&2
  exit 1
fi
if grep -q 'WARN osascript fallback enabled' "$doctor_log"; then
  echo "doctor warned that osascript fallback is enabled unexpectedly" >&2
  exit 1
fi
grep -q 'WARN codex not found on PATH' "$doctor_log"
grep -q 'WARN no activate bundle ID configured' "$doctor_log"
grep -q "click-to-focus setup: set CODEX_ALARM_ACTIVATE_BUNDLE_ID in $install_alarm_home/config" "$doctor_log"
grep -q "click-to-focus setup: find a bundle ID with osascript -e 'id of app \"App Name\"'" "$doctor_log"
grep -q 'click-to-focus setup: common values include com.apple.Terminal, com.googlecode.iterm2, com.microsoft.VSCode, com.todesktop.230313mzl4w4u92, com.mitchellh.ghostty, and dev.warp.Warp-Stable' "$doctor_log"
grep -q 'hooks.json: valid JSON' "$doctor_log"
grep -q 'hooks: Codex Alarm entries 2' "$doctor_log"
grep -q 'hooks: Stop hook entries 1' "$doctor_log"
grep -q 'hooks: PermissionRequest hook entries 1' "$doctor_log"
grep -q 'hooks: Codex Alarm entries found' "$doctor_log"
grep -q 'hooks: required entries present' "$doctor_log"
grep -q 'presentation checks: read-only macOS Notification Center checklist' "$doctor_log"
grep -q 'presentation check: doctor cannot inspect or change macOS notification permissions' "$doctor_log"
grep -q 'presentation check: System Settings > Notifications > terminal-notifier > Allow Notifications on' "$doctor_log"
grep -q 'presentation check: terminal-notifier alert style set to Banners or Alerts' "$doctor_log"
grep -q 'presentation check: terminal-notifier Sounds enabled if you expect notification sound' "$doctor_log"
grep -q 'presentation check: Focus / Do Not Disturb disabled or configured to allow terminal-notifier' "$doctor_log"
grep -q "presentation check: run $install_alarm_home/alarm test after changing macOS settings" "$doctor_log"
grep -q 'Run /hooks inside Codex' "$doctor_log"
CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID=com.apple.Terminal "$install_alarm_home/alarm" doctor > "$doctor_log" 2>&1
grep -q 'click-to-focus target: com.apple.Terminal' "$doctor_log"
grep -q "click-to-focus check: run $install_alarm_home/alarm test, then click the notification" "$doctor_log"
cmp "$install_codex_home/hooks.json" "$TMP_ROOT/hooks-before-doctor.json"
cmp "$install_alarm_home/config" "$TMP_ROOT/config-before-doctor"
test -x "$install_alarm_home/alarm"
test ! -e "$install_alarm_home/state.json"

echo "status"
status_log="$TMP_ROOT/status.log"
rm -f "$install_alarm_home/alarm.log"
PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$install_alarm_home/alarm" status > "$status_log" 2>&1
grep -q 'version: 1.2.0' "$status_log"
grep -q "installed executable: $install_alarm_home/alarm" "$status_log"
grep -q 'installed executable status: found' "$status_log"
grep -q 'backend: configured=auto resolved=terminal-notifier' "$status_log"
grep -q 'notifications: stop=1 permission=1' "$status_log"
grep -q 'sound: built-in Submarine; fallback=disabled' "$status_log"
grep -q 'click target: <not configured>' "$status_log"
grep -q "log file: $install_alarm_home/alarm.log" "$status_log"
grep -q 'latest log: <none>' "$status_log"
grep -q 'hooks: Stop=found PermissionRequest=found' "$status_log"
if grep -q 'presentation checks\|diagnostic flow\|Run /hooks' "$status_log"; then
  echo "status included doctor-only troubleshooting output" >&2
  exit 1
fi
test "$(wc -l < "$status_log" | tr -d '[:space:]')" -lt "$(wc -l < "$doctor_log" | tr -d '[:space:]')"
printf '2026-06-28T00:00:00-0700 event=stop backend=terminal-notifier project=alarm tool=- detail=Done\n' > "$install_alarm_home/alarm.log"
PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID=com.apple.Terminal "$install_alarm_home/alarm" status > "$status_log" 2>&1
grep -q 'click target: com.apple.Terminal' "$status_log"
grep -q 'latest log: 2026-06-28T00:00:00-0700 event=stop backend=terminal-notifier project=alarm tool=- detail=Done' "$status_log"
cmp "$install_codex_home/hooks.json" "$TMP_ROOT/hooks-before-doctor.json"
cmp "$install_alarm_home/config" "$TMP_ROOT/config-before-doctor"

echo "hooks"
hooks_log="$TMP_ROOT/hooks.log"
hooks_dry_log="$TMP_ROOT/hooks-dry.log"
hooks_missing_codex_home="$TMP_ROOT/hooks-missing-codex"
hooks_missing_alarm_home="$hooks_missing_codex_home/alarm"
hooks_missing_log="$TMP_ROOT/hooks-missing.log"
hooks_invalid_codex_home="$TMP_ROOT/hooks-invalid-codex"
hooks_invalid_alarm_home="$hooks_invalid_codex_home/alarm"
hooks_invalid_log="$TMP_ROOT/hooks-invalid.log"
hooks_stale_codex_home="$TMP_ROOT/hooks-stale-codex"
hooks_stale_alarm_home="$hooks_stale_codex_home/alarm"
hooks_stale_log="$TMP_ROOT/hooks-stale.log"
PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$install_alarm_home/alarm" hooks > "$hooks_log" 2>&1
grep -q 'Codex Alarm hooks' "$hooks_log"
grep -q "hooks file: $install_codex_home/hooks.json" "$hooks_log"
grep -q "expected Stop command: $install_alarm_home/alarm stop" "$hooks_log"
grep -q "expected PermissionRequest command: $install_alarm_home/alarm permission" "$hooks_log"
grep -q 'trust UI: run /hooks inside Codex to review or trust hooks' "$hooks_log"
grep -q 'hooks.json: valid JSON' "$hooks_log"
grep -q 'hooks: Codex Alarm entries 2' "$hooks_log"
grep -q 'hooks: Stop hook entries 1' "$hooks_log"
grep -q 'hooks: PermissionRequest hook entries 1' "$hooks_log"
grep -q 'hooks: required entries present' "$hooks_log"
grep -q 'hook entry: event=Stop' "$hooks_log"
grep -q "hook command path: $install_alarm_home/alarm" "$hooks_log"
grep -q 'hook command subcommand: stop' "$hooks_log"
grep -q 'hook timeout: 10' "$hooks_log"
grep -q 'hook statusMessage: Codex Alarm: notifying completion' "$hooks_log"
grep -q 'hook entry: event=PermissionRequest' "$hooks_log"
grep -q 'hook command subcommand: permission' "$hooks_log"
grep -q 'hook statusMessage: Codex Alarm: notifying approval request' "$hooks_log"
grep -q 'hook status: installed' "$hooks_log"
CODEX_ALARM_DRY_RUN=1 PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$install_alarm_home/alarm" hooks > "$hooks_dry_log" 2>&1
grep -q 'hooks: required entries present' "$hooks_dry_log"
cmp "$install_codex_home/hooks.json" "$TMP_ROOT/hooks-before-doctor.json"
cmp "$install_alarm_home/config" "$TMP_ROOT/config-before-doctor"
test ! -e "$install_alarm_home/state.json"

PATH="/usr/bin:/bin" CODEX_HOME="$hooks_missing_codex_home" CODEX_ALARM_HOME="$hooks_missing_alarm_home" "$install_alarm_home/alarm" hooks > "$hooks_missing_log" 2>&1
grep -q "WARN hooks.json missing: $hooks_missing_codex_home/hooks.json" "$hooks_missing_log"
grep -q 'hooks: Codex Alarm entries 0' "$hooks_missing_log"
grep -q 'WARN hooks: Stop hook not found' "$hooks_missing_log"
grep -q 'WARN hooks: PermissionRequest hook not found' "$hooks_missing_log"
test ! -e "$hooks_missing_codex_home"

mkdir -p "$hooks_invalid_codex_home"
printf '{' > "$hooks_invalid_codex_home/hooks.json"
if PATH="/usr/bin:/bin" CODEX_HOME="$hooks_invalid_codex_home" CODEX_ALARM_HOME="$hooks_invalid_alarm_home" "$install_alarm_home/alarm" hooks > "$hooks_invalid_log" 2>&1; then
  echo "hooks succeeded with invalid hooks JSON" >&2
  exit 1
fi
grep -q "ERROR hooks.json is invalid JSON: $hooks_invalid_codex_home/hooks.json" "$hooks_invalid_log"
grep -q '^{$' "$hooks_invalid_codex_home/hooks.json"
test ! -e "$hooks_invalid_alarm_home"

mkdir -p "$hooks_stale_codex_home" "$hooks_stale_alarm_home"
cp "$ROOT/bin/alarm" "$hooks_stale_alarm_home/alarm"
chmod +x "$hooks_stale_alarm_home/alarm"
cat > "$hooks_stale_codex_home/hooks.json" <<JSON
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
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
            "command": "$hooks_stale_alarm_home/alarm permission",
            "timeout": 10,
            "statusMessage": "Codex Alarm: notifying approval request"
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
          }
        ]
      }
    ]
  }
}
JSON
cp "$hooks_stale_codex_home/hooks.json" "$TMP_ROOT/hooks-stale-before.json"
PATH="/usr/bin:/bin" CODEX_HOME="$hooks_stale_codex_home" CODEX_ALARM_HOME="$hooks_stale_alarm_home" "$hooks_stale_alarm_home/alarm" hooks > "$hooks_stale_log" 2>&1
grep -q 'hooks: Codex Alarm entries 3' "$hooks_stale_log"
grep -q 'hooks: Stop hook entries 0' "$hooks_stale_log"
grep -q 'hooks: PermissionRequest hook entries 1' "$hooks_stale_log"
grep -q 'WARN hooks: Stop hook not found' "$hooks_stale_log"
grep -q 'WARN hooks: stale Codex Alarm entries 2' "$hooks_stale_log"
grep -q "WARN hooks: Stop command path mismatch: /old/alarm/alarm stop (expected $hooks_stale_alarm_home/alarm stop)" "$hooks_stale_log"
grep -q 'hook entry: event=PreToolUse' "$hooks_stale_log"
grep -q 'hook status: stale' "$hooks_stale_log"
grep -q 'hook status: stale; command path mismatch' "$hooks_stale_log"
cmp "$hooks_stale_codex_home/hooks.json" "$TMP_ROOT/hooks-stale-before.json"
test ! -e "$hooks_stale_alarm_home/state.json"

echo "config"
config_default_codex_home="$TMP_ROOT/config-default-codex"
config_default_alarm_home="$config_default_codex_home/alarm"
config_file_codex_home="$TMP_ROOT/config-file-codex"
config_file_alarm_home="$config_file_codex_home/alarm"
config_warn_codex_home="$TMP_ROOT/config-warn-codex"
config_warn_alarm_home="$config_warn_codex_home/alarm"
config_invalid_codex_home="$TMP_ROOT/config-invalid-codex"
config_invalid_alarm_home="$config_invalid_codex_home/alarm"
config_default_log="$TMP_ROOT/config-default.log"
config_file_log="$TMP_ROOT/config-file.log"
config_env_log="$TMP_ROOT/config-env.log"
config_path_log="$TMP_ROOT/config-path.log"
config_warn_log="$TMP_ROOT/config-warn.log"
config_invalid_log="$TMP_ROOT/config-invalid.log"
PATH="/usr/bin:/bin" CODEX_HOME="$config_default_codex_home" CODEX_ALARM_HOME="$config_default_alarm_home" "$install_alarm_home/alarm" config > "$config_default_log" 2>&1
grep -q 'Codex Alarm config' "$config_default_log"
grep -q "config file: $config_default_alarm_home/config" "$config_default_log"
grep -q 'config file status: missing; using defaults and environment overrides' "$config_default_log"
grep -q 'CODEX_ALARM_BACKEND=auto' "$config_default_log"
grep -q 'backend resolved: terminal-notifier' "$config_default_log"
grep -q 'CODEX_ALARM_SOUND=Glass' "$config_default_log"
grep -q 'CODEX_ALARM_SOUND_FILE=' "$config_default_log"
grep -q 'custom sound file status: <not configured>' "$config_default_log"
grep -q 'CODEX_ALARM_SOUND_FALLBACK=0' "$config_default_log"
grep -q 'sound fallback: disabled' "$config_default_log"
grep -q 'CODEX_ALARM_NOTIFY_ON_STOP=1' "$config_default_log"
grep -q 'CODEX_ALARM_NOTIFY_ON_PERMISSION=1' "$config_default_log"
grep -q 'CODEX_ALARM_BACKEND_TIMEOUT_SECONDS=3' "$config_default_log"
grep -q 'CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK=0' "$config_default_log"
test ! -e "$config_default_alarm_home"

mkdir -p "$config_file_alarm_home"
printf 'CODEX_ALARM_BACKEND="osascript"\nCODEX_ALARM_ACTIVATE_BUNDLE_ID="com.example.App"\nCODEX_ALARM_SOUND="Ping"\nCODEX_ALARM_SOUND_FALLBACK="1"\nCODEX_ALARM_NOTIFY_ON_STOP="0"\nCODEX_ALARM_NOTIFY_ON_PERMISSION="1"\nCODEX_ALARM_BACKEND_TIMEOUT_SECONDS="7"\nCODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="1"\n' > "$config_file_alarm_home/config"
cp "$config_file_alarm_home/config" "$TMP_ROOT/config-file-before"
PATH="/usr/bin:/bin" CODEX_HOME="$config_file_codex_home" CODEX_ALARM_HOME="$config_file_alarm_home" "$install_alarm_home/alarm" config > "$config_file_log" 2>&1
grep -q 'config file status: found' "$config_file_log"
grep -q 'CODEX_ALARM_BACKEND=osascript' "$config_file_log"
grep -q 'backend resolved: osascript' "$config_file_log"
grep -q 'CODEX_ALARM_ACTIVATE_BUNDLE_ID=com.example.App' "$config_file_log"
grep -q 'CODEX_ALARM_SOUND=Ping' "$config_file_log"
grep -q 'sound fallback: enabled' "$config_file_log"
grep -q 'CODEX_ALARM_NOTIFY_ON_STOP=0' "$config_file_log"
grep -q 'CODEX_ALARM_BACKEND_TIMEOUT_SECONDS=7' "$config_file_log"
grep -q 'CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK=1' "$config_file_log"
PATH="/usr/bin:/bin" CODEX_HOME="$config_file_codex_home" CODEX_ALARM_HOME="$config_file_alarm_home" CODEX_ALARM_BACKEND=terminal-notifier CODEX_ALARM_SOUND=Pop CODEX_ALARM_NOTIFY_ON_STOP=1 CODEX_ALARM_BACKEND_TIMEOUT_SECONDS=9 "$install_alarm_home/alarm" config > "$config_env_log" 2>&1
grep -q 'CODEX_ALARM_BACKEND=terminal-notifier' "$config_env_log"
grep -q 'backend resolved: terminal-notifier' "$config_env_log"
grep -q 'CODEX_ALARM_SOUND=Pop' "$config_env_log"
grep -q 'CODEX_ALARM_NOTIFY_ON_STOP=1' "$config_env_log"
grep -q 'CODEX_ALARM_BACKEND_TIMEOUT_SECONDS=9' "$config_env_log"
PATH="/usr/bin:/bin" CODEX_HOME="$config_file_codex_home" CODEX_ALARM_HOME="$config_file_alarm_home" "$install_alarm_home/alarm" config path > "$config_path_log" 2>&1
grep -qx "$config_file_alarm_home/config" "$config_path_log"
cmp "$config_file_alarm_home/config" "$TMP_ROOT/config-file-before"
test ! -e "$config_file_alarm_home/state.json"

mkdir -p "$config_warn_alarm_home"
printf 'CODEX_ALARM_SOUND="/tmp/custom.aiff"\nCODEX_ALARM_SOUND_FILE="%s"\n' "$TMP_ROOT/missing-config-sound.mp3" > "$config_warn_alarm_home/config"
PATH="/usr/bin:/bin" CODEX_HOME="$config_warn_codex_home" CODEX_ALARM_HOME="$config_warn_alarm_home" "$install_alarm_home/alarm" config > "$config_warn_log" 2>&1
grep -q "CODEX_ALARM_SOUND=/tmp/custom.aiff" "$config_warn_log"
grep -q "WARN sound: '/tmp/custom.aiff' looks like a file path; use CODEX_ALARM_SOUND_FILE for custom sound files" "$config_warn_log"
grep -q "CODEX_ALARM_SOUND_FILE=$TMP_ROOT/missing-config-sound.mp3" "$config_warn_log"
grep -q "WARN custom sound file: '$TMP_ROOT/missing-config-sound.mp3' does not exist" "$config_warn_log"

mkdir -p "$config_invalid_alarm_home"
printf 'CODEX_ALARM_BACKEND="invalid"\n' > "$config_invalid_alarm_home/config"
if PATH="/usr/bin:/bin" CODEX_HOME="$config_invalid_codex_home" CODEX_ALARM_HOME="$config_invalid_alarm_home" "$install_alarm_home/alarm" config > "$config_invalid_log" 2>&1; then
  echo "config succeeded with invalid backend" >&2
  exit 1
fi
grep -q 'CODEX_ALARM_BACKEND=invalid' "$config_invalid_log"
grep -q 'ERROR config invalid:' "$config_invalid_log"
grep -q "invalid CODEX_ALARM_BACKEND 'invalid'" "$config_invalid_log"
printf 'CODEX_ALARM_NOTIFY_ON_STOP="maybe"\n' > "$config_invalid_alarm_home/config"
if PATH="/usr/bin:/bin" CODEX_HOME="$config_invalid_codex_home" CODEX_ALARM_HOME="$config_invalid_alarm_home" "$install_alarm_home/alarm" config > "$config_invalid_log" 2>&1; then
  echo "config succeeded with invalid boolean" >&2
  exit 1
fi
grep -q 'CODEX_ALARM_NOTIFY_ON_STOP=maybe' "$config_invalid_log"
grep -q 'CODEX_ALARM_NOTIFY_ON_STOP must be 0 or 1' "$config_invalid_log"
printf 'CODEX_ALARM_BACKEND_TIMEOUT_SECONDS="0"\n' > "$config_invalid_alarm_home/config"
if PATH="/usr/bin:/bin" CODEX_HOME="$config_invalid_codex_home" CODEX_ALARM_HOME="$config_invalid_alarm_home" "$install_alarm_home/alarm" config > "$config_invalid_log" 2>&1; then
  echo "config succeeded with invalid timeout" >&2
  exit 1
fi
grep -q 'CODEX_ALARM_BACKEND_TIMEOUT_SECONDS=0' "$config_invalid_log"
grep -q 'CODEX_ALARM_BACKEND_TIMEOUT_SECONDS must be a positive integer' "$config_invalid_log"
printf 'BROKEN LINE\n' > "$config_invalid_alarm_home/config"
if PATH="/usr/bin:/bin" CODEX_HOME="$config_invalid_codex_home" CODEX_ALARM_HOME="$config_invalid_alarm_home" "$install_alarm_home/alarm" config > "$config_invalid_log" 2>&1; then
  echo "config succeeded with invalid config format" >&2
  exit 1
fi
grep -q 'ERROR config invalid:' "$config_invalid_log"
grep -q 'expected KEY=VALUE' "$config_invalid_log"
test ! -e "$config_invalid_alarm_home/state.json"
cmp "$install_codex_home/hooks.json" "$TMP_ROOT/hooks-before-doctor.json"
cmp "$install_alarm_home/config" "$TMP_ROOT/config-before-doctor"

echo "logs"
logs_default="$TMP_ROOT/logs-default.log"
logs_tail="$TMP_ROOT/logs-tail.log"
logs_path="$TMP_ROOT/logs-path.log"
logs_missing="$TMP_ROOT/logs-missing.log"
logs_invalid="$TMP_ROOT/logs-invalid.log"
for i in {1..25}; do
  printf 'entry %02d event=stop backend=terminal-notifier project=alarm tool=- detail=Done\n' "$i"
done > "$install_alarm_home/alarm.log"
PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$install_alarm_home/alarm" logs > "$logs_default" 2>&1
test "$(line_count "$logs_default")" = "20"
grep -q '^entry 06 ' "$logs_default"
grep -q '^entry 25 ' "$logs_default"
PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$install_alarm_home/alarm" logs --tail 3 > "$logs_tail" 2>&1
test "$(line_count "$logs_tail")" = "3"
grep -q '^entry 23 ' "$logs_tail"
grep -q '^entry 25 ' "$logs_tail"
PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$install_alarm_home/alarm" logs path > "$logs_path" 2>&1
grep -qx "$install_alarm_home/alarm.log" "$logs_path"
rm -f "$install_alarm_home/alarm.log"
PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$install_alarm_home/alarm" logs > "$logs_missing" 2>&1
grep -q "No Codex Alarm log found at $install_alarm_home/alarm.log" "$logs_missing"
grep -q 'Logs are created after notification attempts or backend failures.' "$logs_missing"
if PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$install_alarm_home/alarm" logs --tail 0 > "$logs_invalid" 2>&1; then
  echo "logs accepted invalid tail count 0" >&2
  exit 1
fi
grep -q 'logs --tail must be a positive integer between 1 and 1000' "$logs_invalid"
if PATH="/usr/bin:/bin" CODEX_HOME="$install_codex_home" CODEX_ALARM_HOME="$install_alarm_home" "$install_alarm_home/alarm" logs --tail many > "$logs_invalid" 2>&1; then
  echo "logs accepted nonnumeric tail count" >&2
  exit 1
fi
grep -q 'logs --tail must be a positive integer between 1 and 1000' "$logs_invalid"
cmp "$install_codex_home/hooks.json" "$TMP_ROOT/hooks-before-doctor.json"
cmp "$install_alarm_home/config" "$TMP_ROOT/config-before-doctor"
test ! -e "$install_alarm_home/state.json"

echo "doctor sound warnings"
sound_doctor_codex_home="$TMP_ROOT/sound-doctor-codex"
sound_doctor_alarm_home="$sound_doctor_codex_home/alarm"
sound_doctor_log="$TMP_ROOT/doctor-sound.log"
mkdir -p "$sound_doctor_alarm_home"
cp "$ROOT/bin/alarm" "$sound_doctor_alarm_home/alarm"
chmod +x "$sound_doctor_alarm_home/alarm"
printf 'CODEX_ALARM_SOUND="NotASound"\n' > "$sound_doctor_alarm_home/config"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_doctor_codex_home" CODEX_ALARM_HOME="$sound_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$sound_doctor_alarm_home/alarm" doctor > "$sound_doctor_log" 2>&1
grep -q "WARN sound: 'NotASound' was not found in /System/Library/Sounds" "$sound_doctor_log"
printf 'CODEX_ALARM_SOUND=""\n' > "$sound_doctor_alarm_home/config"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_doctor_codex_home" CODEX_ALARM_HOME="$sound_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$sound_doctor_alarm_home/alarm" doctor > "$sound_doctor_log" 2>&1
grep -q 'WARN sound: empty; notification sound is disabled' "$sound_doctor_log"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_doctor_codex_home" CODEX_ALARM_HOME="$sound_doctor_alarm_home" CODEX_ALARM_SOUND="/tmp/custom.aiff" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$sound_doctor_alarm_home/alarm" doctor > "$sound_doctor_log" 2>&1
grep -q "WARN sound: '/tmp/custom.aiff' looks like a file path; use CODEX_ALARM_SOUND_FILE for custom sound files" "$sound_doctor_log"
printf 'CODEX_ALARM_SOUND_FILE="%s"\n' "$custom_sound" > "$sound_doctor_alarm_home/config"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_doctor_codex_home" CODEX_ALARM_HOME="$sound_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$sound_doctor_alarm_home/alarm" doctor > "$sound_doctor_log" 2>&1
grep -q "custom sound file: $custom_sound" "$sound_doctor_log"
grep -q 'custom sound file status: usable by afplay' "$sound_doctor_log"
grep -q 'sound source: custom sound file; built-in notification sound is suppressed' "$sound_doctor_log"
printf 'CODEX_ALARM_SOUND="Ping"\nCODEX_ALARM_SOUND_FALLBACK="1"\n' > "$sound_doctor_alarm_home/config"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_doctor_codex_home" CODEX_ALARM_HOME="$sound_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$sound_doctor_alarm_home/alarm" doctor > "$sound_doctor_log" 2>&1
grep -q 'sound fallback: enabled' "$sound_doctor_log"
grep -q 'sound fallback playback: /System/Library/Sounds/Ping.aiff (afplay)' "$sound_doctor_log"
printf 'CODEX_ALARM_SOUND_FILE="%s"\nCODEX_ALARM_SOUND_FALLBACK="1"\n' "$custom_sound" > "$sound_doctor_alarm_home/config"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_doctor_codex_home" CODEX_ALARM_HOME="$sound_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$sound_doctor_alarm_home/alarm" doctor > "$sound_doctor_log" 2>&1
grep -q 'sound fallback playback: custom sound file is configured; fallback is not used' "$sound_doctor_log"
printf 'CODEX_ALARM_SOUND_FILE="%s"\n' "$TMP_ROOT/missing.mp3" > "$sound_doctor_alarm_home/config"
PATH="/usr/bin:/bin" CODEX_HOME="$sound_doctor_codex_home" CODEX_ALARM_HOME="$sound_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$sound_doctor_alarm_home/alarm" doctor > "$sound_doctor_log" 2>&1
grep -q "WARN custom sound file: '$TMP_ROOT/missing.mp3' does not exist" "$sound_doctor_log"

echo "doctor invalid config"
bad_doctor_codex_home="$TMP_ROOT/bad-doctor-config-codex"
bad_doctor_alarm_home="$bad_doctor_codex_home/alarm"
bad_doctor_log="$TMP_ROOT/doctor-bad-config.log"
mkdir -p "$bad_doctor_alarm_home"
cp "$ROOT/bin/alarm" "$bad_doctor_alarm_home/alarm"
chmod +x "$bad_doctor_alarm_home/alarm"
printf 'CODEX_ALARM_SOUND="Glass"\nBROKEN LINE\n' > "$bad_doctor_alarm_home/config"
if PATH="/usr/bin:/bin" CODEX_HOME="$bad_doctor_codex_home" CODEX_ALARM_HOME="$bad_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$bad_doctor_alarm_home/alarm" doctor > "$bad_doctor_log" 2>&1; then
  echo "doctor succeeded with invalid config" >&2
  exit 1
fi
grep -q 'ERROR config invalid:' "$bad_doctor_log"
grep -q 'expected KEY=VALUE' "$bad_doctor_log"
grep -q 'WARN terminal-notifier missing' "$bad_doctor_log"
if PATH="/usr/bin:/bin" CODEX_HOME="$bad_doctor_codex_home" CODEX_ALARM_HOME="$bad_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$bad_doctor_alarm_home/alarm" status > "$bad_doctor_log" 2>&1; then
  echo "status succeeded with invalid config" >&2
  exit 1
fi
grep -q 'ERROR config invalid:' "$bad_doctor_log"
grep -q 'expected KEY=VALUE' "$bad_doctor_log"
test -x "$bad_doctor_alarm_home/alarm"
grep -q 'BROKEN LINE' "$bad_doctor_alarm_home/config"
test ! -e "$bad_doctor_alarm_home/state.json"

echo "doctor invalid hooks"
bad_hooks_doctor_codex_home="$TMP_ROOT/bad-doctor-hooks-codex"
bad_hooks_doctor_alarm_home="$bad_hooks_doctor_codex_home/alarm"
bad_hooks_doctor_log="$TMP_ROOT/doctor-bad-hooks.log"
mkdir -p "$bad_hooks_doctor_codex_home" "$bad_hooks_doctor_alarm_home"
cp "$ROOT/bin/alarm" "$bad_hooks_doctor_alarm_home/alarm"
chmod +x "$bad_hooks_doctor_alarm_home/alarm"
printf 'CODEX_ALARM_SOUND="Glass"\n' > "$bad_hooks_doctor_alarm_home/config"
printf '{' > "$bad_hooks_doctor_codex_home/hooks.json"
if PATH="/usr/bin:/bin" CODEX_HOME="$bad_hooks_doctor_codex_home" CODEX_ALARM_HOME="$bad_hooks_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$bad_hooks_doctor_alarm_home/alarm" doctor > "$bad_hooks_doctor_log" 2>&1; then
  echo "doctor succeeded with invalid hooks JSON" >&2
  exit 1
fi
grep -q 'ERROR hooks.json is invalid JSON' "$bad_hooks_doctor_log"
if PATH="/usr/bin:/bin" CODEX_HOME="$bad_hooks_doctor_codex_home" CODEX_ALARM_HOME="$bad_hooks_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$bad_hooks_doctor_alarm_home/alarm" status > "$bad_hooks_doctor_log" 2>&1; then
  echo "status succeeded with invalid hooks JSON" >&2
  exit 1
fi
grep -q 'ERROR hooks.json is invalid JSON' "$bad_hooks_doctor_log"
test -x "$bad_hooks_doctor_alarm_home/alarm"
grep -q 'CODEX_ALARM_SOUND="Glass"' "$bad_hooks_doctor_alarm_home/config"
grep -q '^{$' "$bad_hooks_doctor_codex_home/hooks.json"
test ! -e "$bad_hooks_doctor_alarm_home/state.json"

echo "doctor stale hook warnings"
stale_doctor_codex_home="$TMP_ROOT/stale-doctor-codex"
stale_doctor_alarm_home="$stale_doctor_codex_home/alarm"
stale_doctor_log="$TMP_ROOT/doctor-stale-hooks.log"
mkdir -p "$stale_doctor_codex_home" "$stale_doctor_alarm_home"
cp "$ROOT/bin/alarm" "$stale_doctor_alarm_home/alarm"
chmod +x "$stale_doctor_alarm_home/alarm"
printf 'CODEX_ALARM_SOUND="Glass"\n' > "$stale_doctor_alarm_home/config"
cat > "$stale_doctor_codex_home/hooks.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/old/alarm/alarm pre",
            "timeout": 1,
            "statusMessage": "Codex Alarm: old other event"
          }
        ]
      }
    ]
  }
}
JSON
PATH="/usr/bin:/bin" CODEX_HOME="$stale_doctor_codex_home" CODEX_ALARM_HOME="$stale_doctor_alarm_home" CODEX_ALARM_ACTIVATE_BUNDLE_ID='' "$stale_doctor_alarm_home/alarm" doctor > "$stale_doctor_log" 2>&1
grep -q 'hooks: Codex Alarm entries 1' "$stale_doctor_log"
grep -q 'hooks: Stop hook entries 0' "$stale_doctor_log"
grep -q 'hooks: PermissionRequest hook entries 0' "$stale_doctor_log"
grep -q 'WARN hooks: Stop hook not found' "$stale_doctor_log"
grep -q 'WARN hooks: PermissionRequest hook not found' "$stale_doctor_log"
if grep -q 'hooks: required entries present' "$stale_doctor_log"; then
  echo "doctor reported required hooks for stale-only setup" >&2
  exit 1
fi
test -x "$stale_doctor_alarm_home/alarm"
grep -q 'CODEX_ALARM_SOUND="Glass"' "$stale_doctor_alarm_home/config"
test ! -e "$stale_doctor_alarm_home/state.json"

echo "uninstall dry-run"
uninstall_codex_home="$TMP_ROOT/uninstall-codex"
uninstall_alarm_home="$uninstall_codex_home/alarm"
uninstall_home="$TMP_ROOT/uninstall-home"
uninstall_shell_config="$uninstall_home/.zshrc"
uninstall_log="$TMP_ROOT/uninstall-dry-run.log"
mkdir -p "$uninstall_codex_home" "$uninstall_alarm_home" "$uninstall_home/.local/bin"
cp "$ROOT/bin/alarm" "$uninstall_alarm_home/alarm"
chmod +x "$uninstall_alarm_home/alarm"
ln -s "$uninstall_alarm_home/alarm" "$uninstall_home/.local/bin/agent-alarm"
cat > "$uninstall_shell_config" <<'EOF'
export BEFORE_CODEX_ALARM=1
# >>> Codex Alarm agent-alarm PATH >>>
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
# <<< Codex Alarm agent-alarm PATH <<<
export AFTER_CODEX_ALARM=1
EOF
printf 'CODEX_ALARM_SOUND="Submarine"\n' > "$uninstall_alarm_home/config"
cat > "$uninstall_codex_home/hooks.json" <<JSON
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
            "command": "\\"$uninstall_alarm_home/alarm\\" stop",
            "timeout": 5,
            "statusMessage": "Codex Alarm: notifying completion"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\\"$uninstall_alarm_home/alarm\\" permission",
            "timeout": 5,
            "statusMessage": "Codex Alarm: notifying approval request"
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
            "statusMessage": "Old alarm command"
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
cp "$uninstall_codex_home/hooks.json" "$TMP_ROOT/hooks-before-dry-run.json"
cp "$uninstall_alarm_home/config" "$TMP_ROOT/config-before-dry-run"
cp "$uninstall_shell_config" "$TMP_ROOT/shell-before-dry-run"
HOME="$uninstall_home" CODEX_ALARM_SHELL_CONFIG="$uninstall_shell_config" CODEX_HOME="$uninstall_codex_home" CODEX_ALARM_HOME="$uninstall_alarm_home" "$ROOT/uninstall.sh" --dry-run > "$uninstall_log" 2>&1
grep -q 'DRY-RUN: would remove Codex Alarm hooks' "$uninstall_log"
grep -q 'DRY-RUN: would back up' "$uninstall_log"
grep -q "DRY-RUN: would remove $uninstall_alarm_home/alarm" "$uninstall_log"
grep -q "DRY-RUN: would remove $uninstall_home/.local/bin/agent-alarm" "$uninstall_log"
grep -q "DRY-RUN: would remove Codex Alarm PATH block from $uninstall_shell_config" "$uninstall_log"
grep -q 'DRY-RUN: would ask before removing' "$uninstall_log"
cmp "$uninstall_codex_home/hooks.json" "$TMP_ROOT/hooks-before-dry-run.json"
cmp "$uninstall_alarm_home/config" "$TMP_ROOT/config-before-dry-run"
cmp "$uninstall_shell_config" "$TMP_ROOT/shell-before-dry-run"
test -x "$uninstall_alarm_home/alarm"
test -L "$uninstall_home/.local/bin/agent-alarm"
test "$(find "$uninstall_codex_home" -name 'hooks.json.codex-alarm-backup-*' -type f | wc -l | tr -d '[:space:]')" = "0"

echo "uninstall invalid hooks"
bad_uninstall_codex_home="$TMP_ROOT/bad-uninstall-codex"
bad_uninstall_alarm_home="$bad_uninstall_codex_home/alarm"
bad_uninstall_home="$TMP_ROOT/bad-uninstall-home"
bad_uninstall_log="$TMP_ROOT/uninstall-bad-hooks.log"
mkdir -p "$bad_uninstall_codex_home" "$bad_uninstall_alarm_home"
cp "$ROOT/bin/alarm" "$bad_uninstall_alarm_home/alarm"
chmod +x "$bad_uninstall_alarm_home/alarm"
printf 'CODEX_ALARM_SOUND="Glass"\n' > "$bad_uninstall_alarm_home/config"
printf '{' > "$bad_uninstall_codex_home/hooks.json"
if HOME="$bad_uninstall_home" CODEX_HOME="$bad_uninstall_codex_home" CODEX_ALARM_HOME="$bad_uninstall_alarm_home" "$ROOT/uninstall.sh" --yes > "$bad_uninstall_log" 2>&1; then
  echo "uninstall succeeded with invalid hooks JSON" >&2
  exit 1
fi
grep -q 'invalid JSON' "$bad_uninstall_log"
test -x "$bad_uninstall_alarm_home/alarm"
test -f "$bad_uninstall_alarm_home/config"

echo "uninstall"
HOME="$uninstall_home" CODEX_ALARM_SHELL_CONFIG="$uninstall_shell_config" CODEX_HOME="$uninstall_codex_home" CODEX_ALARM_HOME="$uninstall_alarm_home" "$ROOT/uninstall.sh"
test ! -e "$uninstall_alarm_home/alarm"
test ! -e "$uninstall_home/.local/bin/agent-alarm"
grep -q 'export BEFORE_CODEX_ALARM=1' "$uninstall_shell_config"
grep -q 'export AFTER_CODEX_ALARM=1' "$uninstall_shell_config"
if grep -q 'Codex Alarm agent-alarm PATH' "$uninstall_shell_config"; then
  echo "Codex Alarm PATH block still present after uninstall" >&2
  exit 1
fi
test -f "$uninstall_alarm_home/config"
test "$(find "$uninstall_codex_home" -name 'hooks.json.codex-alarm-backup-*' -type f | wc -l | tr -d '[:space:]')" = "1"
grep -q 'Keep stop' "$uninstall_codex_home/hooks.json"
grep -q 'Keep other' "$uninstall_codex_home/hooks.json"
if grep -q 'Codex Alarm:\|/old/alarm/alarm' "$uninstall_codex_home/hooks.json"; then
  echo "Codex Alarm hooks still present after uninstall" >&2
  exit 1
fi
test -x "$TMP_ROOT/bin/terminal-notifier"

echo "uninstall removes config with yes"
yes_uninstall_codex_home="$TMP_ROOT/yes-uninstall-codex"
yes_uninstall_alarm_home="$yes_uninstall_codex_home/alarm"
yes_uninstall_home="$TMP_ROOT/yes-uninstall-home"
mkdir -p "$yes_uninstall_alarm_home"
cp "$ROOT/bin/alarm" "$yes_uninstall_alarm_home/alarm"
chmod +x "$yes_uninstall_alarm_home/alarm"
printf 'CODEX_ALARM_SOUND="Glass"\n' > "$yes_uninstall_alarm_home/config"
HOME="$yes_uninstall_home" CODEX_HOME="$yes_uninstall_codex_home" CODEX_ALARM_HOME="$yes_uninstall_alarm_home" "$ROOT/uninstall.sh" --yes
test ! -e "$yes_uninstall_alarm_home/alarm"
test ! -e "$yes_uninstall_alarm_home/config"
test ! -d "$yes_uninstall_alarm_home"

echo "ok"
