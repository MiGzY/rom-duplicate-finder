# Safety Notes

ROM Cleanup Suite tries to avoid destructive behavior.

## What it does not do by default

- It does not permanently delete duplicate ROM files.
- It does not edit `gamelist.xml` without creating a backup.
- It does not remove game variants without asking which item to keep.

## Before large cleanups

For large libraries, make a separate backup first:

```bash
cp -a /path/to/roms /path/to/roms.backup
```

Or use your preferred snapshot / backup tool.

## After cleanup

Before deleting any quarantine folder:

1. launch a few games from the cleaned system;
2. refresh or restart your frontend;
3. confirm artwork and metadata still look right;
4. keep the gamelist backup until you are confident the result is good.
