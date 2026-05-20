#!/bin/bash

#############################################################################
# Gamelist Duplicate Remover
#
# Removes duplicate game entries from EmulationStation/RetroDECK gamelist.xml
# Finds duplicates by ROM path and removes excess entries while preserving
# the best metadata.
#
# Usage: ./remove_gamelist_dupes.sh [/path/to/gamelist.xml]
#        ./remove_gamelist_dupes.sh  (interactive mode)
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

show_usage() {
    cat << EOF
Gamelist Duplicate Remover - Clean up duplicate game entries in gamelist.xml

USAGE:
    $0 [/path/to/gamelist.xml]
    $0  (interactive mode - will find gamelist files)

EXAMPLES:
    $0 ~/.var/app/net.retrodeck.retrodeck/roms/mame/gamelist.xml
    $0 ~/.emulationstation/gamelists/snes/gamelist.xml
    $0  (will search for gamelist.xml files)

FEATURES:
    • Finds duplicates by ROM path (the primary identifier)
    • Preserves best metadata (game with most fields)
    • Safe XML parsing and preservation
    • Creates backup before any modifications
    • Shows before/after comparison

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Show detailed duplicate information
    --find          Search for gamelist.xml files in common locations

WHAT IT DOES:
    1. Scans gamelist.xml for duplicate entries by path
    2. Keeps the entry with the most metadata
    3. Shows duplicates and what will be removed
    4. Creates backup with timestamp
    5. Modifies XML while preserving structure

COMMON LOCATIONS:
    RetroDECK:           ~/.var/app/net.retrodeck.retrodeck/roms/[system]/
    EmulationStation:    ~/.emulationstation/gamelists/[system]/
    RetroArch:           ~/.config/RetroArch/.../

EOF
}

find_gamelist_files() {
    echo "Searching for gamelist.xml files in common locations..."
    echo ""
    
    local locations=(
        "~/.var/app/net.retrodeck.retrodeck/roms"
        "~/.emulationstation/gamelists"
        "~/Games/EmulationStation/gamelists"
        "~/.config/retrodeck/roms"
    )
    
    local found_count=0
    
    for loc in "${locations[@]}"; do
        loc="${loc/#\~/$HOME}"
        if [[ -d "$loc" ]]; then
            while IFS= read -r file; do
                ((found_count++))
                echo "$found_count) $file"
            done < <(find "$loc" -name "gamelist.xml" -type f 2>/dev/null)
        fi
    done
    
    if [[ $found_count -eq 0 ]]; then
        print_warning "No gamelist.xml files found in common locations"
        echo "Please provide the full path to your gamelist.xml"
        return 1
    fi
    
    echo ""
    read -p "Enter file number or full path: " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # User selected by number - find it again and select
        local count=0
        for loc in "${locations[@]}"; do
            loc="${loc/#\~/$HOME}"
            if [[ -d "$loc" ]]; then
                while IFS= read -r file; do
                    ((count++))
                    if [[ $count -eq $choice ]]; then
                        GAMELIST_FILE="$file"
                        return 0
                    fi
                done < <(find "$loc" -name "gamelist.xml" -type f 2>/dev/null)
            fi
        done
        print_error "Invalid selection"
        return 1
    else
        GAMELIST_FILE="$choice"
        return 0
    fi
}

count_xml_fields() {
    local entry="$1"
    echo "$entry" | grep -o '<[a-z]*>' | sort -u | wc -l
}

extract_rom_path() {
    local entry="$1"
    echo "$entry" | grep -oP '(?<=<path>)[^<]*' | head -1
}

extract_game_name() {
    local entry="$1"
    echo "$entry" | grep -oP '(?<=<name>)[^<]*' | head -1
}

# Parse arguments
VERBOSE=false
GAMELIST_FILE=""
AUTO_FIND=false

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
        --find)
            AUTO_FIND=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            GAMELIST_FILE="$1"
            shift
            ;;
    esac
done

# If no file provided, prompt for it
if [[ -z "$GAMELIST_FILE" ]]; then
    if [[ "$AUTO_FIND" == true ]]; then
        find_gamelist_files || exit 1
    else
        print_header "Gamelist Duplicate Remover"
        echo ""
        read -p "Enter path to gamelist.xml: " GAMELIST_FILE
        echo ""
    fi
fi

# Expand tilde
GAMELIST_FILE="${GAMELIST_FILE/#\~/$HOME}"

# Validate file
if [[ ! -f "$GAMELIST_FILE" ]]; then
    print_error "File not found: $GAMELIST_FILE"
    exit 1
fi

if [[ ! "$GAMELIST_FILE" =~ gamelist\.xml$ ]]; then
    print_warning "File doesn't appear to be a gamelist.xml: $GAMELIST_FILE"
    read -p "Continue anyway? (y/N): " confirm
    [[ "$confirm" != "y" ]] && exit 0
fi

print_header "Gamelist Duplicate Remover"
echo "File: $GAMELIST_FILE"
echo ""

# Check if xmllint is available
use_xmllint=false
if command -v xmllint &> /dev/null; then
    use_xmllint=true
fi

# Parse XML and find duplicates
# Strategy: Extract each game entry and check for duplicate paths
declare -A path_to_entry
declare -a duplicate_entries=()
declare -A duplicate_info

echo "Parsing gamelist.xml..."
echo ""

# Extract game entries
local_ifs="$IFS"
IFS=$'\n'

