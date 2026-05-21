#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/rom_cleanup.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

assert_contains() {
    local haystack=$1
    local needle=$2
    if [[ "$haystack" != *"$needle"* ]]; then
        printf 'Expected output to contain: %s\n' "$needle" >&2
        return 1
    fi
}

assert_not_contains() {
    local haystack=$1
    local needle=$2
    if [[ "$haystack" == *"$needle"* ]]; then
        printf 'Expected output not to contain: %s\n' "$needle" >&2
        return 1
    fi
}

bash -n "$script"
help_output=$(NO_COLOR=1 "$script" --help)
assert_contains "$help_output" "ROM Cleanup Suite"
assert_contains "$help_output" "Remove orphan gamelist.xml entries"
if [[ "$help_output" == *$'\033'* ]]; then
    echo "Help output contained ANSI escape characters despite NO_COLOR=1" >&2
    exit 1
fi

# Operation 1: exact duplicate ROM cleanup should prefer the gamelist-referenced file.
op1_dir="$tmp/op1"
mkdir -p "$op1_dir/roms"
printf 'same-rom-data' > "$op1_dir/roms/a.zip"
printf 'same-rom-data' > "$op1_dir/roms/b.zip"
cat > "$op1_dir/gamelist.xml" <<'XML'
<gameList>
  <game>
    <path>./b.zip</path>
    <name>Referenced copy</name>
  </game>
</gameList>
XML
NO_COLOR=1 printf '1\n%s\nn\n%s\ny\n\n6\n' "$op1_dir/roms" "$op1_dir/gamelist.xml" | NO_COLOR=1 "$script" >/tmp/rom_cleanup_op1.out
if [[ ! -f "$op1_dir/roms/b.zip" ]]; then
    echo "Operation 1 moved the referenced duplicate file" >&2
    exit 1
fi
if [[ -f "$op1_dir/roms/a.zip" ]]; then
    echo "Operation 1 did not move the unreferenced duplicate file" >&2
    exit 1
fi

# Operation 2: duplicate path cleanup should merge metadata into the kept entry.
op2_dir="$tmp/op2"
mkdir -p "$op2_dir"
op2_gamelist="$op2_dir/gamelist.xml"
cat > "$op2_gamelist" <<'XML'
<gameList>
  <game>
    <path>foo.zip</path>
    <name>Foo bare</name>
  </game>
  <game>
    <path>./foo.zip</path>
    <name>Foo rich</name>
    <desc>Rich description</desc>
    <image>./media/foo.png</image>
  </game>
</gameList>
XML
printf '2\n%s\ny\n\n6\n' "$op2_gamelist" | NO_COLOR=1 "$script" >/tmp/rom_cleanup_op2.out
python3 - "$op2_gamelist" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
games = root.findall('game')
assert len(games) == 1, len(games)
assert games[0].findtext('desc') == 'Rich description'
assert games[0].findtext('image') == './media/foo.png'
PY

# Operation 3: variant cleanup should keep existing ROMs and copy metadata from removed entries.
op3_dir="$tmp/op3"
mkdir -p "$op3_dir/roms"
printf 'working' > "$op3_dir/roms/working.zip"
op3_gamelist="$op3_dir/gamelist.xml"
cat > "$op3_gamelist" <<'XML'
<gameList>
  <game>
    <path>./missing-rich.zip</path>
    <name>Regional Game</name>
    <desc>Metadata from missing regional entry</desc>
    <image>./media/regional.png</image>
  </game>
  <game>
    <path>./working.zip</path>
    <name>Regional Game</name>
  </game>
</gameList>
XML
printf '3\n%s\n%s\n2\ny\n\n6\n' "$op3_gamelist" "$op3_dir/roms" | NO_COLOR=1 "$script" >/tmp/rom_cleanup_op3.out
python3 - "$op3_gamelist" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
games = root.findall('game')
assert len(games) == 1, len(games)
game = games[0]
assert game.findtext('path') == './working.zip', game.findtext('path')
assert game.findtext('desc') == 'Metadata from missing regional entry'
assert game.findtext('image') == './media/regional.png'
PY
if [[ ! -f "$op3_dir/roms/working.zip" ]]; then
    echo "Operation 3 moved a ROM file; it should be gamelist-only" >&2
    exit 1
fi

# Operation 4: orphan cleanup should remove missing entries using a separate ROM directory.
op4_dir="$tmp/op4"
mkdir -p "$op4_dir/roms" "$op4_dir/gamelists/mame"
printf 'good' > "$op4_dir/roms/good.zip"
op4_gamelist="$op4_dir/gamelists/mame/gamelist.xml"
cat > "$op4_gamelist" <<'XML'
<gameList>
  <game><path>./good.zip</path><name>Good</name></game>
  <game><path>./gone.zip</path><name>Gone</name></game>
</gameList>
XML
printf '4\n%s\n%s\ny\n\n6\n' "$op4_gamelist" "$op4_dir/roms" | NO_COLOR=1 "$script" >/tmp/rom_cleanup_op4.out
python3 - "$op4_gamelist" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
paths = [game.findtext('path') for game in root.findall('game')]
assert paths == ['./good.zip'], paths
PY

# Operation 5: metadata restore should copy missing metadata by name when the path changed.
op5_dir="$tmp/op5"
mkdir -p "$op5_dir"
op5_current="$op5_dir/current.xml"
op5_backup="$op5_dir/backup.xml"
cat > "$op5_current" <<'XML'
<gameList>
  <game><path>./new-region.zip</path><name>Changed Region</name></game>
</gameList>
XML
cat > "$op5_backup" <<'XML'
<gameList>
  <game>
    <path>./old-region.zip</path>
    <name>Changed Region</name>
    <desc>Recovered description</desc>
    <rating>0.8</rating>
  </game>
</gameList>
XML
printf '5\n%s\n%s\ny\n\n6\n' "$op5_current" "$op5_backup" | NO_COLOR=1 "$script" >/tmp/rom_cleanup_op5.out
python3 - "$op5_current" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
game = root.find('game')
assert game is not None
assert game.findtext('desc') == 'Recovered description'
assert game.findtext('rating') == '0.8'
PY

echo "smoke tests passed"
