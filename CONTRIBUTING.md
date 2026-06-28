# Contributing

Thanks for improving Codex Alarm.

## Development Principles

- Keep the runtime lightweight and auditable.
- Avoid required package-manager dependencies.
- Do not vendor binaries or generated executables.
- Keep hook commands silent in normal operation.
- Preserve conservative install and uninstall behavior.

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