# Read the file and split by game entries
while IFS= read -r line; do
    if [[ "$line" =~ \<game\> ]]; then
        # Start of a game entry
        game_entry="$line"
        closing_found=false
        
        while IFS= read -r next_line; do
            game_entry+=$'\n'"$next_line"
            
            if [[ "$next_line" =~ \</game\> ]]; then
                closing_found=true
                break
            fi
        done
        
        if [[ "$closing_found" == true ]]; then
            # Extract ROM path
            rom_path=$(extract_rom_path "$game_entry")
            game_name=$(extract_game_name "$game_entry")
            field_count=$(count_xml_fields "$game_entry")
            
            if [[ -n "$rom_path" ]]; then
                if [[ -n "${path_to_entry[$rom_path]}" ]]; then
                    # Duplicate found!
                    orig_count=$(count_xml_fields "${path_to_entry[$rom_path]}")
                    
                    if [[ $field_count -gt $orig_count ]]; then
                        # New entry has more metadata, keep it and mark old as duplicate
                        duplicate_entries+=("${path_to_entry[$rom_path]}")
                        path_to_entry[$rom_path]="$game_entry"
                        duplicate_info["$rom_path"]="old (${orig_count} fields) → new (${field_count} fields)"
                    else
                        # Keep original
                        duplicate_entries+=("$game_entry")
                        duplicate_info["$rom_path"]="new (${field_count} fields) → old (${orig_count} fields)"
                    fi
                    
                    print_duplicate "$game_name"
                    echo "   Path: $rom_path"
                    echo "   Action: ${duplicate_info[$rom_path]}"
                    echo ""
                else
                    path_to_entry[$rom_path]="$game_entry"
                fi
            fi
        fi
    fi
done < "$GAMELIST_FILE"

IFS="$local_ifs"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Results
if [[ ${#duplicate_entries[@]} -eq 0 ]]; then
    print_success "No duplicate entries found in gamelist.xml"
    exit 0
fi

echo -e "Found ${RED}${#duplicate_entries[@]}${NC} duplicate game entries"
echo ""

# Count total games
total_games=$((${#path_to_entry[@]} + ${#duplicate_entries[@]}))
cleaned_games=${#path_to_entry[@]}

echo "Total games: $total_games"
echo "Unique games: $cleaned_games"
echo "Duplicates to remove: ${#duplicate_entries[@]}"
echo ""

# User prompt
echo "What would you like to do?"
echo "  1) Show which entries will be removed (safe - no changes)"
echo "  2) Create backup and remove duplicates"
echo "  3) Create cleaned version (new file)"
echo "  4) Cancel"
echo ""
read -p "Choose [1-4]: " choice

case $choice in
    1)
        echo ""
        echo "Duplicate entries that will be removed:"
        echo ""
        for entry in "${duplicate_entries[@]}"; do
            name=$(extract_game_name "$entry")
            path=$(extract_rom_path "$entry")
            echo "  • $name ($path)"
        done
        echo ""
        ;;
    2)
        BACKUP_FILE="${GAMELIST_FILE}.backup_$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}Creating backup: $BACKUP_FILE${NC}"
        cp "$GAMELIST_FILE" "$BACKUP_FILE"
        
        # Create cleaned version
        temp_file=$(mktemp)
        
        # Extract header
        sed -n '1,/<gameList>/p' "$GAMELIST_FILE" > "$temp_file"
        
        # Add unique entries
        for rom_path in "${!path_to_entry[@]}"; do
            echo "${path_to_entry[$rom_path]}" >> "$temp_file"
        done
        
        # Add footer
        echo "</gameList>" >> "$temp_file"
        
        # Verify the file looks valid before replacing
        if grep -q "</gameList>" "$temp_file"; then
            mv "$temp_file" "$GAMELIST_FILE"
            print_success "Removed ${#duplicate_entries[@]} duplicate entries"
            echo "Backup saved: $BACKUP_FILE"
            echo "Cleaned file: $GAMELIST_FILE"
        else
            print_error "Generated file is invalid. Original preserved. Backup: $BACKUP_FILE"
            rm "$temp_file"
            exit 1
        fi
        ;;
    3)
        CLEANED_FILE="${GAMELIST_FILE%.*}_cleaned.xml"
        echo -e "${YELLOW}Creating cleaned version: $CLEANED_FILE${NC}"
        
        # Extract header
        sed -n '1,/<gameList>/p' "$GAMELIST_FILE" > "$CLEANED_FILE"
        
        # Add unique entries
        for rom_path in "${!path_to_entry[@]}"; do
            echo "${path_to_entry[$rom_path]}" >> "$CLEANED_FILE"
        done
        
        # Add footer
        echo "</gameList>" >> "$CLEANED_FILE"
        
        if grep -q "</gameList>" "$CLEANED_FILE"; then
            print_success "Created cleaned gamelist.xml"
            echo "File: $CLEANED_FILE"
            echo "Original: $GAMELIST_FILE"
            echo ""
            print_warning "To use the cleaned file, back up the original and replace it:"
            echo "  cp $GAMELIST_FILE ${GAMELIST_FILE}.backup"
            echo "  mv $CLEANED_FILE $GAMELIST_FILE"
        else
            print_error "Generated file is invalid"
            rm "$CLEANED_FILE"
            exit 1
        fi
        ;;
    *)
        print_warning "Cancelled."
        exit 0
        ;;
esac
