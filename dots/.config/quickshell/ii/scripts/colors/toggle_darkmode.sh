#!/usr/bin/env bash

# Toggle or set dark/light mode
# Usage: toggle_darkmode.sh [dark|light]

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"

# Determine the target mode
if [[ -n "$1" && "$1" =~ ^(dark|light)$ ]]; then
    mode="$1"
else
    # If no argument, toggle current mode
    current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
    if [[ "$current_mode" == "prefer-dark" ]]; then
        mode="light"
    else
        mode="dark"
    fi
fi

# Set GNOME color-scheme
if [[ "$mode" == "dark" ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' 2>/dev/null
fi

# Re-apply colors with the new mode (palette-only, no wallpaper switch)
if [[ -f "$SHELL_CONFIG_FILE" ]]; then
    wallpaper_path=$(jq -r '.background.wallpaperPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null)
    if [[ -n "$wallpaper_path" && -f "$wallpaper_path" ]]; then
        bash "$SCRIPT_DIR/switchwall.sh" --noswitch --mode "$mode" "$wallpaper_path" 2>/dev/null
    fi
fi
