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
- creates or refreshes a convenience symlink at `~/.local/bin/agent-alarm`
- adds `~/.local/bin` to your shell startup file with a marked Codex Alarm block when needed
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

The installer also sets up the short `agent-alarm` command by adding `~/.local/bin` to your shell startup file, such as `~/.zshrc` or `~/.bashrc`. If your current terminal does not see it immediately, open a new terminal or source the file printed by the installer.

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

The installer replaces the installed `~/.codex/alarm/alarm` executable, refreshes the `agent-alarm` convenience symlink, refreshes Codex Alarm hook entries, creates a timestamped `hooks.json` backup, preserves existing config values, and appends any new default config keys. After updating, restart Codex, run `/hooks`, review and trust the refreshed hooks, then run:

```sh
agent-alarm test
agent-alarm status
agent-alarm doctor
```

For v1.1 and later, make sure `terminal-notifier` is installed and allowed in macOS Notification settings. `osascript` fallback is disabled by default; enable `CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="1"` only if you intentionally want generic macOS script notifications when `terminal-notifier` is unavailable.

## Verify Install

Restart Codex, then run:

```text
/hooks
```

Review and trust the Codex Alarm hooks. Then test notifications and diagnostics:

```sh
agent-alarm test
agent-alarm status
agent-alarm doctor
```

If `agent-alarm` is not found, use the full installed path:

```sh
~/.codex/alarm/alarm test
~/.codex/alarm/alarm status
~/.codex/alarm/alarm doctor
```

You can also add the command path manually:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## Full Click-to-Focus

`terminal-notifier` is the recommended backend. It gives Codex Alarm a clearer notification identity and supports clicking the banner to focus your terminal or Codex window.

Install it with Homebrew if you have not already:

```sh
brew install terminal-notifier
```

Then run a test once so macOS can register the notification sender:

```sh
agent-alarm test
```

On many Macs, `terminal-notifier` starts with notifications disabled until you allow it. Open **System Settings > Notifications > terminal-notifier** and enable notifications, banners or alerts, and sounds. Also check that Focus / Do Not Disturb is not hiding banners.

Codex Alarm auto-detects common macOS terminal/editor hosts from `TERM_PROGRAM` and a conservative parent-process check. Explicit config always wins, so set your terminal app bundle ID in `~/.codex/alarm/config` if clicking the notification opens the wrong app or does nothing:

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

Then add it to `~/.codex/alarm/config`:

```sh
CODEX_ALARM_ACTIVATE_BUNDLE_ID="com.example.YourApp"
```

Run `agent-alarm doctor` to confirm the configured target, then run `agent-alarm test` and click the notification.

