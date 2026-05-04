#!/bin/bash
TV="HDMI-A-1"
TV_CONFIG="3840x2160@60.0,3840x0,1.0,bitdepth,10"
DISABLED_MONITORS_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/wallpaper/monitors_disabled.txt"
MONITOR_OVERRIDES_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitor-overrides.conf"

if hyprctl monitors -j | jq -e ".[] | select(.name == \"$TV\")" > /dev/null 2>&1; then
    # Persist the disabled state so hyprctl keyword calls don't re-enable the TV
    sed -i "/^monitor=$TV/d" "$MONITOR_OVERRIDES_CONF" 2>/dev/null || true
    echo "monitor=$TV,disabled" >> "$MONITOR_OVERRIDES_CONF"
    hyprctl keyword monitor "$TV,disabled"
    notify-send "TV Disabled" -a "Hyprland"
else
    # Remove from disabled list BEFORE re-enabling so monitor-watch.sh allows the re-add
    sed -i "/^${TV}$/d" "$DISABLED_MONITORS_FILE" 2>/dev/null || true
    # Remove the override so the TV stays enabled across reloads
    sed -i "/^monitor=$TV/d" "$MONITOR_OVERRIDES_CONF" 2>/dev/null || true
    hyprctl keyword monitor "$TV,$TV_CONFIG"
    notify-send "TV Enabled" -a "Hyprland"
fi
