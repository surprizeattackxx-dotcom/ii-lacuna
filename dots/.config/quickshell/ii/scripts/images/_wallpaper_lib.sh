MONITOR_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/wallpaper/monitors"

get_focused_wallpaper() {
    local monitor
    monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' 2>/dev/null)

    if [[ -z "$monitor" ]]; then
        local first
        first=$(ls "$MONITOR_STATE_DIR"/*.json 2>/dev/null | head -1)
        monitor=$(basename "$first" .json 2>/dev/null)
    fi

    if [[ -n "$monitor" && -f "$MONITOR_STATE_DIR/${monitor}.json" ]]; then
        local path
        path=$(jq -r '.path // empty' "$MONITOR_STATE_DIR/${monitor}.json" 2>/dev/null)
        if [[ -n "$path" && -f "$path" ]]; then
            echo "$path"
            return
        fi
    fi

    local fallback
    fallback=$(ls -t "$MONITOR_STATE_DIR"/*.json 2>/dev/null | head -1)
    if [[ -n "$fallback" ]]; then
        local path
        path=$(jq -r '.path // empty' "$fallback" 2>/dev/null)
        if [[ -n "$path" && -f "$path" ]]; then
            echo "$path"
            return
        fi
    fi

    echo ""
}

ensure_venv() {
    if [[ -z "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]]; then
        echo "ERROR: ILLOGICAL_IMPULSE_VIRTUAL_ENV is not set" >&2
        exit 1
    fi
    local activate="${ILLOGICAL_IMPULSE_VIRTUAL_ENV/#\~/$HOME}/bin/activate"
    if [[ ! -f "$activate" ]]; then
        echo "ERROR: Virtual environment activate script not found: $activate" >&2
        exit 1
    fi
    source "$activate"
}
