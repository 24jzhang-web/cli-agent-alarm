#!/bin/bash
#
# Install Codex Alarm into the user-level Codex configuration.

set -euo pipefail

YES=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ALARM="$REPO_DIR/bin/alarm"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CODEX_ALARM_HOME="${CODEX_ALARM_HOME:-$CODEX_HOME/alarm}"
INSTALL_ALARM="$CODEX_ALARM_HOME/alarm"
CONFIG_FILE="$CODEX_ALARM_HOME/config"
HOOKS_FILE="$CODEX_HOME/hooks.json"

is_interactive() {
  [ -t 0 ] && [ -t 1 ]
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_bundle_id() {
  case "${TERM_PROGRAM-}" in
    Apple_Terminal) printf '%s' "com.apple.Terminal" ;;
    iTerm.app) printf '%s' "com.googlecode.iterm2" ;;
    vscode) printf '%s' "com.microsoft.VSCode" ;;
    Cursor) printf '%s' "com.todesktop.230313mzl4w4u92" ;;
    ghostty|Ghostty) printf '%s' "com.mitchellh.ghostty" ;;
    WarpTerminal) printf '%s' "dev.warp.Warp-Stable" ;;
    *) printf '%s' "" ;;
  esac
}

validate_hooks_json() {
  [ -f "$HOOKS_FILE" ] || return 0
  /usr/bin/osascript -l JavaScript - "$HOOKS_FILE" <<'JXA' >/dev/null
function run(argv) {
  ObjC.import('Foundation');
  var text = ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null));
  JSON.parse(text || '{}');
}
JXA
}

config_has_key() {
  local key="$1"
  [ -f "$CONFIG_FILE" ] || return 1
  grep -Eq "^[[:space:]]*$key[[:space:]]*=" "$CONFIG_FILE"
}

ensure_config_key() {
  local key="$1"
  local line="$2"

  config_has_key "$key" && return 0
  printf '%s\n' "$line" >> "$CONFIG_FILE"
}

write_hooks_json() {
  local dry="$1"
  /usr/bin/osascript -l JavaScript - "$HOOKS_FILE" "$INSTALL_ALARM" "$dry" <<'JXA'
function run(argv) {
  ObjC.import('Foundation');
  var hooksPath = argv[0];
  var alarmPath = argv[1];
  var dryRun = argv[2] === '1';
  var fm = $.NSFileManager.defaultManager;

  function readText(path) {
    if (!fm.fileExistsAtPath(path)) return '';
    try {
      return ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null)) || '';
    } catch (error) {
      return '';
    }
  }

  function writeText(path, value) {
    var text = $.NSString.alloc.initWithUTF8String(String(value));
    return text.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
  }

  var existing = readText(hooksPath);
  var doc = existing ? JSON.parse(existing) : {};
  if (!doc || typeof doc !== 'object' || Array.isArray(doc)) doc = {};
  if (!doc.hooks || typeof doc.hooks !== 'object' || Array.isArray(doc.hooks)) doc.hooks = {};

  function isAlarmHook(hook) {
    if (!hook || typeof hook !== 'object') return false;
    var command = String(hook.command || '');
    var status = String(hook.statusMessage || hook.status_message || '');
    return status.indexOf('Codex Alarm:') === 0 ||
      command.indexOf('/alarm/alarm') !== -1 ||
      command.indexOf(alarmPath) !== -1;
  }

  function cleanEvent(eventName) {
    var groups = Array.isArray(doc.hooks[eventName]) ? doc.hooks[eventName] : [];
    var next = [];
    groups.forEach(function(group) {
      if (!group || typeof group !== 'object') return;
      var hooks = Array.isArray(group.hooks) ? group.hooks.filter(function(hook) { return !isAlarmHook(hook); }) : [];
      if (hooks.length > 0) {
        group.hooks = hooks;
        next.push(group);
      }
    });
    if (next.length > 0) doc.hooks[eventName] = next;
    else delete doc.hooks[eventName];
  }

  Object.keys(doc.hooks).forEach(cleanEvent);

  function addEvent(eventName, subcommand, statusMessage) {
    if (!Array.isArray(doc.hooks[eventName])) doc.hooks[eventName] = [];
    doc.hooks[eventName].push({
      hooks: [{
        type: 'command',
        command: '"' + alarmPath + '" ' + subcommand,
        timeout: 10,
        statusMessage: statusMessage
      }]
    });
  }

  addEvent('Stop', 'stop', 'Codex Alarm: notifying completion');
  addEvent('PermissionRequest', 'permission', 'Codex Alarm: notifying approval request');

  var output = JSON.stringify(doc, null, 2) + '\n';
  if (dryRun) {
    console.log(output);
    return;
  }
  writeText(hooksPath, output);
}
JXA
}

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: Codex Alarm v1 supports macOS only." >&2
  exit 1
