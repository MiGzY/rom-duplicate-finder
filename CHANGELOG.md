# Changelog

## 0.2.0

- Added separate `gamelist.xml` and ROM directory prompts for gamelist operations.
- Added MAME/arcade-safe variant cleanup that edits `gamelist.xml` only.
- Removed ROM moving from regional/clone variant cleanup.
- Added metadata merging before duplicate or variant gamelist entries are removed.
- Added orphan gamelist entry cleanup.
- Added metadata restore from backup/source gamelist.
- Made exact duplicate ROM cleanup optionally gamelist-aware so referenced files are not moved.
- Added smoke tests for metadata preservation, orphan cleanup, variant cleanup, and reference-safe duplicate cleanup.

## 0.1.0

- Initial ROM Cleanup Suite.
