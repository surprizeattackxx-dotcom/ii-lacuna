#!/usr/bin/env bash

# Toggle or set dark/light mode - syncs all KDE Plasma apps to Material You colors
# Usage: toggle_darkmode.sh [dark|light]

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
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
# Generate Material You KDE color scheme based on current wallpaper
# ============================================================================
generate_material_you_scheme() {
    local target_mode="$1"
    local color_file="$XDG_STATE_HOME/quickshell/user/generated/color.txt"
    
    if [[ ! -f "$color_file" ]]; then
        return
    fi
    
    local color=$(cat "$color_file")
    
    # Activate venv and run kde-material-you-colors to generate the color scheme
    if [[ -n "$ILLOGICAL_IMPULSE_VIRTUAL_ENV" ]]; then
        source "$(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate" 2>/dev/null || true
        
        if [[ "$target_mode" == "dark" ]]; then
            kde-material-you-colors -d --color "$color" 2>/dev/null &
        else
            kde-material-you-colors -l --color "$color" 2>/dev/null &
        fi
        
        deactivate 2>/dev/null || true
    fi
}

# ============================================================================
# Apply Material You color scheme via KDE
# ============================================================================
if [[ "$mode" == "dark" ]]; then
    color_scheme="MaterialYouDark"
    # Also set gsettings for compatibility with applycolor.sh (which reads gsettings)
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
else
    color_scheme="MaterialYouLight"
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
fi

# Set the KDE color scheme
kwriteconfig5 --file kdeglobals --group General --key ColorScheme "$color_scheme"

# Generate the Material You scheme from current wallpaper
generate_material_you_scheme "$mode"

# ============================================================================
# Illogical Impulse Shell Config & Regenerate Colors
# ============================================================================
if [[ -f "$SHELL_CONFIG_FILE" ]]; then
    jq --arg m "$mode" '.appearance.colorMode = $m' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    
    # Regenerate material colors with correct mode flag
    (
        color_source=$(jq -r '.background.thumbnailPath // .background.wallpaperPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null)
        if [[ -n "$color_source" && -f "$color_source" ]]; then
            # Use mode_flag that matches the color generation mode
            mode_flag=""
            [[ "$mode" == "dark" ]] && mode_flag="-d" || mode_flag="-l"
            
            # Regenerate material colors from wallpaper with correct mode
            source "$(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate" 2>/dev/null || true
            python3 "$SCRIPT_DIR/generate_colors_material.py" $mode_flag --path "$color_source" \
                > "$XDG_STATE_HOME/quickshell/user/generated/material_colors.scss" 2>/dev/null || true
            deactivate 2>/dev/null || true
        fi
        
        # Now apply the regenerated colors to all apps
        bash "$SCRIPT_DIR/applycolor.sh" 2>/dev/null
    ) &
fi

# ============================================================================
# Delayed Plasmashell Restart
# ============================================================================
(
    sleep 2
    kquitapp5 plasmashell 2>/dev/null
    sleep 1
    kstart5 plasmashell > /dev/null 2>&1
) &

# ============================================================================
# Notify user
# ============================================================================
notify-send -i "preferences-system-display" "Theme Updated" "Switched to $mode mode (Material You)" 2>/dev/null || true
