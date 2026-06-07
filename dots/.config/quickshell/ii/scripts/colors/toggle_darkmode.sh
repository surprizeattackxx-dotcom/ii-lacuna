#!/usr/bin/env bash

# Toggle or set dark/light mode - syncs all KDE Plasma apps to Material You colors
# Usage: toggle_darkmode.sh [dark|light]

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
# Monitor whose wallpaper drives matugen theming. Override with the env var;
# otherwise prefer DP-1, then the focused monitor, then the first connected one.
PREFERRED_MATUGEN_MONITOR="${PREFERRED_MATUGEN_MONITOR:-$(hyprctl monitors -j 2>/dev/null | jq -r '
    (.[] | select(.name == "DP-1") | .name),
    ([.[] | select(.focused == true) | .name][0]),
    (.[0].name)' 2>/dev/null | grep -v '^null$' | head -n1)}"
[ -z "$PREFERRED_MATUGEN_MONITOR" ] && PREFERRED_MATUGEN_MONITOR="DP-1"

# Expand ~ in venv path (bash doesn't expand ~ inside variables)
II_VENV="${ILLOGICAL_IMPULSE_VIRTUAL_ENV/#\~/$HOME}"

get_monitor_state_path() {
    local monitor="$1"
    local state_file="$XDG_STATE_HOME/quickshell/user/generated/wallpaper/monitors/${monitor}.json"
    [[ -f "$state_file" ]] || return
    jq -r '.matugenPath // .thumbnailPath // .previewPath // .path // empty' "$state_file" 2>/dev/null || true
}

resolve_color_source() {
    local source_path=""
    source_path="$(get_monitor_state_path "$PREFERRED_MATUGEN_MONITOR")"
    if [[ -n "$source_path" && -f "$source_path" ]]; then
        printf '%s\n' "$source_path"
        return
    fi

    jq -r '.background.thumbnailPath // .background.wallpaperPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null || true
}

silent_flag=""
for _arg in "$@"; do [[ "$_arg" == "--silent" ]] && silent_flag="1"; done

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
    if [[ -n "$II_VENV" ]]; then
        source "$II_VENV/bin/activate" 2>/dev/null || true
        
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
    color_scheme="ColloidDarkGruvbox"
    # Also set gsettings for compatibility with applycolor.sh (which reads gsettings)
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
else
    color_scheme="colloidLightGruvbox"
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
fi

# Set the KDE color scheme
kwriteconfig5 --file kdeglobals --group General --key ColorScheme "$color_scheme"

# ============================================================================
# Read active theme from states.json — if a preset is active, re-apply it
# instead of regenerating from wallpaper (which would overwrite it).
# ============================================================================
ACTIVE_THEME="Matugen"
STATE_FILE="$XDG_STATE_HOME/quickshell/states.json"
[[ -f "$STATE_FILE" ]] && ACTIVE_THEME=$(jq -r '.activeTheme // "Matugen"' "$STATE_FILE" 2>/dev/null || echo "Matugen")

if [[ "$ACTIVE_THEME" != "Matugen" ]]; then
    # Re-apply the preset theme — keeps colors.json in sync, applies KDE scheme, etc.
    THEME_FILE="$(dirname "$SCRIPT_DIR")/defaults/themes/${ACTIVE_THEME,,}.json"
    if [[ -f "$THEME_FILE" ]]; then
        bash "$SCRIPT_DIR/apply_custom_theme.sh" "$THEME_FILE" "$ACTIVE_THEME"
        # apply_custom_theme.sh auto-detects dark/light from theme colors,
        # so re-override config + gsettings with the intended mode
        jq --arg m "$mode" '.appearance.colorMode = $m' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
        if [[ "$mode" == "dark" ]]; then
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        else
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
        fi
        # Notify quickshell to reload the theme (colors.json was updated by apply_custom_theme.sh)
        qs -c ii ipc call theme reload 2>/dev/null || true
    fi
else
    # Matugen active — regenerate from wallpaper (original behavior)
    generate_material_you_scheme "$mode"

    if [[ -f "$SHELL_CONFIG_FILE" ]]; then
        jq --arg m "$mode" '.appearance.colorMode = $m' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
        
        # Regenerate material colors with correct mode flag
        (
            color_source="$(resolve_color_source)"
            if [[ -n "$color_source" && -f "$color_source" ]]; then
                terminalscheme="$SCRIPT_DIR/terminal/scheme-base.json"

                # Regenerate material colors from wallpaper with correct mode
                source "$II_VENV/bin/activate" 2>/dev/null || true
                python3 "$SCRIPT_DIR/generate_colors_material.py" \
                    --mode "$mode" \
                    --path "$color_source" \
                    --termscheme "$terminalscheme" \
                    --blend_bg_fg \
                    --cache "$XDG_STATE_HOME/quickshell/user/generated/color.txt" \
                    --json-out "$XDG_STATE_HOME/quickshell/user/generated/colors.json" \
                    > "$XDG_STATE_HOME/quickshell/user/generated/material_colors.scss" 2>/dev/null || true
                deactivate 2>/dev/null || true
            fi
            
            # Now apply the regenerated colors to all apps
            bash "$SCRIPT_DIR/applycolor.sh" 2>/dev/null
            
            # Notify quickshell to reload the theme
            qs -c ii ipc call theme reload 2>/dev/null || true
        ) &
    fi
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
[[ -z "$silent_flag" ]] && notify-send -i "preferences-system-display" "Theme Updated" "Switched to $mode mode" 2>/dev/null || true
