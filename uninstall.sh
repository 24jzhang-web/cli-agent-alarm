#!/bin/bash
#
# Uninstall Codex Alarm from the user-level Codex configuration.

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

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CODEX_ALARM_HOME="${CODEX_ALARM_HOME:-$CODEX_HOME/alarm}"
INSTALL_ALARM="$CODEX_ALARM_HOME/alarm"
CONFIG_FILE="$CODEX_ALARM_HOME/config"
HOOKS_FILE="$CODEX_HOME/hooks.json"

is_interactive() {
  [ -t 0 ] && [ -t 1 ]
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

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

write_hooks_json() {
  local dry="$1"
  /usr/bin/osascript -l JavaScript - "$HOOKS_FILE" "$INSTALL_ALARM" "$dry" <<'JXA'
function run(argv) {
  ObjC.import('Foundation');
  var hooksPath = argv[0];
  var alarmPath = argv[1];
  var dryRun = argv[2] === '1';

  function readText(path) {
    if (!$.NSFileManager.defaultManager.fileExistsAtPath(path)) return '';
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

  Object.keys(doc.hooks).forEach(function(eventName) {
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
  });

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

if [ -f "$HOOKS_FILE" ] && ! validate_hooks_json; then
  echo "ERROR: existing hooks file is invalid JSON: $HOOKS_FILE" >&2
  echo "No changes were made. Fix that file, then rerun uninstall." >&2
  exit 1
fi

echo "Codex Alarm uninstall"
echo "CODEX_HOME: $CODEX_HOME"
echo "CODEX_ALARM_HOME: $CODEX_ALARM_HOME"

if [ "$DRY_RUN" -eq 1 ]; then
  [ -f "$HOOKS_FILE" ] && echo "DRY-RUN: would remove Codex Alarm hooks from $HOOKS_FILE"
  [ -f "$HOOKS_FILE" ] && echo "DRY-RUN: would back up $HOOKS_FILE before editing"
  [ -f "$INSTALL_ALARM" ] && echo "DRY-RUN: would remove $INSTALL_ALARM"
  if [ -f "$CONFIG_FILE" ]; then
    if [ "$YES" -eq 1 ]; then
      echo "DRY-RUN: would remove $CONFIG_FILE"
    else
      echo "DRY-RUN: would ask before removing $CONFIG_FILE"
    fi
  fi
  [ -f "$HOOKS_FILE" ] && write_hooks_json 1
  exit 0
fi

backup_path=""
if [ -f "$HOOKS_FILE" ]; then
  backup_path="$HOOKS_FILE.codex-alarm-backup-$(date +%Y%m%d-%H%M%S)"
  cp "$HOOKS_FILE" "$backup_path"
  write_hooks_json 0
fi

rm -f "$INSTALL_ALARM"

remove_config=0
if [ -f "$CONFIG_FILE" ]; then
  if [ "$YES" -eq 1 ]; then
    remove_config=1
  elif is_interactive; then
    printf "Remove Codex Alarm config at %s? [y/N] " "$CONFIG_FILE"
    read -r answer
    case "$answer" in
      y|Y|yes|YES) remove_config=1 ;;
    esac
  fi
fi

[ "$remove_config" -eq 1 ] && rm -f "$CONFIG_FILE"
rmdir "$CODEX_ALARM_HOME" 2>/dev/null || true

echo "Uninstalled Codex Alarm."
[ -n "$backup_path" ] && echo "Hooks backup: $backup_path"
echo "terminal-notifier was not removed."
