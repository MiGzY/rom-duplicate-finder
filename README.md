# ROM Cleanup Suite

A small Bash tool for cleaning retro ROM collections and EmulationStation-style `gamelist.xml` files.

It helps you:

- find exact duplicate ROM files by SHA256 hash;
- move duplicate ROM copies into a quarantine folder instead of deleting them;
- remove duplicate `gamelist.xml` entries that point to the same ROM path;
- review same-name game variants and choose which ROM entry to keep.

The script is designed for Linux handheld / desktop environments such as Bazzite, SteamOS-like systems, and other Bash-based setups.

## Safety model

ROM Cleanup Suite is intentionally conservative:

- ROM files are moved to quarantine folders, not permanently deleted.
- `gamelist.xml` is backed up before it is changed.
- duplicate gamelist entries are previewed before removal.
- variant removal is interactive.

Even so, make a backup of your ROM directory before running cleanup on a collection you care about.

## Requirements

- Bash 4 or newer
- Python 3, for `gamelist.xml` operations
- standard Linux tools: `find`, `sort`, `sha256sum`, `stat`, `awk`, `mv`, `cp`

## Quick start

```bash
git clone https://github.com/MiGzY/rom-cleanup-suite/
cd rom-cleanup-suite
chmod +x rom_cleanup.sh
./rom_cleanup.sh
```

To view help:

```bash
./rom_cleanup.sh --help
```

## Menu options

```text
[1] Find and move exact duplicate ROM files
[2] Clean duplicate gamelist.xml entries
[3] Find and remove game variants interactively
[4] Exit
```

### 1. Find and move exact duplicate ROM files

This option scans a ROM directory, hashes files with SHA256, and reports exact byte-for-byte duplicates. You can choose whether to scan only the top-level directory or scan recursively.

When duplicates are found, the first copy discovered is kept and later matching copies can be moved into a timestamped quarantine folder inside the ROM directory.

### 2. Clean duplicate `gamelist.xml` entries

This option looks for repeated `<game>` entries with the same `<path>` value. When duplicates are found, it keeps the entry with the most metadata and removes the others after confirmation.

Before writing changes, it creates a backup like:

```text
gamelist.xml.backup_20260520_123456
```

### 3. Find and remove game variants interactively

This option finds games with the same `<name>` but different `<path>` values. For each group, you choose which ROM path to keep. The removed entries are deleted from `gamelist.xml` only after confirmation.

You can also choose to move the removed ROM files into a timestamped quarantine folder next to the gamelist.

## Typical paths

On Bazzite or similar systems, ROM directories are often under paths like:

```text
/var/home/<user>/Emulation/roms
/var/home/<user>/ROMs
```

Example gamelist paths may look like:

```text
/var/home/<user>/Emulation/roms/snes/gamelist.xml
/var/home/<user>/.emulationstation/gamelists/snes/gamelist.xml
```

Your setup may differ, especially if you use EmuDeck, RetroDECK, or custom folders.

## Development

Run the smoke tests:

```bash
make test
```

Run all local checks:

```bash
make check
```

Run only ShellCheck if it is installed:

```bash
make lint
```

Install a `rom-cleanup` command into `~/.local/bin`:

```bash
make install
```

Uninstall it:

```bash
make uninstall
```

## Versioning

This repo starts at `v0.1.0`.

## License

MIT. See [`LICENSE`](LICENSE).
