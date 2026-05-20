# Contributing

## Local checks

Run:

```bash
make test
make lint
```

`make lint` requires ShellCheck. If ShellCheck is not installed, the Makefile prints a warning and skips linting.

## Style

- Prefer safe shell patterns: `set -Eeuo pipefail`, quoted variables, and `--` before file paths where appropriate.
- Do not permanently delete user ROM files from the script.
- Preserve backup-first behavior for any command that edits `gamelist.xml`.
- Keep interactive prompts clear and conservative.
