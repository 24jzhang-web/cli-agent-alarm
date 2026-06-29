# Changelog

All notable changes to Codex Alarm will be documented here.

## 1.2.0 - 2026-06-28

- Added an `agent-alarm` convenience symlink and managed shell PATH setup for human CLI use while keeping hook commands on the absolute installed path.
- Added `agent-alarm status` as a concise everyday health summary, with latest-log visibility and fatal config/hooks validation.
- Added `agent-alarm sound` commands to import custom sounds, select built-in sounds, disable sound, and test the saved sound configuration.
- Added `agent-alarm config` for read-only effective config inspection and script-friendly config path output.
- Added `agent-alarm hooks` for read-only hook inspection with stale-entry and command-path mismatch reporting.
- Added `agent-alarm logs` for recent local notification attribution and backend failure entries.
- Documented common built-in macOS notification sound names and added doctor warnings for empty, path-like, or unknown sound values.
- Added macOS custom sound file support through `CODEX_ALARM_SOUND_FILE` using built-in `afplay`, with doctor diagnostics and hook-safe fallback behavior.
- Expanded `alarm doctor` and README troubleshooting with a read-only macOS presentation checklist for `terminal-notifier` permissions, banner style, sound settings, and Focus / Do Not Disturb.
- Added opt-in macOS built-in sound fallback through `CODEX_ALARM_SOUND_FALLBACK` for setups where banners appear but Notification Center stays silent.
- Improved macOS click-to-focus guidance, common bundle-ID detection, and doctor diagnostics for missing activation targets.

## 1.1.0 - 2026-06-28

- `terminal-notifier` is now the default backend for the intended macOS notification experience.
- `osascript` fallback is now explicit opt-in and disabled by default.
- Backend timeout and failure logging so stuck or rejected macOS notification helpers do not silently look successful.
- `alarm test` now fails on primary backend failure or timeout even when fallback delivery is attempted.
- README update instructions for existing v1 installs.

## 1.0.0 - 2026-06-27

- Initial macOS Codex CLI alarm design.
- User-level Codex hook installer.
- Completion and permission notification entrypoints.
- `terminal-notifier` support for click-to-focus.
- `osascript` fallback for banner + sound.
- Read-only diagnostics and smoke-test scaffolding.
- Public README, security policy, contribution guide, changelog, and issue templates.
