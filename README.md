# ROM Duplicate Finder

A safe, efficient bash script to find and remove duplicate ROM files from your retro gaming collections. Perfect for cleaning up MAME, NES, SNES, Genesis, or any other ROM archives.

## Features

✅ **Accurate Detection** - Uses SHA256 hashing to find exact duplicates (even if filenames differ)  
✅ **Safe by Default** - Shows you duplicates before deleting anything  
✅ **Backup Option** - Automatically backs up duplicates before removal  
✅ **Works Everywhere** - Compatible with Linux, macOS, and WSL  
✅ **Any ROM Format** - Handles .zip, .7z, .rom, .nes, .gba, etc.  
✅ **Progress Reporting** - Shows scanning progress and space to recover  

## Installation

```bash
git clone https://github.com/MiGzY/rom-duplicate-finder.git
cd rom-duplicate-finder
chmod +x find_rom_dupes.sh
```

## Usage

### Interactive Mode (Recommended)
```bash
./find_rom_dupes.sh
# Script will prompt for ROM directory path
```

### With Path Argument
```bash
./find_rom_dupes.sh ~/Games/roms/mame
./find_rom_dupes.sh /media/external/snes
```

### With Verbose Output
```bash
./find_rom_dupes.sh -v ~/Games/roms
```

### Help
```bash
./find_rom_dupes.sh --help
```

## Examples

### Example 1: Clean up MAME ROMs
```bash
./find_rom_dupes.sh ~/.var/app/net.retrodeck.retrodeck/roms/mame
```
Output:
```
Found 15 duplicate file(s)
Space to recover: 2.5G
```

### Example 2: Check SNES collection
```bash
./find_rom_dupes.sh ~/Games/snes
```

### Example 3: Interactive - no path needed
```bash
$ ./find_rom_dupes.sh
Enter path to ROM directory: ~/Games/roms
Scanning...
```

## How It Works

1. **Scans** the directory for all files
2. **Calculates** SHA256 hash for each file
3. **Identifies** files with matching hashes (exact duplicates)
4. **Reports** findings with file sizes
5. **Offers options**:
   - View removal commands (safe preview)
   - Create backup and delete
   - List duplicates only
   - Cancel

## What Counts as a Duplicate?

This script finds **exact duplicates** - files with identical content, regardless of filename.

✅ Detects these as duplicates:
- `pacman.zip` and `pacman_v2.zip` (same ROM, different names)
- `mario.nes` and `mario (1).nes` (accidentally downloaded twice)
- Different archives of the same ROM

❌ Does NOT detect these as duplicates:
- Different versions of a game (v1.0 vs v1.1)
- Different ROM dumps (GoodTools vs No-Intro versions)
- Game variants or regional releases

## Safety

The script is designed to be safe:

- **Non-destructive by default** - Shows you what would be deleted
- **Backup option** - Creates timestamped backup before deletion
- **Clear prompts** - Never deletes without explicit confirmation
- **Error handling** - Stops and preserves backup if removal fails

## Requirements

- **bash** 4.0+
- **Linux/macOS/WSL** (Windows Subsystem for Linux)
- Standard Unix tools: `find`, `sha256sum`, `stat`

### Optional
- `numfmt` - For human-readable file sizes (usually included)

## Troubleshooting

### "Permission denied" error
```bash
chmod +x find_rom_dupes.sh
```

### Script won't run
Verify bash version:
```bash
bash --version  # Should be 4.0 or higher
```

If you have bash 3.x, try:
```bash
bash find_rom_dupes.sh /path/to/roms
```

### Can't access directory
Make sure the path exists and you have read permissions:
```bash
ls -la ~/Games/roms/mame
```

## Performance

- Typical scanning speed: ~50-100 files per second
- For 1000 files: ~15-20 seconds
- Hash calculation is the bottleneck; your storage speed matters

## Tips

**Before running on large collections:**
```bash
# Count files first
find /path/to/roms -type f | wc -l

# Run with verbose mode to monitor progress
./find_rom_dupes.sh -v /path/to/roms
```

**Organize by system first:**
```bash
./find_rom_dupes.sh ~/Games/mame
./find_rom_dupes.sh ~/Games/snes
./find_rom_dupes.sh ~/Games/genesis
```

**Common backup locations:**
```
RetroDECK:  ~/.var/app/net.retrodeck.retrodeck/roms/[system]
Emulation Station:  ~/.emulationstation/roms/[system]
RetroArch:  ~/.config/RetroArch/downloads
General:    ~/Games/roms/[system]
```

## Contributing

Found a bug? Want to add features? Pull requests welcome!

Possible improvements:
- `--dry-run` flag for safety
- `--keep-newest` / `--keep-oldest` options
- Size filters (`--min-size`, `--max-size`)
- Specific file type filters
- JSON output for scripting
- Parallel hashing for speed

## License

MIT License - Free to use and modify

## Disclaimer

Use at your own risk. Always verify duplicates before deletion. While this script is designed to be safe, backups are always recommended for valuable collections.

---

**Questions?** Open an issue or check the examples above.
