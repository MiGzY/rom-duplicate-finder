#!/usr/bin/env bash

#############################################################################
# ROM Cleanup Suite
#
# Miguel Manzano / MiGzY
# https://github.com/MiGzY/rom-cleanup-suite/
#
# Safer all-in-one ROM and ES-DE gamelist cleanup tool.
#
# Key safety rules:
#   - ROM files are never permanently deleted.
#   - MAME/arcade variants are treated as gamelist entries, not disposable ROMs.
#   - gamelist.xml is backed up before every write.
#   - Variant cleanup preserves metadata by merging missing fields into the kept
#     entry before removing the unwanted gamelist entries.
#   - Relative gamelist paths are resolved against the ROM directory you provide,
#     not against the gamelist.xml directory.
#############################################################################

set -Eeuo pipefail

VERSION="0.2.0"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

show_help() {
    cat <<'HELP'
ROM Cleanup Suite

USAGE:
    ./rom_cleanup.sh             Open the interactive menu
    ./rom_cleanup.sh --help      Show this help
    ./rom_cleanup.sh --version   Show version

OPERATIONS:
    1. Find exact duplicate ROM files
       - Hashes ROM files with SHA256.
       - Optionally uses gamelist.xml to avoid moving referenced files.
       - Moves safe duplicate copies to a quarantine folder.

    2. Clean duplicate gamelist.xml entries
       - Finds repeated <game> entries with the same ROM path.
       - Keeps the richest metadata entry.
       - Merges missing metadata before removing duplicates.

    3. Review regional/clone variants
       - Finds repeated <name> values with different ROM paths.
       - Asks for both gamelist.xml and the real ROM directory.
       - Removes only gamelist entries; it does not move ROM files.
       - Copies missing metadata from removed entries into the kept entry.

    4. Remove orphan gamelist.xml entries
       - Finds gamelist entries whose ROM file is missing.
       - Resolves relative paths against the ROM directory you provide.
       - Removes only gamelist entries after confirmation.

    5. Restore missing metadata from a backup/source gamelist
       - Copies missing fields into the current gamelist.
       - Matches by ROM path first, then by game name.
       - Does not remove entries or ROM files.

NOTES:
    - Close ES-DE/RetroDECK before editing gamelist.xml.
    - For MAME/arcade, do not remove regional/clone ZIPs blindly. Parent,
      clone, BIOS, device, and CHD relationships can make apparently duplicate
      files depend on each other.
HELP
}

print_header() {
    printf '\n%s%s%s\n' "$BLUE" "$1" "$NC"
    printf '%s%s%s\n' "$YELLOW" '==========================================' "$NC"
}

print_menu() {
    printf '\n%sROM Cleanup Suite%s\n\n' "$CYAN" "$NC"
    printf 'Choose an operation:\n\n'
    printf '  %s[1]%s Find and move exact duplicate ROM files\n' "$YELLOW" "$NC"
    printf '  %s[2]%s Clean duplicate gamelist.xml entries\n' "$YELLOW" "$NC"
    printf '  %s[3]%s Review regional/clone variants (gamelist only)\n' "$YELLOW" "$NC"
    printf '  %s[4]%s Remove orphan gamelist.xml entries\n' "$YELLOW" "$NC"
    printf '  %s[5]%s Restore missing metadata from backup/source gamelist\n' "$YELLOW" "$NC"
    printf '  %s[6]%s Exit\n\n' "$YELLOW" "$NC"
}

pause() {
    read -r -p 'Press enter to continue...' _ || true
}

