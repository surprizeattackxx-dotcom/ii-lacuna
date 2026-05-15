#!/usr/bin/env bash

STATE_DIR="$HOME/.local/state/quickshell"
MONITOR_STATE_DIR="$STATE_DIR/user/generated/wallpaper/monitors"

# Stop all WPE services
systemctl --user stop "wpe@*.service" wpe-combined.service 2>/dev/null || true

# Update monitor state files to mark them as NOT WPE
if [[ -d "$MONITOR_STATE_DIR" ]]; then
    for state_file in "$MONITOR_STATE_DIR"/*.json; do
        [[ -f "$state_file" ]] || continue
        # Update kind to image and remove wpe related fields
        jq '.kind = "image" | del(.wpe) | del(.wpe_id) | del(.wpe_path)' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
    done
fi

# Ensure awww-daemon is running to show the static wallpaper
if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon >/dev/null 2>&1 &
    sleep 0.2
fi

# Restore static wallpaper via awww
awww restore 2>/dev/null || true

notify-send "Wallpaper" "WPE stopped, static wallpaper restored and state updated." -a "Wallpaper switcher"
