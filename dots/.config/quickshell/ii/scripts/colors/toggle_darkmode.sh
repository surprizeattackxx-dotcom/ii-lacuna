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
else
    color_scheme="MaterialYouLight"
fi

# Set the color scheme
kwriteconfig5 --file kdeglobals --group General --key ColorScheme "$color_scheme"

# Generate the Material You scheme from current wallpaper
generate_material_you_scheme "$mode"

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
sleep 1
kquitapp5 plasmashell 2>/dev/null
sleep 1
kstart5 plasmashell > /dev/null 2>&1 &

# ============================================================================
# Notify user
# ============================================================================
notify-send -i "preferences-system-display" "Theme Updated" "Switched to $mode mode (Material You)" 2>/dev/null || true
