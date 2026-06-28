# Changelog

All notable changes to Codex Alarm will be documented here.

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
