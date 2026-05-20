#!/usr/bin/env bash

#############################################################################
# ROM Cleanup Suite
#
# Miguel Manzano / MiGzY
# https://github.com/MiGzY/rom-cleanup-suite/
#
# Safer, finished version:
#   1. Find exact duplicate ROM files by SHA256 and optionally move duplicates
#      to a quarantine folder.
#   2. Remove duplicate gamelist.xml entries with the same <path>, keeping the
#      entry with the most metadata.
#   3. Review games with the same <name> but different <path> values and choose
#      which variant to keep.
#
# Usage:
#   ./rom_cleanup.sh
#   ./rom_cleanup.sh --help
#############################################################################

set -Eeuo pipefail

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
    cat <<'EOF'
ROM Cleanup Suite

USAGE:
    ./rom_cleanup.sh          Open the interactive menu
    ./rom_cleanup.sh --help   Show this help

OPERATIONS:
    1. Find exact duplicate ROM files
       - Hashes ROM files with SHA256.
       - Keeps the first copy found.
       - Optionally moves duplicates to a quarantine folder.

    2. Clean duplicate gamelist.xml entries
       - Finds repeated <game> entries with the same <path>.
       - Keeps the entry with the most metadata.
       - Creates a timestamped backup before writing changes.

    3. Find and remove game variants
       - Finds repeated <name> values with different ROM paths.
       - Lets you choose which path to keep for each game.
       - Optionally moves removed ROM files to a quarantine folder.

NOTES:
    - Nothing is permanently deleted by default.
    - Duplicate ROMs and unwanted variants are moved to quarantine folders.
    - gamelist.xml is backed up before it is changed.
EOF
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
    printf '  %s[3]%s Find and remove game variants interactively\n' "$YELLOW" "$NC"
    printf '  %s[4]%s Exit\n\n' "$YELLOW" "$NC"
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