is_yes() {
    [[ "${1:-}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

expand_path() {
    local input=${1:-}
    input=${input%$'\r'}
    input=${input#\"}
    input=${input%\"}
    input=${input#\'}
    input=${input%\'}

    case "$input" in
        '~') printf '%s\n' "$HOME" ;;
        '~/'*) printf '%s/%s\n' "$HOME" "${input#~/}" ;;
        *) printf '%s\n' "$input" ;;
    esac
}

clear_screen() {
    if [[ -t 1 ]]; then
        clear || true
    fi
}

require_python3() {
    if ! command -v python3 >/dev/null 2>&1; then
        printf '%sError:%s python3 is required for gamelist operations.\n' "$RED" "$NC"
        pause
        return 1
    fi
}

run_python_file() {
    local py_script=$1
    shift
    local status=0
    python3 "$py_script" "$@" || status=$?
    rm -f -- "$py_script"
    return "$status"
}

# -----------------------------------------------------------------------------
# Operation 1: exact duplicate ROM files
# -----------------------------------------------------------------------------
find_rom_duplicates() {
    print_header 'Find Exact Duplicate ROM Files'
    require_python3 || return

    local rom_dir recursive gamelist
    read -r -p 'Enter ROM directory path: ' rom_dir || return
    rom_dir=$(expand_path "$rom_dir")

    if [[ ! -d "$rom_dir" ]]; then
        printf '%sError:%s Directory not found: %s\n' "$RED" "$NC" "$rom_dir"
        pause
        return
    fi

    read -r -p 'Search recursively? (y/N): ' recursive || recursive=''
    read -r -p 'Optional gamelist.xml path for reference protection [Enter to skip]: ' gamelist || gamelist=''
    gamelist=$(expand_path "$gamelist")

    if [[ -n "$gamelist" && ! -f "$gamelist" ]]; then
        printf '%sError:%s gamelist.xml not found: %s\n' "$RED" "$NC" "$gamelist"
        pause
        return
    fi

    local py_script
    py_script=$(mktemp)
    cat > "$py_script" <<'PY'
from __future__ import annotations

import datetime as dt
import hashlib
import os
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

rom_dir = Path(sys.argv[1]).expanduser().resolve(strict=False)
recursive = sys.argv[2] == "1"
gamelist_arg = sys.argv[3] if len(sys.argv) > 3 else ""
gamelist_path = Path(gamelist_arg).expanduser() if gamelist_arg else None

QUARANTINE_PREFIX = "_rom_cleanup_"


def text(game: ET.Element, tag: str) -> str:
    node = game.find(tag)
    if node is None or node.text is None:
        return ""
    return node.text.strip()


def strip_file_uri(value: str) -> str:
    value = value.strip()
    if value.startswith("file://"):
        return value[7:]
    return value


def resolve_rom_path(path_text: str) -> Path:
    raw = strip_file_uri(path_text)
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate.resolve(strict=False)
    while raw.startswith("./"):
        raw = raw[2:]
    return (rom_dir / raw).resolve(strict=False)


def collect_referenced_paths() -> set[str]:
    if not gamelist_path:
        return set()
    try:
        tree = ET.parse(gamelist_path)
    except Exception as exc:
        print(f"Error: could not parse gamelist.xml: {exc}")
        raise SystemExit(1)
    refs: set[str] = set()
    for game in tree.getroot().findall("game"):
        rom_path = text(game, "path")
        if rom_path:
            refs.add(str(resolve_rom_path(rom_path)))
    return refs


def should_skip(path: Path) -> bool:
    try:
        rel = path.relative_to(rom_dir)
    except ValueError:
        return False
    return any(part.startswith(QUARANTINE_PREFIX) for part in rel.parts)


def iter_files() -> list[Path]:
    if recursive:
        candidates = [p for p in rom_dir.rglob("*") if p.is_file()]
    else:
        candidates = [p for p in rom_dir.iterdir() if p.is_file()]
    return sorted(p for p in candidates if not should_skip(p))


def file_hash(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(rom_dir))
    except ValueError:
        return str(path)


def unique_destination(src: Path, quarantine: Path) -> Path:
    try:
        relative = src.resolve(strict=False).relative_to(rom_dir)
    except ValueError:
        relative = Path(src.name)
    dest = quarantine / relative
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists():
        return dest
    counter = 1
    while True:
        candidate = dest.with_name(f"{dest.stem}_{counter}{dest.suffix}")
        if not candidate.exists():
            return candidate
        counter += 1


files = iter_files()
if not files:
    print("No files found.")
    raise SystemExit(0)

print(f"Found {len(files)} file(s). Hashing...")
by_hash: dict[str, list[Path]] = {}
for index, path in enumerate(files, start=1):
    if index == len(files) or index % 100 == 0:
        pct = index * 100 // len(files)
        print(f"  Hashed {index}/{len(files)} ({pct}%)", end="\r")
    try:
        digest = file_hash(path)
    except OSError as exc:
        print(f"\nWarning: could not hash {path}: {exc}")
        continue
    by_hash.setdefault(digest, []).append(path)
print()

referenced_paths = collect_referenced_paths()
if referenced_paths:
    print(f"Loaded {len(referenced_paths)} referenced path(s) from gamelist.xml.")
    print("Referenced duplicate files will be skipped to avoid creating orphan metadata.")

planned_moves: list[tuple[Path, Path]] = []
skipped_referenced = 0
duplicate_groups = 0

for digest, paths in sorted(by_hash.items(), key=lambda item: item[0]):
    if len(paths) < 2:
        continue
    duplicate_groups += 1
    paths = sorted(paths)
    referenced = [p for p in paths if str(p.resolve(strict=False)) in referenced_paths]
    if referenced:
        keeper = referenced[0]
        movable = [p for p in paths if p not in referenced]
        skipped_referenced += max(0, len(referenced) - 1)
    else:
        keeper = paths[0]
        movable = paths[1:]

    print(f"\nDuplicate group {duplicate_groups}: sha256 {digest[:12]}...")
    print(f"  Keep: {rel(keeper)}")
    for path in movable:
        size_mb = path.stat().st_size / 1024 / 1024
        print(f"  Move: {rel(path)} ({size_mb:.1f} MB)")
        planned_moves.append((path, keeper))
    for path in referenced:
        if path != keeper:
            print(f"  Skip referenced: {rel(path)}")

if duplicate_groups == 0:
    print("No exact duplicate files found.")
    raise SystemExit(0)

if not planned_moves:
    print("\nNo safely movable duplicate files found.")
    if skipped_referenced:
        print(f"Skipped {skipped_referenced} referenced duplicate file(s). Clean the gamelist first if you want to hide those entries.")
    raise SystemExit(0)

print(f"\nPlanned move count: {len(planned_moves)} file(s).")
answer = input("Move these duplicate copies to quarantine? (y/N): ").strip().lower()
if answer not in {"y", "yes"}:
    print("No files moved.")
    raise SystemExit(0)

quarantine = rom_dir / ("_rom_cleanup_duplicates_" + dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
quarantine.mkdir(parents=True, exist_ok=True)

moved = 0
for src, keeper in planned_moves:
    if not src.exists():
        print(f"Skipped missing file: {src}")
        continue
    dest = unique_destination(src, quarantine)
    shutil.move(str(src), str(dest))
    moved += 1
    print(f"Moved: {rel(src)} -> {dest}")

print(f"\nMoved {moved} file(s) to: {quarantine}")
PY

    local recursive_flag=0
    if is_yes "$recursive"; then
        recursive_flag=1
    fi

    run_python_file "$py_script" "$rom_dir" "$recursive_flag" "$gamelist"
    pause
}

# -----------------------------------------------------------------------------
# Operation 2: duplicate gamelist entries by path
# -----------------------------------------------------------------------------
clean_gamelist_duplicates() {
    print_header 'Clean Duplicate Gamelist Entries'
    require_python3 || return

    local gamelist
    read -r -p 'Enter gamelist.xml path: ' gamelist || return
    gamelist=$(expand_path "$gamelist")

    if [[ ! -f "$gamelist" ]]; then
        printf '%sError:%s File not found: %s\n' "$RED" "$NC" "$gamelist"
        pause
        return
    fi

    local py_script
    py_script=$(mktemp)
    cat > "$py_script" <<'PY'
from __future__ import annotations

import copy
import datetime as dt
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

path = Path(sys.argv[1]).expanduser()

try:
    tree = ET.parse(path)
except Exception as exc:
    print(f"Error: could not parse XML: {exc}")
    raise SystemExit(1)

root = tree.getroot()
games = list(root.findall("game"))

if not games:
    print("No <game> entries found.")
    raise SystemExit(0)


def text(game: ET.Element, tag: str) -> str:
    node = game.find(tag)
    if node is None or node.text is None:
        return ""
    return node.text.strip()


def normalize_path_key(value: str) -> str:
    raw = value.strip().replace("\\", "/")
    if raw.startswith("file://"):
        raw = raw[7:]
    while raw.startswith("./"):
        raw = raw[2:]
    return raw.strip()


def node_has_value(node: ET.Element | None) -> bool:
    if node is None:
        return False
    if node.text and node.text.strip():
        return True
    if node.attrib:
        return True
    if list(node):
        return True
    return False


def metadata_score(game: ET.Element) -> int:
    score = 0
    for child in list(game):
        if child.tag == "path":
            score += 1 if child.text and child.text.strip() else 0
            continue
        if child.text and child.text.strip():
            score += 3
        if child.attrib:
            score += len(child.attrib)
        score += len(list(child))
    return score


def preferred_keep_key(game: ET.Element) -> tuple[int, int, int]:
    path_text = text(game, "path")
    has_esde_relative = 1 if path_text.startswith("./") else 0
    return (metadata_score(game), has_esde_relative, -len(path_text))


def merge_missing_metadata(keep: ET.Element, source: ET.Element) -> int:
    copied = 0
    for child in list(source):
        if child.tag == "path":
            continue
        current = keep.find(child.tag)
        if not node_has_value(current):
            if current is not None:
                keep.remove(current)
            keep.append(copy.deepcopy(child))
            copied += 1
    return copied


by_path: dict[str, list[ET.Element]] = {}
for game in games:
    rom_path = text(game, "path")
    if rom_path:
        by_path.setdefault(normalize_path_key(rom_path), []).append(game)

groups = [(rom_path, entries) for rom_path, entries in by_path.items() if len(entries) > 1]
if not groups:
    print("No duplicate gamelist entries found.")
    raise SystemExit(0)

duplicate_total = sum(len(entries) - 1 for _, entries in groups)
print(f"Found {duplicate_total} duplicate gamelist entr{'y' if duplicate_total == 1 else 'ies'}.\n")

planned_remove: list[ET.Element] = []
merge_count = 0
for rom_path, entries in sorted(groups, key=lambda item: item[0].casefold()):
    keep = max(entries, key=preferred_keep_key)
    print(f"Path: {rom_path}")
    print(f"  Keep:   {text(keep, 'name') or '(unnamed)'}  [metadata score {metadata_score(keep)}]")
    for entry in entries:
        if entry is keep:
            continue
        merge_count += merge_missing_metadata(keep, entry)
        planned_remove.append(entry)
        print(f"  Remove: {text(entry, 'name') or '(unnamed)'}  [metadata score {metadata_score(entry)}]")
    print()

if merge_count:
    print(f"Will copy {merge_count} missing metadata field(s) into kept entries before removal.")

answer = input("Remove these duplicate entries from gamelist.xml? (y/N): ").strip().lower()
if answer not in {"y", "yes"}:
    print("No changes made.")
    raise SystemExit(0)

backup = path.with_name(path.name + ".backup_" + dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copy2(path, backup)
for entry in planned_remove:
    root.remove(entry)

try:
    ET.indent(tree, space="  ")
except AttributeError:
    pass

tree.write(path, encoding="utf-8", xml_declaration=True)
print(f"Backup created: {backup}")
print(f"Removed {len(planned_remove)} duplicate entr{'y' if len(planned_remove) == 1 else 'ies'}.")
if merge_count:
    print(f"Copied {merge_count} missing metadata field(s) into kept entries.")
PY

    run_python_file "$py_script" "$gamelist"
    pause
}

# -----------------------------------------------------------------------------
# Operation 3: same game name, different ROM paths, gamelist-only
# -----------------------------------------------------------------------------
review_variants_gamelist_only() {
    print_header 'Review Regional/Clone Variants'
    require_python3 || return

    local gamelist rom_dir
    read -r -p 'Enter gamelist.xml path: ' gamelist || return
    gamelist=$(expand_path "$gamelist")

    if [[ ! -f "$gamelist" ]]; then
        printf '%sError:%s File not found: %s\n' "$RED" "$NC" "$gamelist"
        pause
        return
    fi

    read -r -p 'Enter ROM directory path for this gamelist: ' rom_dir || return
    rom_dir=$(expand_path "$rom_dir")

    if [[ ! -d "$rom_dir" ]]; then
        printf '%sError:%s ROM directory not found: %s\n' "$RED" "$NC" "$rom_dir"
        pause
        return
    fi

    local py_script
    py_script=$(mktemp)
    cat > "$py_script" <<'PY'
from __future__ import annotations

import copy
import datetime as dt
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


gamelist_path = Path(sys.argv[1]).expanduser()
rom_dir = Path(sys.argv[2]).expanduser().resolve(strict=False)

try:
    tree = ET.parse(gamelist_path)
except Exception as exc:
    print(f"Error: could not parse XML: {exc}")
    raise SystemExit(1)

root = tree.getroot()
games = list(root.findall("game"))

if not games:
    print("No <game> entries found.")
    raise SystemExit(0)


def text(game: ET.Element, tag: str) -> str:
    node = game.find(tag)
    if node is None or node.text is None:
        return ""
    return node.text.strip()


def normalize_name(value: str) -> str:
    return " ".join(value.split()).casefold()


def normalize_path_key(value: str) -> str:
    raw = value.strip().replace("\\", "/")
    if raw.startswith("file://"):
        raw = raw[7:]
    while raw.startswith("./"):
        raw = raw[2:]
    return raw.strip()


def resolve_rom_path(value: str) -> Path:
    raw = value.strip()
    if raw.startswith("file://"):
        raw = raw[7:]
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate.resolve(strict=False)
    while raw.startswith("./"):
        raw = raw[2:]
    primary = (rom_dir / raw).resolve(strict=False)
    if primary.exists():
        return primary
    fallback = (rom_dir / Path(raw).name).resolve(strict=False)
    if fallback.exists():
        return fallback
    return primary


def node_has_value(node: ET.Element | None) -> bool:
    if node is None:
        return False
    if node.text and node.text.strip():
        return True
    if node.attrib:
        return True
    if list(node):
        return True
    return False


def metadata_score(game: ET.Element) -> int:
    score = 0
    for child in list(game):
        if child.tag == "path":
            score += 1 if child.text and child.text.strip() else 0
            continue
        if child.text and child.text.strip():
            score += 3
        if child.attrib:
            score += len(child.attrib)
        score += len(list(child))
    return score


def merge_missing_metadata(keep: ET.Element, source: ET.Element) -> int:
    copied = 0
    for child in list(source):
        if child.tag == "path":
            continue
        current = keep.find(child.tag)
        if not node_has_value(current):
            if current is not None:
                keep.remove(current)
            keep.append(copy.deepcopy(child))
            copied += 1
    return copied


def exists(game: ET.Element) -> bool:
    rom_path = text(game, "path")
    return bool(rom_path) and resolve_rom_path(rom_path).is_file()


def default_keep(entries: list[ET.Element]) -> ET.Element:
    # Prefer an existing ROM over a missing one, then the entry with the most
    # metadata. This recovers common cases where the scraped metadata was on an
    # orphaned regional entry while the working file is a different shortname.
    return max(entries, key=lambda game: (1 if exists(game) else 0, metadata_score(game), text(game, "path").startswith("./")))


system_hint = f"{gamelist_path.parent.name} {rom_dir.name}".casefold()
if any(token in system_hint for token in ("mame", "arcade", "fbneo", "fba", "neogeo")):
    print("Arcade/MAME-like system detected.")
    print("This mode will NOT move or delete ROM ZIPs; it only edits gamelist.xml.\n")

by_name: dict[str, list[ET.Element]] = {}
for game in games:
    name = text(game, "name")
    rom_path = text(game, "path")
    if name and rom_path:
        by_name.setdefault(normalize_name(name), []).append(game)

groups: list[tuple[str, list[ET.Element]]] = []
for name_key, entries in by_name.items():
    unique_paths = {normalize_path_key(text(entry, "path")) for entry in entries}
    if len(unique_paths) > 1:
        display_name = text(entries[0], "name") or name_key
        groups.append((display_name, entries))

groups.sort(key=lambda item: item[0].casefold())

if not groups:
    print("No same-name games with multiple ROM paths found.")
    raise SystemExit(0)

print(f"Using ROM directory: {rom_dir}")
print(f"Found {len(groups)} game name(s) with multiple ROM paths.\n")
print("Modes:")
print("  1) Interactive review")
print("  2) Auto keep best entry in every group (existing ROM first, then richest metadata)")
print("  3) Preview only")
print("  4) Cancel")
mode = input("Choose [1-4]: ").strip() or "4"

if mode == "4":
    print("No changes made.")
    raise SystemExit(0)

if mode not in {"1", "2", "3"}:
    print("Invalid choice. No changes made.")
    raise SystemExit(0)

planned: list[tuple[ET.Element, list[ET.Element], str]] = []

def print_group(index: int, total: int, display_name: str, entries: list[ET.Element]) -> None:
    suggested = default_keep(entries)
    print(f"[{index}/{total}] {display_name}")
    for number, entry in enumerate(entries, start=1):
        path_value = text(entry, "path") or "(no path)"
        status = "exists" if exists(entry) else "missing"
        marker = " default" if entry is suggested else ""
        score = metadata_score(entry)
        meta_bits = []
        if text(entry, "desc"):
            meta_bits.append("desc")
        if text(entry, "image"):
            meta_bits.append("image")
        if text(entry, "rating"):
            meta_bits.append("rating")
        meta_note = f" metadata={','.join(meta_bits)}" if meta_bits else ""
        print(f"  {number}) {path_value} [{status}, score {score}{marker}{meta_note}]")


def add_plan(keep: ET.Element, entries: list[ET.Element], display_name: str) -> None:
    remove_entries = [entry for entry in entries if entry is not keep]
    if remove_entries:
        planned.append((keep, remove_entries, display_name))

if mode == "3":
    for index, (display_name, entries) in enumerate(groups[:50], start=1):
        print_group(index, len(groups), display_name, entries)
        print()
    if len(groups) > 50:
        print(f"... {len(groups) - 50} more group(s) not shown.")
    print("Preview only. No changes made.")
    raise SystemExit(0)

if mode == "2":
    for display_name, entries in groups:
        add_plan(default_keep(entries), entries, display_name)
else:
    auto_remaining = False
    for index, (display_name, entries) in enumerate(groups, start=1):
        if auto_remaining:
            add_plan(default_keep(entries), entries, display_name)
            continue
        print_group(index, len(groups), display_name, entries)
        choice = input("Keep which one? [Enter skip, d default, a auto remaining, q quit]: ").strip().lower()
        print()
        if not choice:
            continue
        if choice in {"q", "quit", "exit"}:
            break
        if choice == "a":
            add_plan(default_keep(entries), entries, display_name)
            auto_remaining = True
            continue
        if choice == "d":
            add_plan(default_keep(entries), entries, display_name)
            continue
        if not choice.isdigit():
            print("Not a number; skipped.\n")
            continue
        keep_index = int(choice)
        if keep_index < 1 or keep_index > len(entries):
            print("Out of range; skipped.\n")
            continue
        add_plan(entries[keep_index - 1], entries, display_name)

if not planned:
    print("No variant entries selected for removal.")
    raise SystemExit(0)

remove_count = sum(len(remove_entries) for _, remove_entries, _ in planned)
print(f"Selected {remove_count} gamelist entr{'y' if remove_count == 1 else 'ies'} to remove.")
for keep, remove_entries, display_name in planned[:30]:
    print(f"\n{display_name}")
    print(f"  Keep: {text(keep, 'path')} [score {metadata_score(keep)}]")
    for entry in remove_entries:
        print(f"  Remove: {text(entry, 'path')} [score {metadata_score(entry)}]")
if len(planned) > 30:
    print(f"\n... {len(planned) - 30} more group(s) selected.")

print("\nROM files will be left in place. This avoids breaking MAME parent/clone/dependency sets.")
answer = input("Update gamelist.xml now? (y/N): ").strip().lower()
if answer not in {"y", "yes"}:
    print("No changes made.")
    raise SystemExit(0)

backup = gamelist_path.with_name(gamelist_path.name + ".backup_" + dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copy2(gamelist_path, backup)

merge_count = 0
removed = 0
for keep, remove_entries, _ in planned:
    for entry in remove_entries:
        merge_count += merge_missing_metadata(keep, entry)
        root.remove(entry)
        removed += 1

try:
    ET.indent(tree, space="  ")
except AttributeError:
    pass

tree.write(gamelist_path, encoding="utf-8", xml_declaration=True)
print(f"Backup created: {backup}")
print(f"Removed {removed} gamelist entr{'y' if removed == 1 else 'ies'}.")
print(f"Copied {merge_count} missing metadata field(s) into kept entries.")
print("ROM files were not moved.")
PY

    run_python_file "$py_script" "$gamelist" "$rom_dir"
    pause
}

# -----------------------------------------------------------------------------
# Operation 4: orphan gamelist entries
# -----------------------------------------------------------------------------
clean_orphan_gamelist_entries() {
    print_header 'Remove Orphan Gamelist Entries'
    require_python3 || return

    local gamelist rom_dir
    read -r -p 'Enter gamelist.xml path: ' gamelist || return
    gamelist=$(expand_path "$gamelist")

    if [[ ! -f "$gamelist" ]]; then
        printf '%sError:%s File not found: %s\n' "$RED" "$NC" "$gamelist"
        pause
        return
    fi

    read -r -p 'Enter ROM directory path for this gamelist: ' rom_dir || return
    rom_dir=$(expand_path "$rom_dir")

    if [[ ! -d "$rom_dir" ]]; then
        printf '%sError:%s ROM directory not found: %s\n' "$RED" "$NC" "$rom_dir"
        pause
        return
    fi

    local py_script
    py_script=$(mktemp)
    cat > "$py_script" <<'PY'
from __future__ import annotations

import datetime as dt
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


gamelist_path = Path(sys.argv[1]).expanduser()
rom_dir = Path(sys.argv[2]).expanduser().resolve(strict=False)

try:
    tree = ET.parse(gamelist_path)
except Exception as exc:
    print(f"Error: could not parse XML: {exc}")
    raise SystemExit(1)

root = tree.getroot()
games = list(root.findall("game"))


def text(game: ET.Element, tag: str) -> str:
    node = game.find(tag)
    if node is None or node.text is None:
        return ""
    return node.text.strip()


def resolve_rom_path(value: str) -> Path:
    raw = value.strip()
    if raw.startswith("file://"):
        raw = raw[7:]
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate.resolve(strict=False)
    while raw.startswith("./"):
        raw = raw[2:]
    primary = (rom_dir / raw).resolve(strict=False)
    if primary.exists():
        return primary
    fallback = (rom_dir / Path(raw).name).resolve(strict=False)
    if fallback.exists():
        return fallback
    return primary

orphans: list[tuple[ET.Element, Path]] = []
for game in games:
    rom_path = text(game, "path")
    if not rom_path:
        continue
    resolved = resolve_rom_path(rom_path)
    if not resolved.is_file():
        orphans.append((game, resolved))

if not orphans:
    print("No orphan gamelist entries found.")
    raise SystemExit(0)

print(f"Found {len(orphans)} orphan gamelist entr{'y' if len(orphans) == 1 else 'ies'}.\n")
for game, resolved in orphans[:80]:
    print(f"  {text(game, 'name') or '(unnamed)'} -> {text(game, 'path')}  [missing: {resolved}]")
if len(orphans) > 80:
    print(f"  ... {len(orphans) - 80} more not shown")

answer = input("Remove these orphan entries from gamelist.xml? (y/N): ").strip().lower()
if answer not in {"y", "yes"}:
    print("No changes made.")
    raise SystemExit(0)

backup = gamelist_path.with_name(gamelist_path.name + ".backup_" + dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copy2(gamelist_path, backup)
for game, _ in orphans:
    root.remove(game)

try:
    ET.indent(tree, space="  ")
except AttributeError:
    pass

tree.write(gamelist_path, encoding="utf-8", xml_declaration=True)
print(f"Backup created: {backup}")
print(f"Removed {len(orphans)} orphan gamelist entr{'y' if len(orphans) == 1 else 'ies'}.")
print("ROM files and media files were not changed.")
PY

    run_python_file "$py_script" "$gamelist" "$rom_dir"
    pause
}

# -----------------------------------------------------------------------------
# Operation 5: restore missing metadata from backup/source gamelist
# -----------------------------------------------------------------------------
restore_metadata_from_backup() {
    print_header 'Restore Missing Metadata From Backup'
    require_python3 || return

    local current_gamelist source_gamelist
    read -r -p 'Enter current gamelist.xml path to repair: ' current_gamelist || return
    current_gamelist=$(expand_path "$current_gamelist")

    if [[ ! -f "$current_gamelist" ]]; then
        printf '%sError:%s File not found: %s\n' "$RED" "$NC" "$current_gamelist"
        pause
        return
    fi

    read -r -p 'Enter backup/source gamelist.xml path with good metadata: ' source_gamelist || return
    source_gamelist=$(expand_path "$source_gamelist")

    if [[ ! -f "$source_gamelist" ]]; then
        printf '%sError:%s File not found: %s\n' "$RED" "$NC" "$source_gamelist"
        pause
        return
    fi

    local py_script
    py_script=$(mktemp)
    cat > "$py_script" <<'PY'
from __future__ import annotations

import copy
import datetime as dt
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

current_path = Path(sys.argv[1]).expanduser()
source_path = Path(sys.argv[2]).expanduser()

try:
    current_tree = ET.parse(current_path)
    source_tree = ET.parse(source_path)
except Exception as exc:
    print(f"Error: could not parse XML: {exc}")
    raise SystemExit(1)

current_root = current_tree.getroot()
source_root = source_tree.getroot()
current_games = list(current_root.findall("game"))
source_games = list(source_root.findall("game"))


def text(game: ET.Element, tag: str) -> str:
    node = game.find(tag)
    if node is None or node.text is None:
        return ""
    return node.text.strip()


def normalize_name(value: str) -> str:
    return " ".join(value.split()).casefold()


def normalize_path_key(value: str) -> str:
    raw = value.strip().replace("\\", "/")
    if raw.startswith("file://"):
        raw = raw[7:]
    while raw.startswith("./"):
        raw = raw[2:]
    return raw.strip()


def node_has_value(node: ET.Element | None) -> bool:
    if node is None:
        return False
    if node.text and node.text.strip():
        return True
    if node.attrib:
        return True
    if list(node):
        return True
    return False


def metadata_score(game: ET.Element) -> int:
    score = 0
    for child in list(game):
        if child.tag == "path":
            continue
        if child.text and child.text.strip():
            score += 3
        if child.attrib:
            score += len(child.attrib)
        score += len(list(child))
    return score


def merge_missing_metadata(target: ET.Element, source: ET.Element) -> int:
    copied = 0
    for child in list(source):
        if child.tag == "path":
            continue
        current = target.find(child.tag)
        if not node_has_value(current):
            if current is not None:
                target.remove(current)
            target.append(copy.deepcopy(child))
            copied += 1
    return copied

source_by_path: dict[str, list[ET.Element]] = {}
source_by_name: dict[str, list[ET.Element]] = {}
for game in source_games:
    path_key = normalize_path_key(text(game, "path"))
    name_key = normalize_name(text(game, "name"))
    if path_key:
        source_by_path.setdefault(path_key, []).append(game)
    if name_key:
        source_by_name.setdefault(name_key, []).append(game)

changed_games = 0
copied_fields = 0
path_matches = 0
name_matches = 0

for game in current_games:
    candidates: list[ET.Element] = []
    path_key = normalize_path_key(text(game, "path"))
    name_key = normalize_name(text(game, "name"))
    match_type = ""
    if path_key and path_key in source_by_path:
        candidates = source_by_path[path_key]
        match_type = "path"
    elif name_key and name_key in source_by_name:
        candidates = source_by_name[name_key]
        match_type = "name"
    if not candidates:
        continue
    source = max(candidates, key=metadata_score)
    copied = merge_missing_metadata(game, source)
    if copied:
        changed_games += 1
        copied_fields += copied
        if match_type == "path":
            path_matches += 1
        else:
            name_matches += 1

if copied_fields == 0:
    print("No missing metadata fields found to restore.")
    raise SystemExit(0)

print(f"Can restore {copied_fields} missing metadata field(s) across {changed_games} game entr{'y' if changed_games == 1 else 'ies'}.")
print(f"Matches used: {path_matches} by path, {name_matches} by name.")
answer = input("Write repaired gamelist.xml now? (y/N): ").strip().lower()
if answer not in {"y", "yes"}:
    print("No changes made.")
    raise SystemExit(0)

backup = current_path.with_name(current_path.name + ".backup_" + dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copy2(current_path, backup)
try:
    ET.indent(current_tree, space="  ")
except AttributeError:
    pass
current_tree.write(current_path, encoding="utf-8", xml_declaration=True)
print(f"Backup created: {backup}")
print(f"Restored {copied_fields} missing metadata field(s) across {changed_games} game entr{'y' if changed_games == 1 else 'ies'}.")
PY

    run_python_file "$py_script" "$current_gamelist" "$source_gamelist"
    pause
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        --version)
            printf 'ROM Cleanup Suite %s\n' "$VERSION"
            exit 0
            ;;
        '')
            ;;
        *)
            printf '%sError:%s Unknown argument: %s\n\n' "$RED" "$NC" "$1"
            show_help
            exit 2
            ;;
    esac

    while true; do
        clear_screen
        print_menu
        read -r -p 'Choose [1-6]: ' choice || exit 0

        case "$choice" in
            1)
                clear_screen
                find_rom_duplicates
                ;;
            2)
                clear_screen
                clean_gamelist_duplicates
                ;;
            3)
                clear_screen
                review_variants_gamelist_only
                ;;
            4)
                clear_screen
                clean_orphan_gamelist_entries
                ;;
            5)
                clear_screen
                restore_metadata_from_backup
                ;;
            6|q|Q|quit|exit)
                printf 'Goodbye.\n'
                exit 0
                ;;
            *)
                printf '%sInvalid choice.%s\n' "$RED" "$NC"
                pause
                ;;
        esac
    done
}

main "$@"
