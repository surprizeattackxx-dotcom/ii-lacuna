#!/bin/bash
TV="HDMI-A-1"
MONITORS_LUA="$HOME/.config/hypr/monitors.lua"
DISABLED_MONITORS_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/wallpaper/monitors_disabled.txt"

if hyprctl monitors all -j | jq -e ".[] | select(.name == \"$TV\") | select(.disabled == false)" > /dev/null 2>&1; then
    # TV is currently enabled — disable it
    perl -0777 -i -pe 's/(hl\.monitor\(\{[^}]*?output = "HDMI-A-1"[^}]*?disabled = )false/$1true/s' "$MONITORS_LUA"
    grep -qxF "$TV" "$DISABLED_MONITORS_FILE" 2>/dev/null || echo "$TV" >> "$DISABLED_MONITORS_FILE"
    hyprctl eval "hl.monitor({ output = \"$TV\", disabled = true })"
    notify-send "TV Disabled" -a "Hyprland"
else
    # TV is currently disabled — enable it
    sed -i "/^${TV}$/d" "$DISABLED_MONITORS_FILE" 2>/dev/null || true
    perl -0777 -i -pe 's/(hl\.monitor\(\{[^}]*?output = "HDMI-A-1"[^}]*?disabled = )true/$1false/s' "$MONITORS_LUA"
    hyprctl eval "hl.monitor({ output = \"$TV\", disabled = false })"
    notify-send "TV Enabled" -a "Hyprland"
fi
