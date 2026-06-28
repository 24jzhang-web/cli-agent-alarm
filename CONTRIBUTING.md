# Contributing

Thanks for improving Codex Alarm.

## Development Principles

- Keep the runtime lightweight and auditable.
- Avoid required package-manager dependencies.
- Do not vendor binaries or generated executables.
- Keep the default path local-only: no telemetry, analytics, or network calls.
- Keep hook commands silent in normal operation.
- Preserve conservative install and uninstall behavior.
- Document installer, hook, config, and uninstall behavior before changing it.

## Local Checks

Run smoke tests:

```sh
test/smoke.sh
```

If ShellCheck is installed, run:

```sh
shellcheck bin/alarm install.sh uninstall.sh test/smoke.sh
```

## Pull Requests

Please include:

- what changed
- how you tested it
- whether install, uninstall, or hook behavior changed

Security-sensitive changes should be small and easy to review.

Do not include private Codex prompts, tokens, local hook payloads, or machine-specific paths in issues or pull requests unless they are scrubbed.
