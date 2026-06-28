# Security Policy

## Supported Versions

Codex Alarm is pre-1.0. Security fixes are made on `main` until the first tagged release.

## Reporting a Vulnerability

Please report security issues privately through GitHub's private vulnerability reporting if it is enabled for this repository.

If private reporting is not available, open an issue with minimal detail and ask for a private contact path. Do not include exploit details, sensitive local paths, tokens, or private hook payloads in a public issue.

## Scope

Security-sensitive areas include:

- editing `~/.codex/hooks.json`
- hook command execution
- config parsing
- notification payload handling
- installer and uninstaller behavior

Codex Alarm is intended to be local-only. It should not send telemetry or make network requests.

## Trust Model

Codex Alarm installs local Codex hooks. Codex requires users to review and trust hook definitions with `/hooks`.

The alarm must never auto-approve or deny Codex actions. It only sends notifications and exits successfully.

Install and uninstall scripts should preserve unrelated hook entries, back up hook changes, and avoid hidden package-manager installs.
