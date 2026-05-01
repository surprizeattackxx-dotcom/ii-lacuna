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
    if [[ "$current_theme" == *"dark"* ]] || [[ "$current_theme" == *"Dark"* ]]; then
        mode="light"
    else
        mode="dark"
    fi
fi

# ============================================================================
# KDE Plasma Theme Settings
# ============================================================================
if [[ "$mode" == "dark" ]]; then
    # Set Plasma theme (colloid-dark)
    kwriteconfig5 --file kdeglobals --group General --key ColorScheme "Colloid-Dark"
    kwriteconfig5 --file kdeglobals --group General --key PlasmaTheme "Colloid-Dark"
    kwriteconfig5 --file kdeglobals --group General --key widgetStyle "Colloid-Dark"
    
    # KDE app theme settings
    kwriteconfig5 --file kdeglobals --group General --key kde-settings-apply-on-launch true
else
    # Set Plasma theme (colloid-light)
    kwriteconfig5 --file kdeglobals --group General --key ColorScheme "Colloid-Light"
    kwriteconfig5 --file kdeglobals --group General --key PlasmaTheme "Colloid-Light"
    kwriteconfig5 --file kdeglobals --group General --key widgetStyle "Colloid-Light"
    
    # KDE app theme settings
    kwriteconfig5 --file kdeglobals --group General --key kde-settings-apply-on-launch true
fi

# Signal KDE to reload settings
dbus-send --print-reply --dest=org.kde.KWin /KWin org.kde.KWin.reloadConfig 2>/dev/null || true
kquitapp5 plasmashell 2>/dev/null || true
kstart5 plasmashell 2>/dev/null || true

# ============================================================================
# VS Code / Cursor Editor Themes
# ============================================================================
update_code_theme() {
    local code_config="$1"
    local target_theme="$2"
    
    if [[ -f "$code_config" ]]; then
        # Update workbench color theme
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
    # Update config.json to reflect the new mode so QML picks it up
    jq --arg m "$mode" '.appearance.colorMode = $m' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"

    # Re-apply colors with the new mode (palette-only, no wallpaper switch)
    # This regenerates all color files including kitty terminal theme
    # Prefer thumbnail for WPE wallpapers, fall back to wallpaper path
    color_source=$(jq -r '.background.thumbnailPath // .background.wallpaperPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null)
    if [[ -n "$color_source" && -f "$color_source" ]]; then
        bash "$SCRIPT_DIR/switchwall.sh" --noswitch --mode "$mode" "$color_source" 2>/dev/null &
    fi
fi

# ============================================================================
# Reload Terminal (kitty) Theme
# ============================================================================
if command -v kitty &>/dev/null; then
    # Send SIGUSR1 to all kitty instances to reload theme
    pkill -USR1 kitty 2>/dev/null || true
fi

# ============================================================================
# Notify user
# ============================================================================
notify-send -i "preferences-system-display" "Theme Updated" "Switched to $mode mode (Colloid)" 2>/dev/null || true
