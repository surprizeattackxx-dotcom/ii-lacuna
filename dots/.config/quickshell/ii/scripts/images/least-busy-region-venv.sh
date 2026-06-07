#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_wallpaper_lib.sh"

ensure_venv

has_positional_file() {
    for arg in "$@"; do
        if [[ "$arg" != --* && "$arg" != -* && -f "$arg" ]]; then
            return 0
        fi
    done
    return 1
}

if ! has_positional_file "$@"; then
    injected=$(get_focused_wallpaper)
    if [[ -n "$injected" ]]; then
        "$SCRIPT_DIR/least_busy_region.py" "$@" "$injected"
    else
        "$SCRIPT_DIR/least_busy_region.py" "$@"
    fi
else
    "$SCRIPT_DIR/least_busy_region.py" "$@"
fi

deactivate
