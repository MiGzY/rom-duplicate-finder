# Usage Guide

## Start the menu

```bash
./rom_cleanup.sh
```

## Show help

```bash
./rom_cleanup.sh --help
```

## Recommended workflow

1. Back up the ROM system folder you are about to clean.
2. Run option 1 to find exact duplicate ROM files.
3. Move exact duplicates to quarantine and check that your emulator still launches the games you care about.
4. Run option 2 on the relevant `gamelist.xml` file to remove duplicate XML entries.
5. Run option 3 only when you want to manually choose between regional versions, revisions, hacks, prototypes, or other variants.

## Quarantine folders

The script creates timestamped quarantine folders rather than deleting ROM files.

Duplicate ROM quarantine folders look like:

```text
_rom_cleanup_duplicates_YYYYMMDD_HHMMSS
```

Variant quarantine folders look like:

```text
_rom_cleanup_variants_YYYYMMDD_HHMMSS
```

After verifying your library, you can manually delete the quarantine folders.

## `gamelist.xml` backups

Before editing a gamelist, the script creates a timestamped backup next to the original file:

```text
gamelist.xml.backup_YYYYMMDD_HHMMSS
```

To roll back manually:

```bash
cp gamelist.xml.backup_YYYYMMDD_HHMMSS gamelist.xml
```

## Notes on variants

The variant finder groups entries by normalized `<name>` text. That means games with the same visible name but different paths will be grouped together.

This is useful for choosing between files such as:

```text
Super Game (USA).zip
Super Game (Europe).zip
Super Game (Japan).zip
Super Game (Rev 1).zip
```

It will not automatically decide which region, revision, hack, or translation is best. You make that choice interactively.
