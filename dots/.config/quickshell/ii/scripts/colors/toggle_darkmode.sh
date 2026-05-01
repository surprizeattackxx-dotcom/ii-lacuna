#!/usr/bin/env bash

# Toggle or set dark/light mode - syncs all KDE Plasma apps to the active mode
# Usage: toggle_darkmode.sh [dark|light]

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"

# Determine the target mode
if [[ -n "$1" && "$1" =~ ^(dark|light)$ ]]; then
    mode="$1"
else
    # If no argument, toggle current mode
    current_theme=$(kreadconfig5 --file kdeglobals --group General --key ColorScheme)
    if [[ "$current_theme" == *"Dark"* ]]; then
        mode="light"
    else
        mode="dark"
    fi
fi

# ============================================================================
# KDE Plasma Theme Settings
# ============================================================================
if [[ "$mode" == "dark" ]]; then
    # Set Plasma theme (ColloidDark - no hyphen!)
    kwriteconfig5 --file kdeglobals --group General --key ColorScheme "ColloidDark"
    kwriteconfig5 --file kdeglobals --group General --key PlasmaTheme "default"
else
    # Set Plasma theme (ColloidLight - no hyphen!)
    kwriteconfig5 --file kdeglobals --group General --key ColorScheme "ColloidLight"
    kwriteconfig5 --file kdeglobals --group General --key PlasmaTheme "default"
fi

# Broadcast kdeglobals change to all KDE apps
dbus-send --session --noreply --print-reply /KGlobalSettings org.kde.KGlobalSettings.notifyChange 4 0 2>/dev/null || true

# ============================================================================
# VS Code / Cursor Editor Themes
# ============================================================================
update_code_theme() {
    local code_config="$1"
    local target_theme="$2"
    
    if [[ -f "$code_config" ]]; then
        jq --arg theme "$target_theme" '.["workbench.colorTheme"] = $theme' "$code_config" > "$code_config.tmp" && mv "$code_config.tmp" "$code_config"
    fi
}

# Determine color theme names based on mode
if [[ "$mode" == "dark" ]]; then
    CODE_THEME="Colloid Dark"
else
    CODE_THEME="Colloid Light"
fi

# Update Cursor settings
[[ -f "$XDG_CONFIG_HOME/Cursor/User/settings.json" ]] && update_code_theme "$XDG_CONFIG_HOME/Cursor/User/settings.json" "$CODE_THEME"

# Update VS Code settings (if installed)
[[ -f "$XDG_CONFIG_HOME/Code/User/settings.json" ]] && update_code_theme "$XDG_CONFIG_HOME/Code/User/settings.json" "$CODE_THEME"

# ============================================================================
# Illogical Impulse Shell Config
# ============================================================================
if [[ -f "$SHELL_CONFIG_FILE" ]]; then
    jq --arg m "$mode" '.appearance.colorMode = $m' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    
    # Re-apply colors with the new mode (palette-only, no wallpaper switch)
    color_source=$(jq -r '.background.thumbnailPath // .background.wallpaperPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null)
    if [[ -n "$color_source" && -f "$color_source" ]]; then
        bash "$SCRIPT_DIR/switchwall.sh" --noswitch --mode "$mode" "$color_source" 2>/dev/null &
    fi
fi

# ============================================================================
# Reload Terminal (kitty) Theme
# ============================================================================
if command -v kitty &>/dev/null; then
    pkill -USR1 kitty 2>/dev/null || true
fi

# ============================================================================
# Restart KDE Plasma Shell to apply changes
# ============================================================================
# This ensures all running KDE apps pick up the theme change
sleep 0.5
kquitapp5 plasmashell 2>/dev/null
sleep 1
kstart5 plasmashell > /dev/null 2>&1 &

# ============================================================================
# Notify user
# ============================================================================
notify-send -i "preferences-system-display" "Theme Updated" "Switched to $mode mode (Colloid)" 2>/dev/null || true
