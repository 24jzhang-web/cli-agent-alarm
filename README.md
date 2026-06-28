# Codex Alarm

Lightweight local macOS banner + sound notifications for Codex CLI.

Codex Alarm alerts you when Codex needs attention:

- Codex finished a turn and is waiting for your next instruction.
- Codex is waiting for approval before taking an action.

It uses Codex lifecycle hooks, not terminal output scraping, and never approves or denies Codex actions.

## Compatibility

| Requirement | Status |
| --- | --- |
| macOS | v1 target platform |
| Codex CLI | supported through Codex hooks |
| `terminal-notifier` | recommended notification backend |
| `osascript` | explicit opt-in fallback backend |

No npm, pip, Python package, Node package, `jq`, telemetry, or network access is required.

## What This Modifies

Codex Alarm is local-only. It does not send telemetry and does not make network requests.

The installer modifies your user-level Codex setup:

- installs `alarm` under `${CODEX_HOME:-~/.codex}/alarm/`
- creates `${CODEX_HOME:-~/.codex}/alarm/config` if missing
- writes dedupe state to `${CODEX_HOME:-~/.codex}/alarm/state.json` when permission notifications are sent
- writes concise notification attribution logs to `${CODEX_HOME:-~/.codex}/alarm/alarm.log`
- updates `${CODEX_HOME:-~/.codex}/hooks.json`
- creates a timestamped backup beside `hooks.json` before editing it

The hook entries run local commands on Codex lifecycle events. They are user-level global hooks, so any active Codex CLI session using the same `CODEX_HOME` can trigger them. Codex will still require you to review and trust the hooks with `/hooks`.

## Install

Clone or download this repo first so you can inspect the scripts before running them.

```sh
git clone https://github.com/24jzhang-web/agent-cli-clarm.git
cd agent-cli-clarm
./install.sh --dry-run
./install.sh
```

If you downloaded a ZIP from GitHub, unzip it, open the folder in Terminal, then run the same `./install.sh --dry-run` and `./install.sh` commands.

The dry run prints planned file and hook changes without writing them.

For the intended macOS experience, install `terminal-notifier`:

```sh
brew install terminal-notifier
```

Codex Alarm uses `terminal-notifier` by default. macOS built-in `osascript` is available only when explicitly configured, because it can show notifications under a generic script identity and cannot reliably focus your terminal when clicked.

## Update from v1

If you installed an earlier v1 release from a Git clone, update the repo and rerun the installer:

```sh
cd agent-cli-clarm
git pull
./install.sh --dry-run
./install.sh
```

If you installed from a ZIP, download the new ZIP, unzip it, then run `./install.sh --dry-run` and `./install.sh` from the new folder.

The installer replaces the installed `~/.codex/alarm/alarm` executable, refreshes Codex Alarm hook entries, creates a timestamped `hooks.json` backup, preserves existing config values, and appends any new default config keys. After updating, restart Codex, run `/hooks`, review and trust the refreshed hooks, then run:

```sh
~/.codex/alarm/alarm test
~/.codex/alarm/alarm doctor
```

For v1.1, make sure `terminal-notifier` is installed and allowed in macOS Notification settings. `osascript` fallback is now disabled by default; enable `CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="1"` only if you intentionally want generic macOS script notifications when `terminal-notifier` is unavailable.

## Verify Install

Restart Codex, then run:

```text
/hooks
```

Review and trust the Codex Alarm hooks. Then test notifications and diagnostics:

```sh
~/.codex/alarm/alarm test
~/.codex/alarm/alarm doctor
```

## Full Click-to-Focus

`terminal-notifier` is the recommended backend. It gives Codex Alarm a clearer notification identity and supports clicking the banner to focus your terminal or Codex window.

Install it with Homebrew if you have not already:

```sh
brew install terminal-notifier
```

Then run a test once so macOS can register the notification sender:

```sh
~/.codex/alarm/alarm test
```

On many Macs, `terminal-notifier` starts with notifications disabled until you allow it. Open **System Settings > Notifications > terminal-notifier** and enable notifications, banners or alerts, and sounds. Also check that Focus / Do Not Disturb is not hiding banners.

Set your terminal app bundle ID in `~/.codex/alarm/config`:

```sh
CODEX_ALARM_ACTIVATE_BUNDLE_ID="com.apple.Terminal"
```

Common bundle IDs:

| App | Bundle ID |
| --- | --- |
| Terminal | `com.apple.Terminal` |
| iTerm2 | `com.googlecode.iterm2` |
| Ghostty | `com.mitchellh.ghostty` |
| Warp | `dev.warp.Warp-Stable` |
| VS Code | `com.microsoft.VSCode` |
| Cursor | `com.todesktop.230313mzl4w4u92` |

Find another app's bundle ID with:

```sh
osascript -e 'id of app "App Name"'
```

macOS controls whether notifications appear as temporary banners or persistent alerts in System Settings.

## Backend Behavior

`CODEX_ALARM_BACKEND="auto"` is the default. It selects `terminal-notifier`, which is the recommended backend for reliable notification identity and click-to-focus.

You can force a backend in `~/.codex/alarm/config`:

