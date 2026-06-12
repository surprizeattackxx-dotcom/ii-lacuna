#!/usr/bin/env bash

# ============================================================================
# 1. ZOMBIE PREVENTION
# Kills any older instances of this script. When Quickshell reloads, 
# it can leave the old listener pipelines running in the background infinitely.
# ============================================================================
for pid in $(pgrep -f "quickshell/workspaces.sh"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

# Cleanly kill immediate children (like socat) when the script exits normally
cleanup() {
    pkill -P $$ 2>/dev/null
}
trap cleanup EXIT SIGTERM SIGINT

# --- Special Cleanup for Network/Bluetooth ---
# The network toggle starts a background bluetooth scan that must be killed explicitly.
BT_PID_FILE="$HOME/.cache/bt_scan_pid"

if [ -f "$BT_PID_FILE" ]; then
    kill $(cat "$BT_PID_FILE") 2>/dev/null
    rm -f "$BT_PID_FILE"
fi

# Ensure bluetooth scan is explicitly turned off (timeout prevents deadlocks on fresh installs)
(timeout 2 bluetoothctl scan off > /dev/null 2>&1) &
# ---------------------------------------------

# Fallback workspace count when no monitor-bound workspace rules exist
SEQ_END=8

print_workspaces() {
    # Get raw data with a timeout fallback
    spaces=$(timeout 2 hyprctl workspaces -j 2>/dev/null)
    monitors=$(timeout 2 hyprctl monitors -j 2>/dev/null)
    rules=$(timeout 2 hyprctl workspacerules -j 2>/dev/null)

    # Failsafe if hyprctl crashes to prevent jq from outputting errors
    if [ -z "$spaces" ] || [ -z "$monitors" ]; then return; fi

    # Monitor-bound rules (workspaces.lua blocks) drive the list; each entry
    # carries its monitor so per-screen bars can filter. Active is per-monitor.
    # Falls back to a flat 1..SEQ_END list when no rules bind monitors.
    jq -n --unbuffered -c \
        --argjson s "$spaces" --argjson m "$monitors" \
        --argjson r "${rules:-[]}" --arg end "$SEQ_END" '
        ($s | map({ (.id|tostring): . }) | add // {}) as $sp |
        ($m | map({ (.name): .activeWorkspace.id }) | add // {}) as $act |
        [ $r[] | select(has("monitor") and (.workspaceString | test("^[0-9]+$")))
              | { id: (.workspaceString | tonumber), monitor: .monitor } ] as $bound |
        (if ($bound | length) > 0
         then $bound
         else [range(1; ($end|tonumber) + 1)] | map({ id: ., monitor: "" })
         end)
        | sort_by(.id) | map(
            . as $w |
            (if ($act[$w.monitor] // ($m[0].activeWorkspace.id)) == $w.id then "active"
             elif ($sp[$w.id|tostring] != null and $sp[$w.id|tostring].windows > 0) then "occupied"
             else "empty" end) as $state |
            (if $sp[$w.id|tostring] != null then $sp[$w.id|tostring].lastwindowtitle else "Empty" end) as $win |
            { id: $w.id, monitor: $w.monitor, state: $state, tooltip: $win }
        )
    ' > /tmp/qs_workspaces.tmp

    mv /tmp/qs_workspaces.tmp /tmp/qs_workspaces.json
}

# Print initial state
print_workspaces

# ============================================================================
# 2. THE EVENT DEBOUNCER
# Listen to Hyprland socket wrapped in an infinite loop
# ============================================================================
while true; do
    socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r line; do
        case "$line" in
            workspace*|focusedmon*|activewindow*|createwindow*|closewindow*|movewindow*|destroyworkspace*)
                
                # -> THE FIX <-
                # Hyprland emits HUNDREDS of events a second when you move/resize windows.
                # This reads and discards all subsequent events arriving within a 50ms window.
                # It bundles the storm into a single UI update, completely preventing CPU clogging!
                while read -t 0.05 -r extra_line; do
                    continue
                done

                print_workspaces
                ;;
        esac
    done
    sleep 1
done