# -----------------------------------------------------------------------------
# Operation 1: exact duplicate ROM files
# -----------------------------------------------------------------------------
find_rom_duplicates() {
    print_header 'Find Exact Duplicate ROM Files'

    local rom_dir recursive file_count count pct hash size size_mb keeper answer
    local quarantine rel dest base ext suffix
    local -a files duplicate_files
    declare -A hash_to_keeper

    read -r -p 'Enter ROM directory path: ' rom_dir || return
    rom_dir=$(expand_path "$rom_dir")

    if [[ ! -d "$rom_dir" ]]; then
        printf '%sError:%s Directory not found: %s\n' "$RED" "$NC" "$rom_dir"
        pause
        return
    fi

    read -r -p 'Search recursively? (y/N): ' recursive || recursive=''

    printf 'Scanning files...\n'
    if is_yes "$recursive"; then
        mapfile -d '' files < <(find "$rom_dir" -type f -print0 | sort -z)
    else
        mapfile -d '' files < <(find "$rom_dir" -maxdepth 1 -type f -print0 | sort -z)
    fi

    file_count=${#files[@]}
    if (( file_count == 0 )); then
        printf '%sNo files found.%s\n' "$YELLOW" "$NC"
        pause
        return
    fi

    printf 'Found %d files. Hashing...\n' "$file_count"

    count=0
    duplicate_files=()
    for file in "${files[@]}"; do
        ((++count))
        if (( count == file_count || count % 100 == 0 )); then
            pct=$((count * 100 / file_count))
            printf '\rHashed: %d/%d (%d%%)' "$count" "$file_count" "$pct"
        fi

        if ! hash=$(sha256sum -- "$file" 2>/dev/null | awk '{print $1}'); then
            printf '\n%sWarning:%s Could not hash: %s\n' "$YELLOW" "$NC" "$file"
            continue
        fi

        if [[ -v "hash_to_keeper[$hash]" ]]; then
            keeper=${hash_to_keeper[$hash]}
            size=$(stat -c '%s' -- "$file" 2>/dev/null || printf '0')
            size_mb=$((size / 1024 / 1024))
            duplicate_files+=("$file")
            printf '\n%sDuplicate:%s %s (%d MB)\n' "$RED" "$NC" "${file#$rom_dir/}" "$size_mb"
            printf '  Matches: %s\n' "${keeper#$rom_dir/}"
        else
            hash_to_keeper[$hash]="$file"
        fi
    done
    printf '\n'

    if (( ${#duplicate_files[@]} == 0 )); then
        printf '%sNo exact duplicate files found.%s\n' "$GREEN" "$NC"
        pause
        return
    fi

    printf '\n%sFound %d duplicate file(s).%s\n' "$RED" "${#duplicate_files[@]}" "$NC"
    read -r -p 'Move duplicate copies to a quarantine folder? (y/N): ' answer || answer=''

    if ! is_yes "$answer"; then
        printf 'No files moved.\n'
        pause
        return
    fi

    quarantine="$rom_dir/_rom_cleanup_duplicates_$(date +%Y%m%d_%H%M%S)"
    mkdir -p -- "$quarantine"

    for file in "${duplicate_files[@]}"; do
        rel=${file#$rom_dir/}
        dest="$quarantine/$rel"
        mkdir -p -- "$(dirname -- "$dest")"

        if [[ -e "$dest" ]]; then
            base=${dest%.*}
            ext=''
            if [[ "$dest" == *.* ]]; then
                ext=.${dest##*.}
            fi
            suffix=1
            while [[ -e "${base}_${suffix}${ext}" ]]; do
                ((++suffix))
            done
            dest="${base}_${suffix}${ext}"
        fi

        mv -- "$file" "$dest"
        printf 'Moved: %s -> %s\n' "${file#$rom_dir/}" "${dest#$quarantine/}"
    done

    printf '\n%sDone.%s Quarantine folder:\n%s\n' "$GREEN" "$NC" "$quarantine"
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

import datetime as _dt
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

path = Path(sys.argv[1])

try:
    tree = ET.parse(path)
except Exception as exc:
    print(f"Error: Could not parse XML: {exc}")
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

def metadata_score(game: ET.Element) -> int:
    score = 0
    for child in list(game):
        if child.text and child.text.strip():
            score += 2
        if child.attrib:
            score += 1
        score += len(list(child))
    return score

by_path: dict[str, list[ET.Element]] = {}
for game in games:
    rom_path = text(game, "path")
    if rom_path:
        by_path.setdefault(rom_path, []).append(game)

groups = [(rom_path, entries) for rom_path, entries in by_path.items() if len(entries) > 1]

if not groups:
    print("No duplicate gamelist entries found.")
    raise SystemExit(0)

duplicate_total = sum(len(entries) - 1 for _, entries in groups)
entry_word = "entry" if duplicate_total == 1 else "entries"
print(f"Found {duplicate_total} duplicate gamelist {entry_word}.\n")

planned: list[ET.Element] = []
for rom_path, entries in groups:
    keep = max(entries, key=metadata_score)
    keep_name = text(keep, "name") or "(unnamed)"
    print(f"Path: {rom_path}")
    print(f"  Keep:   {keep_name}  [metadata score {metadata_score(keep)}]")
    for entry in entries:
        if entry is keep:
            continue
        planned.append(entry)
        remove_name = text(entry, "name") or "(unnamed)"
        print(f"  Remove: {remove_name}  [metadata score {metadata_score(entry)}]")
    print()

answer = input("Remove these duplicate entries from gamelist.xml? (y/N): ").strip().lower()
if answer not in {"y", "yes"}:
    print("No changes made.")
    raise SystemExit(0)

backup = path.with_name(path.name + ".backup_" + _dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copy2(path, backup)

for entry in planned:
    root.remove(entry)

try:
    ET.indent(tree, space="  ")
except AttributeError:
    pass

tree.write(path, encoding="utf-8", xml_declaration=True)
removed_word = "entry" if len(planned) == 1 else "entries"
print(f"Backup created: {backup}")
print(f"Removed {len(planned)} duplicate {removed_word}.")
PY

    python3 "$py_script" "$gamelist"
    rm -f "$py_script"

    pause
}

# -----------------------------------------------------------------------------
# Operation 3: same game name, different ROM paths
# -----------------------------------------------------------------------------
interactive_remove_variants() {
    print_header 'Find and Remove Game Variants'
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

import datetime as _dt
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

path = Path(sys.argv[1])
gamelist_dir = path.parent

try:
    tree = ET.parse(path)
except Exception as exc:
    print(f"Error: Could not parse XML: {exc}")
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

def norm_name(name: str) -> str:
    return " ".join(name.split()).casefold()

def resolve_rom_path(path_text: str) -> Path:
    raw = path_text.strip()
    candidate = Path(raw)
    if candidate.is_absolute():
        return candidate
    if raw.startswith("./"):
        raw = raw[2:]
    return gamelist_dir / raw

def safe_move(src: Path, quarantine: Path) -> str:
    try:
        src_resolved = src.resolve(strict=False)
    except Exception:
        src_resolved = src

    try:
        rel = src_resolved.relative_to(gamelist_dir.resolve(strict=False))
    except Exception:
        rel = Path(src.name)

    dest = quarantine / rel
    dest.parent.mkdir(parents=True, exist_ok=True)

    if dest.exists():
        stem = dest.stem
        suffix = dest.suffix
        counter = 1
        while True:
            candidate = dest.with_name(f"{stem}_{counter}{suffix}")
            if not candidate.exists():
                dest = candidate
                break
            counter += 1

    shutil.move(str(src), str(dest))
    return str(dest)

by_name: dict[str, list[ET.Element]] = {}
for game in games:
    name = text(game, "name")
    rom_path = text(game, "path")
    if name and rom_path:
        by_name.setdefault(norm_name(name), []).append(game)

variant_groups: list[tuple[str, list[ET.Element]]] = []
for key, entries in by_name.items():
    unique_paths = {text(entry, "path") for entry in entries}
    if len(unique_paths) > 1:
        display_name = text(entries[0], "name") or key
        variant_groups.append((display_name, entries))

variant_groups.sort(key=lambda item: item[0].casefold())

if not variant_groups:
    print("No games with multiple ROM paths found.")
    raise SystemExit(0)

print(f"Found {len(variant_groups)} game name(s) with multiple ROM paths.\n")
print("For each group, enter the number to keep, press Enter to skip, or type q to stop.\n")

selected_remove: list[ET.Element] = []

for group_index, (display_name, entries) in enumerate(variant_groups, start=1):
    print(f"[{group_index}/{len(variant_groups)}] {display_name}")
    for idx, entry in enumerate(entries, start=1):
        rom_path = text(entry, "path") or "(no path)"
        desc = text(entry, "desc")
        desc_note = ""
        if desc:
            desc_note = " - has description"
        print(f"  {idx}) {rom_path}{desc_note}")

    choice = input("Keep which one? [Enter skip/q quit]: ").strip().lower()
    print()

    if not choice:
        continue
    if choice in {"q", "quit", "exit"}:
        break
    if not choice.isdigit():
        print("Not a number; skipped.\n")
        continue

    keep_index = int(choice)
    if keep_index < 1 or keep_index > len(entries):
        print("Out of range; skipped.\n")
        continue

    keep = entries[keep_index - 1]
    for entry in entries:
        if entry is not keep:
            selected_remove.append(entry)

if not selected_remove:
    print("No variants selected for removal.")
    raise SystemExit(0)

print("Selected entries to remove from gamelist.xml:")
for entry in selected_remove:
    name_value = text(entry, "name") or "(unnamed)"
    path_value = text(entry, "path") or "(no path)"
    print(f"  - {name_value} -> {path_value}")
print()

answer = input("Update gamelist.xml now? (y/N): ").strip().lower()
if answer not in {"y", "yes"}:
    print("No changes made.")
    raise SystemExit(0)

backup = path.with_name(path.name + ".backup_" + _dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copy2(path, backup)

removed_paths = [text(entry, "path") for entry in selected_remove if text(entry, "path")]
for entry in selected_remove:
    root.remove(entry)

try:
    ET.indent(tree, space="  ")
except AttributeError:
    pass

tree.write(path, encoding="utf-8", xml_declaration=True)
removed_word = "entry" if len(selected_remove) == 1 else "entries"
print(f"Backup created: {backup}")
print(f"Removed {len(selected_remove)} {removed_word} from gamelist.xml.")

move_answer = input("Move removed ROM file(s) to quarantine too? (y/N): ").strip().lower()
if move_answer not in {"y", "yes"}:
    print("ROM files left in place.")
    raise SystemExit(0)

quarantine = gamelist_dir / ("_rom_cleanup_variants_" + _dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
quarantine.mkdir(exist_ok=True)

moved = 0
missing = 0
for rom_path_text in removed_paths:
    src = resolve_rom_path(rom_path_text)
    if src.exists() and src.is_file():
        dest = safe_move(src, quarantine)
        moved += 1
        print(f"Moved: {src} -> {dest}")
    else:
        missing += 1
        print(f"Skipped missing file: {src}")

print(f"Moved {moved} file(s) to: {quarantine}")
if missing:
    print(f"Skipped {missing} missing file(s).")
PY

    python3 "$py_script" "$gamelist"
    rm -f "$py_script"

    pause
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
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
        read -r -p 'Choose [1-4]: ' choice || exit 0

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
                interactive_remove_variants
                ;;
            4|q|Q|quit|exit)
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
