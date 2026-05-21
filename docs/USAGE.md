# Usage

Start the menu:

```bash
./rom_cleanup.sh
```

Show help:

```bash
./rom_cleanup.sh --help
```

## Recommended MAME/RetroDECK flow

1. Restore any accidentally quarantined MAME ROMs.
2. Run option 5 if metadata is missing and you have a good backup.
3. Run option 4 to remove orphan gamelist entries.
4. Run option 2 to remove duplicate entries that point to the same path.
5. Run option 3 only if you want to hide regional/clone variants from the gamelist.
6. Run option 1 for exact byte-for-byte duplicate ROM files, and provide the gamelist path when prompted.

## Path prompts

When asked for `gamelist.xml`, enter a file path like:

```text
/home/migz/Games/retrodeck/ES-DE/gamelists/mame/gamelist.xml
```

When asked for the ROM directory, enter the real ROM folder like:

```text
/home/migz/Games/retrodeck/roms/mame
```
