# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-05-19

### Added
- Initial release of ROM Duplicate Finder
- SHA256 hash-based duplicate detection
- Interactive mode with path prompting
- Command-line argument support (path and flags)
- Backup functionality before deletion
- Human-readable file size formatting
- Color-coded output for easy reading
- Verbose mode (`-v` flag) for detailed progress
- Help menu (`-h` flag)
- Comprehensive error handling
- Progress indicators during scanning
- Four operation modes:
  1. Preview removal commands (safe)
  2. Backup and delete (automatic)
  3. List duplicates only
  4. Cancel

### Features
- Works with any ROM format (.zip, .7z, .rom, etc.)
- Cross-platform: Linux, macOS, WSL
- Finds exact duplicates regardless of filename
- Shows original vs duplicate files
- Calculates total space to recover
- Creates timestamped backups

### Documentation
- Comprehensive README with examples
- MIT License
- .gitignore for common files

## Future Plans

### Planned for v1.1
- `--dry-run` flag for safety
- `--keep-newest` and `--keep-oldest` options
- Parallel hashing for faster processing
- JSON output format for scripting

### Planned for v1.2
- Size filters (`--min-size`, `--max-size`)
- File type filters (`--include`, `--exclude`)
- Recursive directory scanning option
- Configuration file support

### Planned for v2.0
- Web interface for non-technical users
- Database of known ROM hashes
- Integration with popular emulator managers
- Batch processing for multiple systems
