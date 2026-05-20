#!/bin/bash

#############################################################################
# ROM Duplicate Finder
# 
# Scans a directory of ROM files and identifies duplicates by SHA256 hash.
# Safe and non-destructive - shows you what's duplicated before deleting.
#
# Usage: ./find_rom_dupes.sh [/path/to/roms]
#        ./find_rom_dupes.sh  (interactive mode)
#
# GitHub: https://github.com/MiGzY/rom-duplicate-finder
#############################################################################

set -euo pipefail
 
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
 
# Functions
print_header() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}
 
print_error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
}
 
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}
 
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}
 
print_duplicate() {
    echo -e "${RED}🔴 DUPLICATE:${NC} $1"
}
 
format_size() {
    local bytes=$1
    if command -v numfmt &> /dev/null; then
        numfmt --to=iec-i --suffix=B "$bytes"
    else
        echo "$bytes bytes"
    fi
}
 
show_usage() {
    cat << EOF
ROM Duplicate Finder - Remove duplicate ROM files safely
 
USAGE:
    $0 [/path/to/roms]
    $0  (interactive mode - will prompt for path)
 
EXAMPLES:
    $0 ~/Games/retrodeck/roms/mame
    $0 /media/games/snes
    $0  (will ask for path interactively)
 
FEATURES:
    • Finds duplicates by SHA256 hash (most accurate)
    • Shows before/after comparison
    • Safe options: preview, backup, or cancel
    • Works with any ROM format (.zip, .7z, .rom, etc.)
 
OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Show detailed scanning progress
 
EOF
}
 
# Parse arguments
VERBOSE=false
ROM_DIR=""
 
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            ROM_DIR="$1"
            shift
            ;;
    esac
done
 
# If no directory provided, prompt interactively
if [[ -z "$ROM_DIR" ]]; then
    print_header "ROM Duplicate Finder"
    echo ""
    read -p "Enter path to ROM directory: " ROM_DIR
    echo ""
fi
 
# Expand tilde if present
ROM_DIR="${ROM_DIR/#\~/$HOME}"
 
# Validate directory
if [[ ! -d "$ROM_DIR" ]]; then
    print_error "Directory not found: $ROM_DIR"
    exit 1
fi
 
# Check if directory is empty
file_count=$(find "$ROM_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
if [[ $file_count -eq 0 ]]; then
    print_error "No files found in: $ROM_DIR"
    exit 1
fi
 
print_header "ROM Duplicate Finder"
echo "Scanning: $ROM_DIR"
echo "Files: $file_count"
echo ""
 
cd "$ROM_DIR" || exit 1
 
# Use temp file to store hashes (avoids array memory issues with large collections)
temp_hashes=$(mktemp)
trap "rm -f $temp_hashes" EXIT
 
declare -a duplicate_files=()
scanned=0
 
# Build hash list
for file in *; do
    if [[ -f "$file" ]]; then
        ((scanned++))
        
        if (( scanned % 500 == 0 )); then
            pct=$((scanned * 100 / file_count))
            echo -ne "Hashing: $scanned/$file_count ($pct%)\r"
        fi
        
        # Calculate hash
        hash=$(sha256sum "$file" | awk '{print $1}')
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        
        # Store hash: hash|filename|size
        echo "$hash|$file|$size" >> "$temp_hashes"
    fi
done
 
echo -ne "\n"
echo "Checking for duplicates..."
echo ""
 
# Find duplicates
declare -A seen
while IFS='|' read -r hash file size; do
    if [[ -n "${seen[$hash]}" ]]; then
        # Found a duplicate
        duplicate_files+=("$file")
        orig="${seen[$hash]}"
        print_duplicate "$file"
        echo "   Original: $orig"
        echo "   Size: $(format_size "$size")"
        echo ""
    else
        seen[$hash]="$file"
    fi
done < "$temp_hashes"
 
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
 
# Results
if [[ ${#duplicate_files[@]} -eq 0 ]]; then
    print_success "No duplicate ROMs found!"
    exit 0
fi
 
echo -e "Found ${RED}${#duplicate_files[@]}${NC} duplicate file(s)"
echo ""
 
# Calculate space
total_size=0
for dup in "${duplicate_files[@]}"; do
    size=$(stat -c%s "$dup" 2>/dev/null)
    total_size=$((total_size + size))
done
 
echo "Space to recover: $(format_size "$total_size")"
echo ""
 
# User prompt
echo "What would you like to do?"
echo "  1) Show removal commands (safe - no changes)"
echo "  2) Create backup and delete duplicates"
echo "  3) List duplicate files"
echo "  4) Cancel"
echo ""
read -p "Choose [1-4]: " choice
 
case $choice in
    1)
        echo ""
        echo "Commands to remove duplicates:"
        echo ""
        echo "cd \"$ROM_DIR\""
        for dup in "${duplicate_files[@]}"; do
            echo "rm \"$dup\""
        done
        echo ""
        ;;
    2)
        BACKUP_DIR="$ROM_DIR/../roms_dupes_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        echo -e "${YELLOW}Backing up to: $BACKUP_DIR${NC}"
        
        cp "${duplicate_files[@]}" "$BACKUP_DIR/" 2>/dev/null || {
            print_error "Failed to create backup. Aborting."
            exit 1
        }
        
        echo "Removing duplicates..."
        rm "${duplicate_files[@]}" || {
            print_error "Failed to remove files. Your backup is safe at: $BACKUP_DIR"
            exit 1
        }
        
        print_success "Removed ${#duplicate_files[@]} duplicate file(s)"
        echo "Backup saved: $BACKUP_DIR"
        echo "Space recovered: $(format_size "$total_size")"
        ;;
    3)
        echo "Duplicate files:"
        for dup in "${duplicate_files[@]}"; do
            size=$(stat -c%s "$dup" 2>/dev/null)
            printf "  %s (%s)\n" "$dup" "$(format_size "$size")"
        done
        echo ""
        ;;
    *)
        print_warning "Cancelled."
        exit 0
        ;;
esac
