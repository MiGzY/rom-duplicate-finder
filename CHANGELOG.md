# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-05-19

### Added
- Initial release of ROM Duplicate Finder with two complementary scripts:

#### find_rom_dupes.sh
- SHA256 hash-based duplicate detection for ROM files
- Interactive mode with path prompting
- Command-line argument support (path and flags)
- Backup functionality before deletion
- Human-readable file size formatting
- Color-coded output for easy reading
- Verbose mode (`-v` flag) for detailed progress
- Help menu (`-h` flag)
- Comprehensive error handling
- Progress indicators during scanning

#### remove_gamelist_dupes.sh
- XML-safe duplicate game entry detection
- Identifies duplicates by ROM path in gamelist.xml
- Preserves entry with most metadata
- Auto-discovery of gamelist.xml files
- Three removal modes:
  1. Preview mode (safe preview)
  2. Backup and modify original
  3. Create cleaned copy (new file)
- Verbose mode for detailed output
- Help menu with common location examples

### Features
- Works with any ROM format (.zip, .7z, .rom, etc.)
- Cross-platform: Linux, macOS, WSL
- Finds exact duplicates regardless of filename
- Shows original vs duplicate files
- Calculates total space to recover
- Creates timestamped backups
- Compatible with RetroDECK, EmulationStation, RetroArch

### Documentation
- Comprehensive README with workflow examples
- Complete gamelist usage guide
- MIT License
- .gitignore for common files

## Future Plans

### Planned for v1.1
- `--dry-run` flag for safety
- `--keep-newest` and `--keep-oldest` options for ROM script
- Parallel hashing for faster ROM processing
- JSON output format for scripting
- Gamelist script: Option to merge metadata from duplicates
- Gamelist script: Validate XML integrity

### Planned for v1.2
- Size filters (`--min-size`, `--max-size`) for ROM script
- File type filters (`--include`, `--exclude`)
- Recursive directory scanning option
- Configuration file support
- Gamelist script: Support for multiple gamelist formats
- Gamelist script: Custom deduplication rules

### Planned for v2.0
- Web interface for non-technical users
- Database of known ROM hashes
- Integration with popular emulator managers
- Batch processing for multiple systems
- Automated cleanup workflows
- Statistics and reporting dashboard
