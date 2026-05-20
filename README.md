# ROM Duplicate Finder

A pair of complementary bash scripts to clean up your retro gaming collections:

1. **find_rom_dupes.sh** - Finds and removes duplicate ROM files
2. **remove_gamelist_dupes.sh** - Removes duplicate game entries from gamelist.xml

Perfect for cleaning up MAME, NES, SNES, Genesis, or any other ROM archives.

## Features

✅ **Accurate Detection** - Uses SHA256 hashing to find exact duplicates (even if filenames differ)  
✅ **Safe by Default** - Shows you duplicates before deleting anything  
✅ **Backup Option** - Automatically backs up duplicates before removal  
✅ **Works Everywhere** - Compatible with Linux, macOS, and WSL  
✅ **Any ROM Format** - Handles .zip, .7z, .rom, .nes, .gba, etc.  
✅ **Progress Reporting** - Shows scanning progress and space to recover  

## Installation

```bash
git clone https://github.com/yourusername/rom-duplicate-finder.git
cd rom-duplicate-finder
chmod +x find_rom_dupes.sh remove_gamelist_dupes.sh
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

## Gamelist Duplicate Remover

After cleaning duplicate ROM files, you'll likely have duplicate entries in your `gamelist.xml` metadata file. Use this script to clean those up.

### Gamelist Usage

#### Interactive Mode (Recommended)
```bash
./remove_gamelist_dupes.sh
# Will search common locations and let you choose
```

#### With Path Argument
```bash
./remove_gamelist_dupes.sh ~/.var/app/net.retrodeck.retrodeck/roms/mame/gamelist.xml
./remove_gamelist_dupes.sh ~/.emulationstation/gamelists/snes/gamelist.xml
```

#### Auto-Find Mode
```bash
./remove_gamelist_dupes.sh --find
# Searches RetroDECK, EmulationStation, RetroArch locations
```

#### With Verbose Output
```bash
./remove_gamelist_dupes.sh -v ~/path/to/gamelist.xml
```

#### Help
```bash
./remove_gamelist_dupes.sh --help
```

### Gamelist Examples

#### Example 1: Clean MAME gamelist
```bash
./remove_gamelist_dupes.sh ~/.var/app/net.retrodeck.retrodeck/roms/mame/gamelist.xml
```
Output:
```
Found 12 duplicate game entries
Total games: 150
Unique games: 138
Duplicates to remove: 12
```

#### Example 2: Find and clean all gamelists
```bash
for gamelist in ~/.emulationstation/gamelists/*/gamelist.xml; do
    ./remove_gamelist_dupes.sh "$gamelist"
done
```

#### Example 3: Auto-discover and clean
```bash
./remove_gamelist_dupes.sh --find
# Lists available gamelist files and lets you choose
```

### Workflow: Complete Cleanup

Here's the recommended order when cleaning up your ROM collection:

```bash
# 1. Find and remove duplicate ROM files
./find_rom_dupes.sh ~/Games/roms/mame
# Choose option 2 to backup and delete

# 2. Remove duplicate gamelist entries for the same system
./remove_gamelist_dupes.sh ~/.emulationstation/gamelists/mame/gamelist.xml
# Choose option 2 to backup and clean

# Repeat for other systems:
./find_rom_dupes.sh ~/Games/roms/snes
./remove_gamelist_dupes.sh ~/.emulationstation/gamelists/snes/gamelist.xml
```

### What Gamelist Duplicates Look Like

Before cleaning, a gamelist.xml might have:

```xml
<gameList>
  <game>
    <path>./pacman.zip</path>
    <name>Pac-Man</name>
    <desc>Classic arcade game</desc>
  </game>
  <!-- This is a DUPLICATE entry with same path -->
  <game>
    <path>./pacman.zip</path>
    <name>Pac Man</name>
  </game>
</gameList>
```

After cleaning:

```xml
<gameList>
  <game>
    <path>./pacman.zip</path>
    <name>Pac-Man</name>
    <desc>Classic arcade game</desc>
  </game>
  <!-- Duplicate removed! -->
</gameList>
```

The script **keeps the entry with the most metadata** (more fields = more complete info) and removes the duplicate with less information.

## How It Works

### find_rom_dupes.sh

1. **Scans** the directory for all files
2. **Calculates** SHA256 hash for each file
3. **Identifies** files with matching hashes (exact duplicates)
4. **Reports** findings with file sizes
5. **Offers options**:
   - View removal commands (safe preview)
   - Create backup and delete
   - List duplicates only
   - Cancel

### remove_gamelist_dupes.sh

1. **Parses** gamelist.xml XML structure
2. **Extracts** ROM path from each game entry
3. **Identifies** duplicate entries (same path)
4. **Compares** metadata completeness (field count)
5. **Keeps** entry with most metadata (better data)
6. **Removes** duplicate with less information
7. **Offers options**:
   - Preview entries to be removed
   - Backup and clean original file
   - Create cleaned copy (new file)
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

MIT License

Copyright (c) 2026 [Miguel Manzano/MiGzY]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


## Disclaimer

Use at your own risk. Always verify duplicates before deletion. While this script is designed to be safe, backups are always recommended for valuable collections.

---

**Questions?** Open an issue or check the examples above.
