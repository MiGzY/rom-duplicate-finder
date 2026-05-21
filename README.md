# ROM Cleanup Suite

A Bash tool for cleaning retro ROM collections and EmulationStation/ES-DE-style `gamelist.xml` files.

This version is designed around the issues found while cleaning RetroDECK/ES-DE MAME lists:

- the `gamelist.xml` directory can be different from the real ROM directory;
- MAME regional/clone sets can depend on parent, BIOS, device, or CHD data;
- metadata can disappear if the script keeps a bare entry and removes the scraped entry;
- orphan entries need a dedicated pass because duplicate cleanup does not catch missing files.

## Safety model

ROM Cleanup Suite is conservative by default:

- ROM files are moved to quarantine folders, not permanently deleted.
- `gamelist.xml` is backed up before every write.
- same-name regional/clone cleanup edits `gamelist.xml` only; it does **not** move ROM ZIPs.
- duplicate and variant gamelist cleanup merges missing metadata into the kept entry before removing anything.
- relative paths like `./game.zip` are resolved against the ROM directory you enter, not the gamelist directory.

Close ES-DE/RetroDECK before editing `gamelist.xml`.

## Requirements

- Bash 4 or newer
- Python 3
- standard Linux tools: `find`, `sort`, `install`, `cp`, `mv`

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

Run checks:

```bash
make check
```

Install as `rom-cleanup`:

```bash
make install
rom-cleanup
```

## Menu options

```text
[1] Find and move exact duplicate ROM files
[2] Clean duplicate gamelist.xml entries
[3] Review regional/clone variants (gamelist only)
[4] Remove orphan gamelist.xml entries
[5] Restore missing metadata from backup/source gamelist
[6] Exit
```

## Typical RetroDECK paths

For MAME in RetroDECK, the gamelist path and ROM directory are normally different.

Example gamelist:

```text
/home/migz/Games/retrodeck/ES-DE/gamelists/mame/gamelist.xml
```

Example ROM directory:

```text
/home/migz/Games/retrodeck/roms/mame
```

When the script asks for both values, use the real ROM directory for the second prompt. This prevents bad paths like:

```text
/home/migz/Games/retrodeck/ES-DE/gamelists/mame/zaxxon.zip
```

and resolves `./zaxxon.zip` as:

```text
/home/migz/Games/retrodeck/roms/mame/zaxxon.zip
```

## Option 1: exact duplicate ROM files

This hashes files with SHA256 and finds byte-for-byte duplicates.

It can optionally read a `gamelist.xml` file. When you provide one, the script avoids moving files that are referenced by that gamelist so it does not create orphan metadata entries.

Quarantine folders look like:

```text
_rom_cleanup_duplicates_20260521_123456
```

## Option 2: duplicate gamelist entries

This finds repeated `<game>` entries that point to the same ROM path.

It normalizes simple path differences such as:

```xml
<path>foo.zip</path>
<path>./foo.zip</path>
```

Before removing a duplicate entry, it copies missing metadata from the removed entry into the kept entry. This helps prevent lost descriptions, images, ratings, release dates, and other scraped fields.

## Option 3: regional/clone variants

This finds entries with the same `<name>` but different `<path>` values.

For MAME/arcade-like systems, this is intentionally **gamelist-only**. It does not move ROM ZIPs, because regional/clone/bootleg entries may depend on parent sets, BIOS sets, device sets, or CHDs.

Modes:

- interactive review;
- auto keep best entry in every group;
- preview only.

The auto mode keeps an existing ROM path first, then the richest metadata entry. If the kept entry is missing metadata but a removed entry has it, the script copies those missing fields before removing the extra gamelist entries.

## Option 4: orphan gamelist entries

This finds entries where `<path>` points to a missing ROM file.

It asks for both:

```text
gamelist.xml path
ROM directory path
```

Then it resolves relative paths against the ROM directory and removes only the orphaned `<game>` entries after confirmation.

It does not remove media files. ES-DE/RetroDECK's own orphan cleanup utility can clean media later if needed.

## Option 5: restore missing metadata

Use this after metadata loss if you still have a backup or a `CLEANUP` copy from ES-DE/RetroDECK.

It asks for:

```text
current gamelist.xml path to repair
backup/source gamelist.xml path with good metadata
```

It copies missing metadata fields into the current gamelist. It matches by ROM path first, then by game name. Existing fields are not overwritten.

Useful backup locations include:

```text
/home/migz/Games/retrodeck/ES-DE/gamelists/mame/gamelist.xml.backup_YYYYMMDD_HHMMSS
/home/migz/Games/retrodeck/ES-DE/gamelists/CLEANUP/YYYY-MM-DD_HHMMSS/mame/gamelist.xml
```

## Recovery tips

Restore quarantined MAME ROMs before doing more cleanup:

```bash
ROM_DIR="/home/migz/Games/retrodeck/roms/mame"
find "$ROM_DIR" -maxdepth 1 -type d -name '_rom_cleanup_*' -print
find "$ROM_DIR" -maxdepth 2 -type f -path '*/_rom_cleanup_*/*' -exec cp -avn {} "$ROM_DIR"/ \;
```

Find the backup with the most metadata:

```bash
cd /home/migz/Games/retrodeck/ES-DE/gamelists/mame

for f in gamelist.xml gamelist.xml.backup_*; do
  [ -f "$f" ] || continue
  printf '%-55s games=%5s desc=%5s image=%5s rating=%5s date=%5s\n' \
    "$f" \
    "$(grep -c '<game>' "$f")" \
    "$(grep -c '<desc>' "$f")" \
    "$(grep -c '<image>' "$f")" \
    "$(grep -c '<rating>' "$f")" \
    "$(grep -c '<releasedate>' "$f")"
done
```

Then use option 5 to copy missing metadata back into the current file, or restore the best backup manually.

## Development

Run smoke tests:

```bash
make test
```

Run ShellCheck if installed:

```bash
make lint
```

Run everything:

```bash
make check
```

## Versioning

Current version: `0.2.0`.

## License

MIT. See [`LICENSE`](LICENSE).