```sh
CODEX_ALARM_BACKEND="osascript"
CODEX_ALARM_BACKEND="terminal-notifier"
```

If `terminal-notifier` is unavailable, fails, or times out, Codex Alarm logs the failure and hook entrypoints still exit successfully so Codex is not blocked. `alarm test` exits nonzero and points to `alarm.log`.

`osascript` fallback is disabled by default:

```sh
CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="0"
```

Enable it only if you intentionally want built-in macOS script notifications when `terminal-notifier` is missing, failing, or timing out:

```sh
CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="1"
```

For normal use, keep `CODEX_ALARM_BACKEND="auto"` and install `terminal-notifier`.

Notification backend calls are capped by `CODEX_ALARM_BACKEND_TIMEOUT_SECONDS` so a stuck macOS notification helper does not make Codex wait indefinitely. Backend failures and timeouts are written to `~/.codex/alarm/alarm.log`.

## Configuration

Default config:

```sh
CODEX_ALARM_BACKEND="auto"
CODEX_ALARM_ACTIVATE_BUNDLE_ID=""
CODEX_ALARM_SOUND="Glass"
CODEX_ALARM_NOTIFY_ON_STOP="1"
CODEX_ALARM_NOTIFY_ON_PERMISSION="1"
CODEX_ALARM_BACKEND_TIMEOUT_SECONDS="3"
CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="0"
```

Environment variables override `~/.codex/alarm/config`.

Advanced paths:

```sh
CODEX_HOME="$HOME/.codex"
CODEX_ALARM_HOME="$CODEX_HOME/alarm"
```

Dry-run notification delivery:

```sh
CODEX_ALARM_DRY_RUN=1 ~/.codex/alarm/alarm test
```

`alarm test` prints whether `osascript` fallback is enabled. Missing, failing, or timed-out `terminal-notifier` makes `alarm test` exit nonzero even if an explicitly enabled `osascript` fallback can still deliver a banner afterward. It cannot prove macOS actually displayed a visible banner, because Notification Center, app notification permissions, and Focus / Do Not Disturb are controlled by macOS.

Temporary overrides are useful for quick checks:

```sh
CODEX_ALARM_SOUND="Ping" ~/.codex/alarm/alarm test
CODEX_ALARM_BACKEND="osascript" ~/.codex/alarm/alarm test
CODEX_ALARM_BACKEND="terminal-notifier" CODEX_ALARM_ACTIVATE_BUNDLE_ID="com.apple.Terminal" ~/.codex/alarm/alarm test
CODEX_ALARM_BACKEND="terminal-notifier" CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="0" ~/.codex/alarm/alarm test
```

## Commands

```sh
~/.codex/alarm/alarm test
~/.codex/alarm/alarm doctor
~/.codex/alarm/alarm version
```

Hook entrypoints are installed automatically:

```sh
~/.codex/alarm/alarm stop
~/.codex/alarm/alarm permission
```

Normal hook entrypoints are silent and exit successfully so they do not interfere with Codex.
Each real completion or approval notification attempt writes one concise line to `~/.codex/alarm/alarm.log` with the event, backend, project folder, tool when present, and short notification detail. Backend failures, timeouts, and fallback attempts are logged there too.

## Uninstall

```sh
./uninstall.sh --dry-run
./uninstall.sh
```

Uninstall removes only Codex Alarm hook entries and the installed alarm executable. It creates a hook backup before editing, leaves unrelated hooks untouched, asks before removing config, and does not remove `terminal-notifier`.

## Security

Codex Alarm installs user-level Codex hooks. Hooks run local commands when Codex lifecycle events occur.

Before installing, inspect:

- `bin/alarm`
- `install.sh`
- `uninstall.sh`

Codex Alarm never auto-approves or denies Codex actions. It only sends local notifications.

Codex Alarm is local-only: no telemetry, no analytics, and no network requests.

Do not use pipe-to-shell install commands unless you have inspected the code and accept that risk.

To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Troubleshooting

Run:

```sh
~/.codex/alarm/alarm doctor
```

Common checks:

- Restart Codex after install.
- Run `/hooks` and trust the Codex Alarm hooks.
- Install `terminal-notifier` for the recommended backend.
- After installing `terminal-notifier`, enable it in **System Settings > Notifications > terminal-notifier**.
- Run `~/.codex/alarm/alarm doctor` and review any warnings.
- Run `~/.codex/alarm/alarm test`; if it fails, check `~/.codex/alarm/alarm.log`.
- Keep `CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="0"` unless you intentionally want generic `osascript` fallback notifications.
- If a notification seems to come from the wrong project, check `~/.codex/alarm/alarm.log`; Codex Alarm hooks are user-level and can fire from any active Codex session using the same `CODEX_HOME`.
- Turn off Focus / Do Not Disturb if notifications are delivered silently.
- Set `CODEX_ALARM_ACTIVATE_BUNDLE_ID` if clicking the notification does not focus your terminal.
- Confirm macOS allows notifications for the app sending them.
- Run `./uninstall.sh --dry-run` before uninstalling if you want to preview hook changes.

## License

MIT. See [LICENSE](LICENSE).
