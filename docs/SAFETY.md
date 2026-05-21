# Safety notes

## MAME and arcade ROMs

Do not treat MAME regional versions, clones, bootlegs, BIOS sets, device sets, or CHDs as disposable duplicates.

A visible duplicate in ES-DE can still rely on a parent or shared dependency. This is why option 3 is gamelist-only and does not move ROM ZIPs.

## Backups

Every gamelist write creates a timestamped backup next to the file being edited:

```text
gamelist.xml.backup_YYYYMMDD_HHMMSS
```

Keep these until you have launched ES-DE/RetroDECK and verified that metadata and games still work.

## Quarantine folders

ROM files moved by exact duplicate cleanup go into folders like:

```text
_rom_cleanup_duplicates_YYYYMMDD_HHMMSS
```

They are not deleted. Restore with `cp -avn` if needed.

## ES-DE/RetroDECK

Close ES-DE/RetroDECK before editing gamelist files. Do not run cleanup while the frontend is open or writing metadata.
