#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/rom_cleanup.sh"

bash -n "$script"

help_output=$(NO_COLOR=1 "$script" --help)
if [[ "$help_output" != *"ROM Cleanup Suite"* ]]; then
    echo "Help output did not include expected title" >&2
    exit 1
fi

if [[ "$help_output" == *$'\033'* ]]; then
    echo "Help output contained ANSI escape characters despite NO_COLOR=1" >&2
    exit 1
fi

echo "smoke tests passed"