This activation behavior is macOS-specific and uses `terminal-notifier -activate <bundle-id>`. Windows notification activation is intentionally not promised here; Windows foreground-window rules are different and are planned for a separate Windows support slice.

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
CODEX_ALARM_SOUND_FILE=""
CODEX_ALARM_SOUND_FALLBACK="0"
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
CODEX_ALARM_DRY_RUN=1 agent-alarm test
```

`alarm test` prints whether `osascript` fallback is enabled. Missing, failing, or timed-out `terminal-notifier` makes `alarm test` exit nonzero even if an explicitly enabled `osascript` fallback can still deliver a banner afterward. It cannot prove macOS actually displayed a visible banner, because Notification Center, app notification permissions, and Focus / Do Not Disturb are controlled by macOS.

Temporary overrides are useful for quick checks:

```sh
CODEX_ALARM_SOUND="Ping" agent-alarm test
CODEX_ALARM_BACKEND="osascript" agent-alarm test
CODEX_ALARM_BACKEND="terminal-notifier" CODEX_ALARM_ACTIVATE_BUNDLE_ID="com.apple.Terminal" agent-alarm test
CODEX_ALARM_BACKEND="terminal-notifier" CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="0" agent-alarm test
```

## Sound Selection

`CODEX_ALARM_SOUND` uses a built-in macOS notification sound name. Common built-in names include:

```text
Basso
Blow
Bottle
Frog
Funk
Glass
Hero
Morse
Ping
Pop
Purr
Sosumi
Submarine
Tink
```

Set one with the sound command:

```sh
agent-alarm sound set Ping
```

Or test one temporarily:

```sh
CODEX_ALARM_SOUND="Submarine" agent-alarm test
```

Run `agent-alarm doctor` after changing it. Doctor warns when the sound is empty, looks like a file path, or is not found in `/System/Library/Sounds`.

For a custom macOS sound file, import a readable local file. Codex Alarm copies it into a managed `~/.codex/alarm/sounds` folder and updates config to use that copy:

```sh
agent-alarm sound import ~/Music/codex-done.mp3
```

Common formats such as `.mp3`, `.m4a`, `.wav`, and `.aiff` can work without extra runtime packages because Codex Alarm plays custom files with macOS `afplay`.

To disable all notification sound while keeping banners enabled:

```sh
agent-alarm sound off
```

To test the saved sound configuration:

```sh
agent-alarm sound test
```

Temporary overrides still work for quick checks:

```sh
CODEX_ALARM_SOUND_FILE="$HOME/Music/codex-done.mp3" agent-alarm test
```

When `CODEX_ALARM_SOUND_FILE` is set, Codex Alarm suppresses the built-in notification sound and plays the custom file separately. This keeps banner delivery separate from audio playback, so a missing or unreadable custom sound file is logged and warned about by `doctor`, but hooks still stay silent and do not block Codex.

If macOS shows banners but does not play notification sound, enable the explicit sound fallback:

```sh
CODEX_ALARM_SOUND_FALLBACK="1"
```

The fallback uses `/usr/bin/afplay` to play the configured built-in `CODEX_ALARM_SOUND` after banner delivery succeeds. It is off by default because it can duplicate normal notification sounds. It is ignored when `CODEX_ALARM_SOUND_FILE` is configured, since custom sound files already play separately.

Windows custom sounds are deferred until after the Windows notification backend research/MVP.
Windows sound fallback behavior is also deferred until Windows notification support is implemented and tested.

## Commands

```sh
agent-alarm test
agent-alarm sound import ~/Music/codex-done.mp3
agent-alarm sound set Ping
agent-alarm sound off
agent-alarm sound test
agent-alarm status
agent-alarm config
agent-alarm hooks
agent-alarm logs
agent-alarm doctor
agent-alarm version
```

Use `agent-alarm status` as the quick first check. It prints the installed path, hook presence, backend, notification flags, sound summary, click target, log path, and latest log line. Use `agent-alarm doctor` when you need the deeper troubleshooting checklist.
Use `agent-alarm config` to inspect the effective read-only configuration after config-file loading and environment overrides. Use `agent-alarm config path` to print only the config file path.
Use `agent-alarm hooks` for hook-specific inspection. It reads user-level `hooks.json` and reports Codex Alarm hook entries, command paths, timeouts, status messages, stale entries, missing entries, invalid JSON, and command path mismatches without editing or trusting hooks.
Use `agent-alarm logs` to inspect recent notification attribution and backend failure entries. Use `agent-alarm logs --tail 50` for more lines, or `agent-alarm logs path` to print only the log file path.

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

Uninstall removes only Codex Alarm hook entries, the installed alarm executable, the `agent-alarm` symlink when it points at Codex Alarm, and the marked Codex Alarm PATH block from your shell startup file. It creates backups before editing hooks or an existing shell startup file, leaves unrelated hooks and shell config untouched, asks before removing config, and does not remove `terminal-notifier`.

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

Start with:

```sh
agent-alarm status
```

If that surfaces a problem or notifications still do not appear, run:

```sh
agent-alarm doctor
```

Common checks:

Hook checks:

- Restart Codex after install.
- Run `/hooks` and trust the Codex Alarm hooks.
- Run `agent-alarm hooks` to inspect hook entries, command paths, timeouts, and stale or mismatched entries. `/hooks` remains the Codex UI for reviewing and trusting hooks.
- If a notification seems to come from the wrong project, run `agent-alarm logs`; Codex Alarm hooks are user-level and can fire from any active Codex session using the same `CODEX_HOME`.

Backend checks:

- Install `terminal-notifier` for the recommended backend.
- Run `agent-alarm doctor` and review the hook, backend resolution, backend availability, and presentation sections.
- Run `agent-alarm test`; if it fails, run `agent-alarm logs` to inspect backend failures and fallback attempts.
- Keep `CODEX_ALARM_ALLOW_OSASCRIPT_FALLBACK="0"` unless you intentionally want generic `osascript` fallback notifications.
- Set `CODEX_ALARM_ACTIVATE_BUNDLE_ID` if clicking the notification does not focus your terminal.

macOS presentation checks:

- After installing `terminal-notifier`, open **System Settings > Notifications > terminal-notifier**.
- Enable notifications.
- Set the alert style to Banners or Alerts.
- Enable Sounds if you expect notification sound.
- Turn off Focus / Do Not Disturb, or configure Focus to allow `terminal-notifier`.
- Run `agent-alarm test` again after changing macOS settings.

`alarm doctor` is read-only. It does not require elevated permissions and does not inspect or change macOS Notification Center state; macOS controls whether a delivered notification is shown, hidden, or silenced.

Windows notification diagnostics are planned under the Windows support issues, not this macOS diagnostic slice.

Run `./uninstall.sh --dry-run` before uninstalling if you want to preview hook changes.

## License

MIT. See [LICENSE](LICENSE).
