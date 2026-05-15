#!/bin/bash
# Dynamic monitor daemon — listens for hotplug events and manages workspace migration.
# Handles: monitor disconnect → move workspaces to fallback; reconnect → restore.
# Respects disabled-monitors list from toggle-tv.sh.

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
STATE_FILE="$HOME/.config/hypr/monitor-state.lua"
PID_FILE="/tmp/hypr-monitor-watch.pid"
DISABLED_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/wallpaper/monitors_disabled.txt"

[[ -S "$SOCKET" ]] || { echo "No Hyprland socket at $SOCKET"; exit 1; }

# Workspace ranges — must match workspaces.lua
declare -A WS_START WS_END
WS_START["DP-1"]=1;     WS_END["DP-1"]=10
WS_START["DP-2"]=11;    WS_END["DP-2"]=20
WS_START["HDMI-A-1"]=21; WS_END["HDMI-A-1"]=30
FALLBACK_ORDER=("DP-1" "DP-2" "HDMI-A-1")
KNOWN_MONS=("DP-1" "DP-2" "HDMI-A-1")

# Kill existing instance if running
if [[ -f "$PID_FILE" ]]; then
    old_pid=$(cat "$PID_FILE")
    if kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null
        sleep 0.2
    fi
fi
echo $$ > "$PID_FILE"

# In-memory: which workspaces were moved per monitor
declare -A MOVED

# ── Helpers ──────────────────────────────────────────────────────────

active_mons()   { hyprctl monitors all -j | jq -r '.[] | select(.disabled == false) | .name'; }
disabled_mons() { [[ -f "$DISABLED_FILE" ]] && cat "$DISABLED_FILE" || true; }

is_active()   { active_mons | grep -qxF "$1"; }
is_disabled() { disabled_mons | grep -qxF "$1"; }

get_fallback() {
    local exclude="$1"
    for fb in "${FALLBACK_ORDER[@]}"; do
        [[ "$fb" == "$exclude" ]] && continue
        is_active "$fb" && { echo "$fb"; return; }
    done
    echo ""
}

write_state() {
    local active disabled
    active=$(active_mons)
    disabled=$(disabled_mons)
    {
        echo "return {"
        echo "  active = {"
        while IFS= read -r m; do [[ -n "$m" ]] && echo "    \"$m\","; done <<< "$active"
        echo "  },"
        echo "  disabled = {"
        while IFS= read -r m; do [[ -n "$m" ]] && echo "    \"$m\","; done <<< "$disabled"
        echo "  },"
        echo "  moved = {"
        for mon in "${KNOWN_MONS[@]}"; do
            local val="${MOVED[$mon]}"
            [[ -n "$val" ]] && echo "    [\"$mon\"] = {$val},"
        done
        echo "  }"
        echo "}"
    } > "$STATE_FILE"
}

read_state() {
    MOVED=()
    [[ ! -f "$STATE_FILE" ]] && return
    local in_moved=0 mon=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*moved[[:space:]]*=[[:space:]]*\{ ]]; then
            in_moved=1
        elif [[ $in_moved -eq 1 && "$line" =~ \[\\\"(.+)\\\"\]\]\ *=\ *\{(.+)\},? ]]; then
            MOVED["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
        elif [[ $in_moved -eq 1 && "$line" =~ ^[[:space:]]*\} ]]; then
            in_moved=0
        fi
    done < "$STATE_FILE"
}

# ── Core logic ───────────────────────────────────────────────────────

evacuate() {
    local mon="$1"
    local start="${WS_START[$mon]}" end="${WS_END[$mon]}"
    [[ -z "$start" ]] && return

    local fb
    fb=$(get_fallback "$mon")
    [[ -z "$fb" ]] && { echo "No fallback for $mon, skipping"; return; }

    local moved_ws=()
    for ((ws = start; ws <= end; ws++)); do
        hyprctl dispatch moveworkspacetomonitor "$ws" "$fb" &>/dev/null
        moved_ws+=("$ws")
    done
    MOVED["$mon"]=$(IFS=,; echo "${moved_ws[*]}")
    write_state
    notify-send "Monitor: $mon disconnected" "Workspaces $start–$end → $fb" -a "Hyprland"
}

restore() {
    local mon="$1"
    local moved="${MOVED[$mon]}"
    [[ -z "$moved" ]] && return
    is_active "$mon" || return

    IFS=',' read -ra wss <<< "$moved"
    for ws in "${wss[@]}"; do
        hyprctl dispatch moveworkspacetomonitor "$ws" "$mon" &>/dev/null
    done
    unset MOVED["$mon"]
    write_state
    notify-send "Monitor: $mon connected" "Workspaces restored" -a "Hyprland"
}

# Restore hyprgamma config for this monitor if it was previously saved
restore_gamma() {
    local mon="$1"
    local cfg="$HOME/.config/hypr/hyprgamma.json"
    [[ -f "$cfg" ]] && hyprctl hyprgamma:reload &>/dev/null
}

# ── Event loop ───────────────────────────────────────────────────────

read_state
write_state

socat -u "UNIX-CONNECT:$SOCKET" - 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" == monitorremoved'>>'* ]]; then
        mon="${line#*'>>'}"
        echo "[$(date +%H:%M:%S)] removed: $mon"
        is_disabled "$mon" && continue
        evacuate "$mon"
        restore_gamma "$mon"
    elif [[ "$line" == monitoradded'>>'* ]]; then
        mon="${line#*'>>'}"
        echo "[$(date +%H:%M:%S)] added: $mon"
            if is_disabled "$mon"; then
                hyprctl eval "hl.monitor({ output = \"$mon\", disabled = true })" &>/dev/null
                write_state
                notify-send "Monitor: $mon reconnected" "Re-disabled (in disabled list)" -a "Hyprland"
                continue
            fi
        sleep 0.5
        restore "$mon"
        restore_gamma "$mon"
    fi
done

rm -f "$PID_FILE"
