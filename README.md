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
| `osascript` | built-in banner + sound backend |
| `terminal-notifier` | optional, for full click-to-focus |

No npm, pip, Python package, Node package, `jq`, telemetry, or network access is required.

## What This Modifies

Codex Alarm is local-only. It does not send telemetry and does not make network requests.

The installer modifies your user-level Codex setup:

- installs `alarm` under `${CODEX_HOME:-~/.codex}/alarm/`
- creates `${CODEX_HOME:-~/.codex}/alarm/config` if missing
- writes dedupe state to `${CODEX_HOME:-~/.codex}/alarm/state.json` when permission notifications are sent
- updates `${CODEX_HOME:-~/.codex}/hooks.json`
- creates a timestamped backup beside `hooks.json` before editing it

The hook entries run local commands on Codex lifecycle events. Codex will still require you to review and trust the hooks with `/hooks`.

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

Banner + sound works with macOS built-in `osascript`. Clicking the banner to focus your terminal requires optional `terminal-notifier`.

Install it with Homebrew:

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

`CODEX_ALARM_BACKEND="auto"` uses `terminal-notifier` when it is installed and falls back to `osascript` when it is not. The fallback still sends a banner and sound, but clicking the notification will not reliably focus your terminal.

You can force a backend in `~/.codex/alarm/config`:

```sh
CODEX_ALARM_BACKEND="osascript"
CODEX_ALARM_BACKEND="terminal-notifier"
```

If `terminal-notifier` is requested but unavailable, Codex Alarm falls back to `osascript` so Codex hooks keep running silently and successfully.

## Configuration

Default config:

```sh
CODEX_ALARM_BACKEND="auto"
CODEX_ALARM_ACTIVATE_BUNDLE_ID=""
CODEX_ALARM_SOUND="Glass"
CODEX_ALARM_NOTIFY_ON_STOP="1"
CODEX_ALARM_NOTIFY_ON_PERMISSION="1"
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

Temporary overrides are useful for quick checks:

```sh
CODEX_ALARM_SOUND="Ping" ~/.codex/alarm/alarm test
CODEX_ALARM_BACKEND="osascript" ~/.codex/alarm/alarm test
CODEX_ALARM_BACKEND="terminal-notifier" CODEX_ALARM_ACTIVATE_BUNDLE_ID="com.apple.Terminal" ~/.codex/alarm/alarm test
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
- Run `~/.codex/alarm/alarm doctor` and review any warnings.
- Install `terminal-notifier` for click-to-focus.
- After installing `terminal-notifier`, enable it in **System Settings > Notifications > terminal-notifier**.
- Turn off Focus / Do Not Disturb if notifications are delivered silently.
- Set `CODEX_ALARM_ACTIVATE_BUNDLE_ID` if clicking the notification does not focus your terminal.
- Confirm macOS allows notifications for the app sending them.
- Run `./uninstall.sh --dry-run` before uninstalling if you want to preview hook changes.

## License

MIT. See [LICENSE](LICENSE).
