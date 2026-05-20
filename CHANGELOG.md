# Changelog

## v0.1.0 - Initial repo version

- Added cleaned `rom_cleanup.sh` entrypoint.
- Fixed unset `$1` crash when running with no arguments.
- Replaced unreliable menu color output with safer `printf` handling.
- Added duplicate ROM detection by SHA256.
- Added quarantine-based ROM movement.
- Added duplicate `gamelist.xml` cleanup with backups.
- Added interactive same-name variant review.
- Added README, usage docs, safety notes, Makefile, smoke tests, and CI workflow.

## v0.1.1 - Repo polish

- Added MIT license.
- Added install and uninstall Makefile targets.
- Added EditorConfig and Git attributes.
- Added `make check` convenience target.