fi

if ! command_exists /usr/bin/osascript; then
  echo "ERROR: /usr/bin/osascript is required." >&2
  exit 1
fi

if [ ! -f "$SOURCE_ALARM" ]; then
  echo "ERROR: missing source executable: $SOURCE_ALARM" >&2
  exit 1
fi

if ! validate_hooks_json; then
  echo "ERROR: existing hooks file is invalid JSON: $HOOKS_FILE" >&2
  echo "No changes were made. Fix or move that file, then rerun install." >&2
  exit 1
fi

echo "Codex Alarm install"
echo "CODEX_HOME: $CODEX_HOME"
echo "CODEX_ALARM_HOME: $CODEX_ALARM_HOME"
echo "Install executable: $INSTALL_ALARM"
echo "Hooks file: $HOOKS_FILE"

if ! command_exists codex; then
  echo "WARN: codex not found on PATH; continuing anyway."
fi

if ! command_exists terminal-notifier; then
  echo "WARN: terminal-notifier missing; default notification backend will be unavailable."
  echo "Install manually with: brew install terminal-notifier"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: would offer Homebrew install in interactive mode."
  elif [ "$YES" -eq 0 ] && is_interactive && command_exists brew; then
    printf "Install terminal-notifier with Homebrew for click-to-focus? [y/N] "
    read -r answer
    case "$answer" in
      y|Y|yes|YES) brew install terminal-notifier ;;
    esac
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY-RUN: would create $CODEX_ALARM_HOME"
  echo "DRY-RUN: would install $INSTALL_ALARM"
  if [ -f "$CONFIG_FILE" ]; then
    config_has_key CODEX_ALARM_BACKEND_TIMEOUT_SECONDS || echo "DRY-RUN: would append CODEX_ALARM_BACKEND_TIMEOUT_SECONDS to $CONFIG_FILE"
    config_has_key CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK || echo "DRY-RUN: would append CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK to $CONFIG_FILE"
  else
    echo "DRY-RUN: would create $CONFIG_FILE"
  fi
  [ -f "$HOOKS_FILE" ] && echo "DRY-RUN: would back up $HOOKS_FILE"
  echo "DRY-RUN: would write Codex Alarm hooks:"
  write_hooks_json 1
  exit 0
fi

mkdir -p "$CODEX_ALARM_HOME"

tmp_alarm="$CODEX_ALARM_HOME/.alarm.tmp.$$"
cp "$SOURCE_ALARM" "$tmp_alarm"
chmod +x "$tmp_alarm"
mv "$tmp_alarm" "$INSTALL_ALARM"

if [ ! -f "$CONFIG_FILE" ]; then
  detected_bundle_id="$(detect_bundle_id)"
  cat > "$CONFIG_FILE" <<EOF
CODEX_ALARM_BACKEND="auto"
CODEX_ALARM_ACTIVATE_BUNDLE_ID="$detected_bundle_id"
CODEX_ALARM_SOUND="Glass"
CODEX_ALARM_NOTIFY_ON_STOP="1"
CODEX_ALARM_NOTIFY_ON_PERMISSION="1"
CODEX_ALARM_BACKEND_TIMEOUT_SECONDS="3"
CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="0"
EOF
else
  ensure_config_key CODEX_ALARM_BACKEND_TIMEOUT_SECONDS 'CODEX_ALARM_BACKEND_TIMEOUT_SECONDS="3"'
  ensure_config_key CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK 'CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="0"'
fi

mkdir -p "$CODEX_HOME"
backup_path=""
if [ -f "$HOOKS_FILE" ]; then
  backup_path="$HOOKS_FILE.codex-alarm-backup-$(date +%Y%m%d-%H%M%S)"
  cp "$HOOKS_FILE" "$backup_path"
fi
write_hooks_json 0

echo "Installed Codex Alarm."
[ -n "$backup_path" ] && echo "Hooks backup: $backup_path"
cat <<EOF

Next steps:
1. Restart Codex.
2. Run /hooks inside Codex.
3. Review and trust the Codex Alarm hooks.
4. Run $INSTALL_ALARM test.
EOF

if [ "$YES" -eq 0 ] && is_interactive; then
  printf "Run alarm test now? [Y/n] "
  read -r answer
  case "$answer" in
    n|N|no|NO) ;;
    *) "$INSTALL_ALARM" test ;;
  esac
fi
