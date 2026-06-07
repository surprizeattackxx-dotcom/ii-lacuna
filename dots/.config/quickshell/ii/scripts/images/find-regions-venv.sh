#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_wallpaper_lib.sh"

ensure_venv

has_image_flag() {
    local prev=""
    for arg in "$@"; do
        if [[ "$prev" == "-i" || "$prev" == "--image" ]]; then
            return 0
        fi
        if [[ "$arg" == --image=* ]]; then
            return 0
        fi
        prev="$arg"
    done
    return 1
}

if ! has_image_flag "$@"; then
    injected=$(get_focused_wallpaper)
    if [[ -n "$injected" ]]; then
        "$SCRIPT_DIR/find_regions.py" "$@" --image "$injected"
    else
        "$SCRIPT_DIR/find_regions.py" "$@"
    fi
else
    "$SCRIPT_DIR/find_regions.py" "$@"
fi

deactivate
