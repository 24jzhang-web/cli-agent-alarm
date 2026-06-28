# Release Checklist

Use this checklist before tagging or publishing a release.

## Automated Checks

```sh
test/smoke.sh
bash -n bin/alarm install.sh uninstall.sh test/smoke.sh
shellcheck bin/alarm install.sh uninstall.sh test/smoke.sh
```

Confirm the GitHub Actions smoke workflow passes on macOS.

## Manual Local Checks

1. Run `./install.sh --dry-run` and confirm the planned `alarm` install path, `config` creation, `hooks.json` update, and hook backup are expected.
2. Run `./install.sh`, restart Codex, then run `/hooks` inside Codex and review/trust the Codex Alarm hooks.
3. Run `~/.codex/alarm/alarm test` and confirm real macOS banner and sound delivery.
4. If `terminal-notifier` is installed, set `CODEX_ALARM_ACTIVATE_BUNDLE_ID` and confirm clicking the notification focuses the terminal or Codex window.
5. Run `~/.codex/alarm/alarm doctor` and confirm warnings are expected for the local machine.
6. Run `./uninstall.sh --dry-run` and confirm unrelated hooks are preserved in the preview.
7. Run `./uninstall.sh` and confirm only Codex Alarm hooks and the installed executable are removed.

Do not include local `docs/CONTEXT.md`, `docs/research-*.md`, `docs/prd/`, or `docs/issues/` artifacts in release commits.
