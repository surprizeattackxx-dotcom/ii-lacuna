#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
MATERIAL_COLORS_FILE="$STATE_DIR/user/generated/material_colors.scss"

term_alpha=75  # Set to < 100 to make terminals transparent

# Ensure generated dir exists
mkdir -p "$STATE_DIR/user/generated"

# Verify the color file exists and is non-empty before proceeding
if [[ ! -f "$MATERIAL_COLORS_FILE" || ! -s "$MATERIAL_COLORS_FILE" ]]; then
    echo "[applycolor] Error: $MATERIAL_COLORS_FILE not found or empty. Aborting." >&2
    exit 1
fi

# Parse color names and hex values from the SCSS file.
# Format is: $name: #RRGGBB;
# colorlist   = array of "$name" (with the dollar sign)
# colorvalues = array of "#RRGGBB"
declare -a colorlist=()
declare -a colorvalues=()

while IFS= read -r line; do
    # Match lines like:  $primary: #1A2B3C;
    if [[ "$line" =~ ^\$([A-Za-z_][A-Za-z0-9_]*):[[:space:]]*(#[0-9A-Fa-f]{6})\; ]]; then
        colorlist+=("\$${BASH_REMATCH[1]}")
        colorvalues+=("${BASH_REMATCH[2]}")
    fi
done < "$MATERIAL_COLORS_FILE"

if [[ ${#colorlist[@]} -eq 0 ]]; then
    echo "[applycolor] Error: No colors parsed from $MATERIAL_COLORS_FILE." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Terminal theming
# ---------------------------------------------------------------------------
apply_term() {
    local template="$SCRIPT_DIR/terminal/sequences.txt"
    if [[ ! -f "$template" ]]; then
        echo "[applycolor] Terminal template not found at $template. Skipping." >&2
        return 0
    fi

    mkdir -p "$STATE_DIR/user/generated/terminal"
    local dest="$STATE_DIR/user/generated/terminal/sequences.txt"
    cp "$template" "$dest"

    # Apply all color substitutions. The template uses the pattern:
    #   $colorname #  (space before hash is the placeholder marker)
    # We replace that with just the hex digits (no # prefix).
    # Done in a single sed call for speed.
    local sed_expr=""
    for i in "${!colorlist[@]}"; do
        local name="${colorlist[$i]}"      # e.g.  $primary
        local val="${colorvalues[$i]#\#}"  # strip leading #  →  1A2B3C

        # Escape the $ so sed treats it literally
        local escaped_name="${name//\$/\\$}"

        sed_expr+="s/${escaped_name} #/${val}/g;"
    done
    sed_expr+="s/\$alpha/$term_alpha/g"

    sed -i "$sed_expr" "$dest"
    # Convert literal \e and \\ notation to actual ESC bytes so terminals interpret them
    printf '%b' "$(cat "$dest")" > "${dest}.tmp" && mv "${dest}.tmp" "$dest"

    # Known terminal emulators we want to push sequences to.
    # kitty is excluded — apply_kitty() handles it cleanly via remote control.
    local -A _term_emus=([foot]=1 [footclient]=1 [alacritty]=1 [wezterm-gui]=1
        [xterm]=1 [urxvt]=1 [st]=1 [konsole]=1 [gnome-terminal]=1 [tilix]=1)

    # Map pts number → whether the session leader is a known terminal emulator
    declare -A _good_pts
    while IFS= read -r line; do
        local pid tty comm
        pid="${line%% *}"; tty="${line##* }"
        [[ "$tty" =~ pts/([0-9]+) ]] || continue
        comm=$(cat "/proc/$pid/comm" 2>/dev/null) || continue
        [[ "${_term_emus[$comm]+_}" ]] && _good_pts["${BASH_REMATCH[1]}"]=1
    done < <(ps -eo pid=,tty= 2>/dev/null)

    # Push sequences only to PTYs owned by known terminal emulators that we can write to
    local pushed=0
    for pts_num in "${!_good_pts[@]}"; do
        local file="/dev/pts/$pts_num"
        [[ -w "$file" ]] || continue
        { cat "$dest" > "$file"; } 2>/dev/null & disown $! 2>/dev/null || true
        (( pushed++ )) || true
    done

    if [[ $pushed -eq 0 ]]; then
        echo "[applycolor] No writable PTYs found — terminal colors not pushed." >&2
    fi
}

# ---------------------------------------------------------------------------
# Qt theming (disabled — handled by kde-material-colors)
# ---------------------------------------------------------------------------
apply_qt() {
    sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"
    python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py"
}

# ---------------------------------------------------------------------------
# Hyprland border colors — applied live via hyprctl, no restart needed
# Uses:
#   active border   → $primary (with a $primaryContainer glow gradient)
#   inactive border → $surfaceVariant (subtle, low contrast)
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Hyprland border + extra visuals — applied live via hyprctl AND written
# to ~/.config/hypr/material-colors.conf so they survive reboots.
# Add this line to your hyprland.conf:
#   source = ~/.config/hypr/material-colors.conf
# ---------------------------------------------------------------------------

# Helper used by both apply_borders and apply_hypr_extras — writes the
# persistent Hyprland config file once all colors are known.
_write_hypr_colors_conf() {
    local col_active_1="$1"
    local col_active_2="$2"
    local col_inactive="$3"
    local shadow_col="$4"
    local shadow_inactive="$5"
    local group_active="$6"
    local group_inactive="$7"
    local surface="$8"

    # Written as Lua because hyprland.lua loads it via dofile() ("must be last to win").
    # The old material-colors.conf was never sourced by the Lua config — dead file.
    local hypr_colors_file="$HOME/.config/hypr/hyprland/colors.lua"
    mkdir -p "$(dirname "$hypr_colors_file")"
    local _pri="${col_active_1#0xff}"

    local _tmp="${hypr_colors_file}.tmp.$$"
    cat > "$_tmp" << HYPREOF
-- Generated by applycolor.sh — do not edit. Loaded by hyprland.lua (dofile, last to win).
-- Persists colors across reloads to match the live hyprctl state. Border *visibility*
-- is controlled separately (disableHyprlandBorders), so this only sets colors.
hl.config({
    ['general.col.active_border']        = { colors = {'${col_active_1}', '${col_active_2}'}, angle = 45 },
    ['general.col.inactive_border']      = '${col_inactive}',
    ['decoration.shadow.color']          = '${shadow_col}',
    ['decoration.shadow.color_inactive'] = '${shadow_inactive}',
    ['group.col.border_active']          = '${group_active}',
    ['group.col.border_inactive']        = '${group_inactive}',
    ['group.col.border_locked_active']   = '${group_active}',
    ['group.col.border_locked_inactive'] = '${group_inactive}',
    ['misc.background_color']            = '0xff${surface#\#}',
})

hl.window_rule({
    match        = { pin = 1 },
    border_color = '0xAA${_pri} 0x77${_pri}',
})
HYPREOF
    # Suppress Hyprland's inotify auto-reload while writing — the live colors
    # are already applied via hyprctl keyword, so we only need the file for
    # persistence across reboots.  Without this guard, every write triggers a
    # full config reload which re-applies monitors.conf and resets resolution.
    if command -v hyprctl &>/dev/null; then
        hyprctl eval "hl.config({ misc = { disable_autoreload = true } })" 2>/dev/null
    fi
    mv "$_tmp" "$hypr_colors_file"
    echo "[applycolor] Hyprland colors written to $hypr_colors_file"
    if command -v hyprctl &>/dev/null; then
        hyprctl eval "hl.config({ misc = { disable_autoreload = false } })" 2>/dev/null
    fi
}

apply_borders() {
    if ! command -v hyprctl &>/dev/null; then
        echo "[applycolor] hyprctl not found — skipping border theming." >&2
        return 0
    fi

    local primary="" primary_container="" surface_variant="" scrim="" surface=""
    for i in "${!colorlist[@]}"; do
        case "${colorlist[$i]}" in
            '$primary')          primary="${colorvalues[$i]}"          ;;
            '$primaryContainer') primary_container="${colorvalues[$i]}" ;;
            '$surfaceVariant')   surface_variant="${colorvalues[$i]}"  ;;
            '$scrim')            scrim="${colorvalues[$i]}"            ;;
            '$surface')             surface="${colorvalues[$i]}"             ;;
        esac
    done

    primary="${primary:-#8aadf4}"
    primary_container="${primary_container:-#6e8fd4}"
    surface_variant="${surface_variant:-#45475a}"
    scrim="${scrim:-#000000}"
    surface="${surface:-#000000}"

    # Hyprland color format: 0xAARRGGBB
    local col_active_1="0xff${primary#\#}"
    local col_active_2="0xff${primary_container#\#}"
    local col_inactive="0xff${surface_variant#\#}"
    local shadow_col="0x88${primary#\#}"
    local shadow_inactive="0x44${scrim#\#}"
    local group_active="0xff${primary#\#}"
    local group_inactive="0xff${surface_variant#\#}"

    # Apply live (takes effect immediately)
    hyprctl eval "hl.config({ ['general.col.active_border'] = { colors = {'${col_active_1}', '${col_active_2}'}, angle = 45 } })" 2>/dev/null
    hyprctl eval "hl.config({ ['general.col.inactive_border'] = '${col_inactive}' })" 2>/dev/null
    hyprctl eval "hl.config({ ['decoration.shadow.color'] = '${shadow_col}' })" 2>/dev/null
    hyprctl eval "hl.config({ ['decoration.shadow.color_inactive'] = '${shadow_inactive}' })" 2>/dev/null
    hyprctl eval "hl.config({ ['group.col.border_active'] = '${group_active}' })" 2>/dev/null
    hyprctl eval "hl.config({ ['group.col.border_inactive'] = '${group_inactive}' })" 2>/dev/null
    hyprctl eval "hl.config({ ['group.col.border_locked_active'] = '${group_active}' })" 2>/dev/null
    hyprctl eval "hl.config({ ['group.col.border_locked_inactive'] = '${group_inactive}' })" 2>/dev/null

    # Write persistent config so colors survive reboots
    _write_hypr_colors_conf         "$col_active_1" "$col_active_2" "$col_inactive"         "$shadow_col" "$shadow_inactive"         "$group_active" "$group_inactive" "$surface"
}

# ---------------------------------------------------------------------------
# hyprlock — colors.conf is sourced by hyprlock.conf. Was matugen-only, so the
# lock screen drifted off-theme on custom schemes. Now generated here too.
# ---------------------------------------------------------------------------
apply_hyprlock() {
    [[ -f "$HOME/.config/hypr/hyprlock.conf" ]] || return 0
    local lock_dir="$HOME/.config/hypr/hyprlock"
    mkdir -p "$lock_dir"

    local primary="" on_primary="" primary_fixed="" on_primary_fixed=""
    local outline="" inverse_surface="" inverse_on_surface=""
    local on_primary_container="" primary_container=""
    for i in "${!colorlist[@]}"; do
        case "${colorlist[$i]}" in
            '$primary')             primary="${colorvalues[$i]}"              ;;
            '$onPrimary')           on_primary="${colorvalues[$i]}"           ;;
            '$primaryFixed')        primary_fixed="${colorvalues[$i]}"        ;;
            '$onPrimaryFixed')      on_primary_fixed="${colorvalues[$i]}"     ;;
            '$outline')             outline="${colorvalues[$i]}"             ;;
            '$inverseSurface')      inverse_surface="${colorvalues[$i]}"      ;;
            '$inverseOnSurface')    inverse_on_surface="${colorvalues[$i]}"   ;;
            '$onPrimaryContainer')  on_primary_container="${colorvalues[$i]}" ;;
            '$primaryContainer')    primary_container="${colorvalues[$i]}"    ;;
        esac
    done
    primary_fixed="${primary_fixed:-$primary}"
    on_primary_fixed="${on_primary_fixed:-$on_primary}"

    local wp; wp=$(cat "$STATE_DIR/user/generated/wallpaper/path.txt" 2>/dev/null)
    [[ -z "$wp" ]] && wp=$(jq -r '.background.wallpaperPath // empty' "$CONFIG_FILE" 2>/dev/null)

    cat > "$lock_dir/colors.conf" << LOCKEOF
# Generated by applycolor.sh — tracks the active scheme (custom or wallpaper).

\$text_color = rgba(${primary_fixed#\#}FF)
\$entry_background_color = rgba(${on_primary_fixed#\#}11)
\$entry_border_color = rgba(${outline#\#}55)
\$entry_color = rgba(${primary_fixed#\#}FF)
\$font_family = Google Sans Flex Medium
\$font_family_clock = Google Sans Flex Medium
\$font_material_symbols = Material Symbols Rounded

# Required by hyprlock.conf (multi-monitor / M3 labels) — do not omit or hyprlock will error
\$inverse_surface = rgba(${inverse_surface#\#}FF)
\$inverse_on_surface = rgba(${inverse_on_surface#\#}FF)
\$on_primary_container = rgba(${on_primary_container#\#}FF)
\$primary_container = rgba(${primary_container#\#}FF)

# Double-quote Pango: unquoted values starting with < break hyprlang parsing.
\$hyprlock_input_placeholder = "<span font_family='Material Symbols Rounded' font_size='16000'></span><span font_family='Google Sans Flex Medium' font_size='13000'>  Password</span>"
\$hyprlock_user_icon = "<span font_family='Material Symbols Rounded' font_size='22000'></span>"
\$hyprlock_layout_prefix = "<span font_family='Material Symbols Rounded' font_size='14000'></span>"
\$hyprlock_check_text = "<span font_family='Material Symbols Rounded' font_size='13000'></span>"
\$hyprlock_fail_text = "<span font_family='Material Symbols Rounded' font_size='13000'></span> <i>\$FAIL</i> <b>(\$ATTEMPTS)</b>"

\$background_image = ${wp}
LOCKEOF
    echo "[applycolor] hyprlock colors written"
}

# ---------------------------------------------------------------------------
# hamr launcher — reads ~/.config/hamr/colors.json (same shape as the shell's
# generated colors.json). Was matugen-only; mirror the live scheme to it.
# ---------------------------------------------------------------------------
apply_hamr() {
    local hamr_dir="$HOME/.config/hamr"
    [[ -d "$hamr_dir" ]] || return 0
    cp "$STATE_DIR/user/generated/colors.json" "$hamr_dir/colors.json" 2>/dev/null \
        && echo "[applycolor] hamr colors written"
}

# ---------------------------------------------------------------------------
# GTK3 — gtk-3.0/gtk.css @define-color block. applycolor already does GTK4 via
# a separate colors.css; GTK3 has no auto-imported colors file, so we own gtk.css.
# ---------------------------------------------------------------------------
apply_gtk3() {
    local gtk3_dir="$HOME/.config/gtk-3.0"
    [[ -d "$gtk3_dir" ]] || return 0

    local primary="" on_primary="" error="" error_container="" on_error_container=""
    local background="" on_background="" surface_container="" on_surface=""
    local surface_container_low="" surface_container_lowest=""
    local surface_container_high="" surface_container_highest=""
    for i in "${!colorlist[@]}"; do
        case "${colorlist[$i]}" in
            '$primary')                  primary="${colorvalues[$i]}"                  ;;
            '$onPrimary')                on_primary="${colorvalues[$i]}"               ;;
            '$error')                    error="${colorvalues[$i]}"                    ;;
            '$errorContainer')           error_container="${colorvalues[$i]}"          ;;
            '$onErrorContainer')         on_error_container="${colorvalues[$i]}"       ;;
            '$background')               background="${colorvalues[$i]}"               ;;
            '$onBackground')             on_background="${colorvalues[$i]}"            ;;
            '$onSurface')                on_surface="${colorvalues[$i]}"               ;;
            '$surfaceContainer')         surface_container="${colorvalues[$i]}"        ;;
            '$surfaceContainerLow')      surface_container_low="${colorvalues[$i]}"    ;;
            '$surfaceContainerLowest')   surface_container_lowest="${colorvalues[$i]}" ;;
            '$surfaceContainerHigh')     surface_container_high="${colorvalues[$i]}"   ;;
            '$surfaceContainerHighest')  surface_container_highest="${colorvalues[$i]}";;
        esac
    done

    cat > "$gtk3_dir/gtk.css" << GTK3EOF
/*
* GTK colors generated by applycolor.sh — tracks the active scheme.
*/

/* Accents */
@define-color accent_color ${primary};
@define-color accent_fg_color ${on_primary};
@define-color accent_bg_color ${primary};
@define-color destructive_bg_color ${error_container};
@define-color destructive_fg_color ${on_error_container};
@define-color destructive_color ${error};
@define-color success_bg_color #374B3E;
@define-color success_fg_color #D1E9D6;
@define-color success_color #B5CCBA;
/* Base surfaces */
@define-color window_bg_color ${background};
@define-color window_fg_color ${on_background};
@define-color headerbar_bg_color ${surface_container};
@define-color headerbar_backdrop_color ${surface_container};
@define-color headerbar_fg_color ${on_surface};
@define-color card_bg_color ${surface_container};
@define-color card_fg_color ${on_surface};
@define-color sidebar_bg_color ${surface_container};
@define-color sidebar_fg_color ${on_surface};
@define-color secondary_sidebar_bg_color ${surface_container_low};
@define-color secondary_sidebar_fg_color ${on_surface};
@define-color sidebar_border_color @sidebar_bg_color;
@define-color sidebar_backdrop_color @sidebar_bg_color;
@define-color view_bg_color ${surface_container_lowest};
@define-color view_fg_color ${on_surface};
@define-color overview_bg_color ${surface_container_lowest};
@define-color overview_fg_color ${on_surface};
/* Popups */
@define-color popover_bg_color ${surface_container_highest};
@define-color popover_fg_color ${on_surface};
@define-color dialog_bg_color ${surface_container_high};
@define-color dialog_fg_color ${on_surface};
GTK3EOF
    echo "[applycolor] GTK3 colors written"
}

# ---------------------------------------------------------------------------
# fuzzel — fuzzel.ini includes fuzzel_theme.ini. Was matugen-only.
# ---------------------------------------------------------------------------
apply_fuzzel() {
    local fuzzel_dir="$HOME/.config/fuzzel"
    [[ -f "$fuzzel_dir/fuzzel.ini" ]] || return 0

    local background="" on_background="" surface_variant="" on_surface_variant="" primary=""
    for i in "${!colorlist[@]}"; do
        case "${colorlist[$i]}" in
            '$background')          background="${colorvalues[$i]}"          ;;
            '$onBackground')        on_background="${colorvalues[$i]}"       ;;
            '$surfaceVariant')      surface_variant="${colorvalues[$i]}"     ;;
            '$onSurfaceVariant')    on_surface_variant="${colorvalues[$i]}"  ;;
            '$primary')             primary="${colorvalues[$i]}"             ;;
        esac
    done

    cat > "$fuzzel_dir/fuzzel_theme.ini" << FUZZELEOF
[colors]
background=${background#\#}ff
text=${on_background#\#}ff
selection=${surface_variant#\#}ff
selection-text=${on_surface_variant#\#}ff
border=${surface_variant#\#}dd
match=${primary#\#}ff
selection-match=${primary#\#}ff
FUZZELEOF
    echo "[applycolor] fuzzel colors written"
}

# ---------------------------------------------------------------------------
# GTK4 colors.css — written to ~/.config/gtk-4.0/colors.css which GTK4
# loads automatically. Running apps pick it up on next theme refresh;
# most do so instantly. Maps Material You roles to GTK4 color variables.
# ---------------------------------------------------------------------------
apply_gtk4() {
    local gtk4_dir="$HOME/.config/gtk-4.0"
    mkdir -p "$gtk4_dir"

    # Pull the colors we need from the parsed arrays
    local primary="" on_primary="" primary_container="" on_primary_container=""
    local secondary="" on_secondary="" secondary_container="" on_secondary_container=""
    local surface="" on_surface="" surface_variant="" on_surface_variant=""
    local surface_container="" surface_container_high="" surface_container_low=""
    local error="" on_error="" error_container="" on_error_container=""
    local outline="" outline_variant="" inverse_surface="" inverse_on_surface=""
    local tertiary="" on_tertiary="" tertiary_container="" on_tertiary_container=""

    for i in "${!colorlist[@]}"; do
        case "${colorlist[$i]}" in
            '$primary')                 primary="${colorvalues[$i]}"                 ;;
            '$onPrimary')               on_primary="${colorvalues[$i]}"              ;;
            '$primaryContainer')        primary_container="${colorvalues[$i]}"       ;;
            '$onPrimaryContainer')      on_primary_container="${colorvalues[$i]}"    ;;
            '$secondary')               secondary="${colorvalues[$i]}"               ;;
            '$onSecondary')             on_secondary="${colorvalues[$i]}"            ;;
            '$secondaryContainer')      secondary_container="${colorvalues[$i]}"     ;;
            '$onSecondaryContainer')    on_secondary_container="${colorvalues[$i]}"  ;;
            '$tertiary')                tertiary="${colorvalues[$i]}"                ;;
            '$onTertiary')              on_tertiary="${colorvalues[$i]}"             ;;
            '$tertiaryContainer')       tertiary_container="${colorvalues[$i]}"      ;;
            '$onTertiaryContainer')     on_tertiary_container="${colorvalues[$i]}"   ;;
            '$surface')                 surface="${colorvalues[$i]}"                 ;;
            '$onSurface')               on_surface="${colorvalues[$i]}"              ;;
            '$surfaceVariant')          surface_variant="${colorvalues[$i]}"         ;;
            '$onSurfaceVariant')        on_surface_variant="${colorvalues[$i]}"      ;;
            '$surfaceContainer')        surface_container="${colorvalues[$i]}"       ;;
            '$surfaceContainerHigh')    surface_container_high="${colorvalues[$i]}"  ;;
            '$surfaceContainerLow')     surface_container_low="${colorvalues[$i]}"   ;;
            '$error')                   error="${colorvalues[$i]}"                   ;;
            '$onError')                 on_error="${colorvalues[$i]}"                ;;
            '$errorContainer')          error_container="${colorvalues[$i]}"         ;;
            '$onErrorContainer')        on_error_container="${colorvalues[$i]}"      ;;
            '$outline')                 outline="${colorvalues[$i]}"                 ;;
            '$outlineVariant')          outline_variant="${colorvalues[$i]}"         ;;
            '$inverseSurface')          inverse_surface="${colorvalues[$i]}"         ;;
            '$inverseOnSurface')        inverse_on_surface="${colorvalues[$i]}"      ;;
        esac
    done

    # Write the CSS — GTK4 picks this up automatically
    cat > "$gtk4_dir/colors.css" << CSSEOF
@define-color accent_color ${primary};
@define-color accent_bg_color ${primary};
@define-color accent_fg_color ${on_primary};

@define-color destructive_color ${error};
@define-color destructive_bg_color ${error_container};
@define-color destructive_fg_color ${on_error_container};

@define-color success_color ${tertiary};
@define-color success_bg_color ${tertiary_container};
@define-color success_fg_color ${on_tertiary_container};

@define-color warning_color ${tertiary};
@define-color warning_bg_color ${tertiary_container};
@define-color warning_fg_color ${on_tertiary_container};

@define-color error_color ${error};
@define-color error_bg_color ${error_container};
@define-color error_fg_color ${on_error_container};

@define-color window_bg_color ${surface};
@define-color window_fg_color ${on_surface};

@define-color view_bg_color ${surface_container_low};
@define-color view_fg_color ${on_surface};

@define-color headerbar_bg_color ${surface_container};
@define-color headerbar_fg_color ${on_surface};
@define-color headerbar_border_color ${outline_variant};
@define-color headerbar_backdrop_color ${surface_container_low};
@define-color headerbar_shade_color ${outline_variant};

@define-color card_bg_color ${surface_container_high};
@define-color card_fg_color ${on_surface};
@define-color card_shade_color ${outline_variant};

@define-color dialog_bg_color ${surface_container};
@define-color dialog_fg_color ${on_surface};

@define-color popover_bg_color ${surface_container};
@define-color popover_fg_color ${on_surface};
@define-color popover_shade_color ${outline_variant};

@define-color shade_color ${outline_variant};
@define-color scrollbar_outline_color ${outline};

@define-color sidebar_bg_color ${surface_container_low};
@define-color sidebar_fg_color ${on_surface};
@define-color sidebar_backdrop_color ${surface};
@define-color sidebar_shade_color ${outline_variant};

@define-color secondary_sidebar_bg_color ${surface_container};
@define-color secondary_sidebar_fg_color ${on_surface_variant};
@define-color secondary_sidebar_backdrop_color ${surface_container_low};
@define-color secondary_sidebar_shade_color ${outline_variant};
CSSEOF

    echo "[applycolor] GTK4 colors written to $gtk4_dir/colors.css"
}

# ---------------------------------------------------------------------------
# Hyprland extra visuals — shadows, groups, dim
# All applied live via hyprctl keyword, no restart needed
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Kitty — writes a theme file and reloads all running instances live
# Kitty supports live reload via SIGUSR1
# ---------------------------------------------------------------------------
apply_kitty() {
    local kitty_theme_dir="$HOME/.local/state/quickshell/user/generated/terminal"
    local kitty_theme_file="$kitty_theme_dir/kitty-theme.conf"
    mkdir -p "$kitty_theme_dir"

    local background="" foreground="" cursor="" selection_bg="" selection_fg=""
    local black="" red="" green="" yellow="" blue="" magenta="" cyan="" white=""
    local br_black="" br_red="" br_green="" br_yellow=""
    local br_blue="" br_magenta="" br_cyan="" br_white=""
    local primary="" primary_container="" secondary="" secondary_container=""
    local tertiary="" tertiary_container="" error="" error_container=""
    local on_primary="" on_primary_container="" on_secondary=""
    local on_secondary_container="" on_tertiary="" on_tertiary_container="" on_error="" on_error_container=""
    local outline_variant=""

    for i in "${!colorlist[@]}"; do
        case "${colorlist[$i]}" in
            '$surface')              background="${colorvalues[$i]}"   ;;
            '$onSurface')            foreground="${colorvalues[$i]}"   ;;
            '$primary')              primary="${colorvalues[$i]}"      ;;
            '$primaryContainer')     primary_container="${colorvalues[$i]}" ;;
            '$secondary')            secondary="${colorvalues[$i]}"    ;;
            '$secondaryContainer')   secondary_container="${colorvalues[$i]}" ;;
            '$tertiary')             tertiary="${colorvalues[$i]}"     ;;
            '$tertiaryContainer')    tertiary_container="${colorvalues[$i]}" ;;
            '$error')                error="${colorvalues[$i]}"        ;;
            '$errorContainer')       error_container="${colorvalues[$i]}" ;;
            '$onPrimary')            on_primary="${colorvalues[$i]}"   ;;
            '$onPrimaryContainer')   on_primary_container="${colorvalues[$i]}" ;;
            '$onSecondary')          on_secondary="${colorvalues[$i]}" ;;
            '$onSecondaryContainer') on_secondary_container="${colorvalues[$i]}" ;;
            '$onTertiary')           on_tertiary="${colorvalues[$i]}"  ;;
            '$onTertiaryContainer') on_tertiary_container="${colorvalues[$i]}" ;;
            '$onError')              on_error="${colorvalues[$i]}"     ;;
            '$onErrorContainer')     on_error_container="${colorvalues[$i]}" ;;
            '$outlineVariant')       outline_variant="${colorvalues[$i]}" ;;
            '$term0')   black="${colorvalues[$i]}"     ;;
            '$term1')   red="${colorvalues[$i]}"       ;;
            '$term2')   green="${colorvalues[$i]}"     ;;
            '$term3')   yellow="${colorvalues[$i]}"    ;;
            '$term4')   blue="${colorvalues[$i]}"      ;;
            '$term5')   magenta="${colorvalues[$i]}"   ;;
            '$term6')   cyan="${colorvalues[$i]}"      ;;
            '$term7')   cursor="${colorvalues[$i]}"
                        white="${colorvalues[$i]}"     ;;
            '$term8')   br_black="${colorvalues[$i]}"  ;;
            '$term9')   br_red="${colorvalues[$i]}"    ;;
            '$term10')  br_green="${colorvalues[$i]}"  ;;
            '$term11')  br_yellow="${colorvalues[$i]}" ;;
            '$term12')  br_blue="${colorvalues[$i]}"   ;;
            '$term13')  br_magenta="${colorvalues[$i]}";;
            '$term14')  br_cyan="${colorvalues[$i]}"   ;;
            '$term15')  br_white="${colorvalues[$i]}"  ;;
        esac
    done

    cat > "$kitty_theme_file" << KITTYEOF
# Generated by applycolor.sh — do not edit manually
cursor                ${cursor}
foreground            ${foreground}

color0  ${black}
color1  ${red}
color2  ${green}
color3  ${yellow}
color4  ${blue}
color5  ${magenta}
color6  ${cyan}
color7  ${white}
color8  ${br_black}
color9  ${br_red}
color10 ${br_green}
color11 ${br_yellow}
color12 ${br_blue}
color13 ${br_magenta}
color14 ${br_cyan}
color15 ${br_white}

background            ${background}

selection_background  ${on_secondary_container}
selection_foreground  ${secondary_container}

color255              ${primary}
color254              ${primary_container}
color253              ${secondary}
color252              ${secondary_container}
color251              ${tertiary}
color250              ${tertiary_container}
color249              ${error}
color248              ${error_container}

color232              ${on_primary}
color233              ${on_primary_container}
color234              ${on_secondary}
color235              ${on_secondary_container}
color236              ${on_tertiary}
color237              ${on_tertiary_container}
color238              ${on_error}
color239              ${on_error_container}
color240              ${on_primary}

color243              ${primary}
color244              ${error}
color245              ${outline_variant}
KITTYEOF

    # Live-reload every running kitty via its remote-control socket.
    # kitty.conf sets `listen_on unix:/tmp/kitty`, so each instance listens on
    # /tmp/kitty-<pid>. --all hits every window/tab, --configured persists it
    # as the new default for windows opened later.
    if command -v kitty &>/dev/null; then
        for sock in /tmp/kitty-*; do
            [[ -S "$sock" ]] || continue
            kitty @ --to "unix:$sock" set-colors --all --configured "$kitty_theme_file" 2>/dev/null || true
        done
    fi
}

# ---------------------------------------------------------------------------
# Tmux — updates background and status bar colors in all running sessions
# Uses tmux set-option for window-style and status colors.
# ---------------------------------------------------------------------------
apply_tmux() {
    if ! command -v tmux &>/dev/null; then
        return 0
    fi

    local bg="" fg="" primary="" surface=""
    for i in "${!colorlist[@]}"; do
        case "${colorlist[$i]}" in
            '$surface')   bg="${colorvalues[$i]}"  ;;
            '$onSurface') fg="${colorvalues[$i]}" ;;
            '$primary')   primary="${colorvalues[$i]}"     ;;
        esac
    done
    bg="${bg:-#000000}"
    fg="${fg:-#ffffff}"
    primary="${primary:-#8aadf4}"

    local sessions
    sessions=$(tmux list-sessions -F '#{session_id}' 2>/dev/null) || return 0

    for sid in $sessions; do
        tmux set-environment -t "$sid" -g TERMINAL_BG "$bg" 2>/dev/null
        tmux set-option -t "$sid" -g window-style "bg=$bg,fg=$fg" 2>/dev/null
        tmux set-option -t "$sid" -g window-active-style "bg=$bg,fg=$fg" 2>/dev/null
        tmux set-option -t "$sid" -g status-bg "$bg" 2>/dev/null
        tmux set-option -t "$sid" -g status-fg "$fg" 2>/dev/null
    done
}

# ---------------------------------------------------------------------------
# Rofi — writes a colors.rasi theme file; rofi reads it fresh each launch
# ---------------------------------------------------------------------------
apply_rofi() {
    local rofi_dir="$HOME/.config/rofi"
    mkdir -p "$rofi_dir"

    local background="" on_surface="" primary="" on_primary=""
    local surface_container="" surface_container_high="" outline_variant=""

    for i in "${!colorlist[@]}"; do
        case "${colorlist[$i]}" in
            '$surface')               background="${colorvalues[$i]}"           ;;
            '$onSurface')             on_surface="${colorvalues[$i]}"           ;;
            '$primary')               primary="${colorvalues[$i]}"              ;;
            '$onPrimary')             on_primary="${colorvalues[$i]}"           ;;
            '$surfaceContainer')      surface_container="${colorvalues[$i]}"    ;;
            '$surfaceContainerHigh')  surface_container_high="${colorvalues[$i]}" ;;
            '$outlineVariant')        outline_variant="${colorvalues[$i]}"      ;;
        esac
    done

    cat > "$rofi_dir/material-colors.rasi" << ROFIEOF
/* Generated by applycolor.sh — do not edit manually */
* {
    bg:          ${background};
    bg-alt:      ${surface_container};
    bg-selected: ${surface_container_high};
    fg:          ${on_surface};
    fg-selected: ${on_primary};
    accent:      ${primary};
    border:      ${outline_variant};
}
ROFIEOF

    # If a main rofi config exists, ensure it imports our colors (once)
    local rofi_conf="$rofi_dir/config.rasi"
    if [[ -f "$rofi_conf" ]]; then
        if ! grep -qF '@import "material-colors.rasi"' "$rofi_conf"; then
            sed -i '1s|^|@import "material-colors.rasi"\n|' "$rofi_conf"
        fi
    else
        echo '@import "material-colors.rasi"' > "$rofi_conf"
    fi
}

# ---------------------------------------------------------------------------
# VSCode — writes to user settings.json workbench.colorCustomizations
# Only touches the color keys; leaves all other settings intact
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Chrome — generate and reload theme
# ---------------------------------------------------------------------------
apply_chrome() {
    local theme_json="$STATE_DIR/user/generated/colors.json"
    local chrome_theme_dir="$HOME/Projects/chrome-theme"
    
    if [ -f "$theme_json" ]; then
        python3 "$SCRIPT_DIR/generate_chrome_theme.py" "$theme_json" "$chrome_theme_dir"
        python3 "$SCRIPT_DIR/reload_chrome_theme.py" "$chrome_theme_dir"
    fi
}

# ---------------------------------------------------------------------------
# Cava — splice Material You gradient colors into cava config
# Reads the matugen-generated file and replaces the gradient block
# ---------------------------------------------------------------------------
apply_cava() {
    local cava_conf="$HOME/.config/cava/config"
    local cava_colors="$HOME/.config/cava/material-colors.conf"
    [[ -f "$cava_conf" ]] || return 0
    [[ -f "$cava_colors" ]] || return 0

    # Extract the gradient block from the generated file (skip the [color] header)
    local gradient_block
    gradient_block=$(grep -v '^\[color\]' "$cava_colors" | grep -v '^$')

    # Use awk to replace the gradient section in the config.
    # Skip every line starting with "gradient" (gradient =, gradient_count, gradient_color_N)
    # and emit the new block exactly once at the first match.
    awk -v new="$gradient_block" '
        /^gradient/ { if (!p) { print new; p=1 }; next }
        { print }
    ' "$cava_conf" > "${cava_conf}.tmp" && mv "${cava_conf}.tmp" "$cava_conf"

    echo "[applycolor] Cava gradient colors updated"
}

# ---------------------------------------------------------------------------
# Starship — splice Material You palette into starship.toml
# Appends/replaces the [palettes.material] block and sets palette = "material"
# ---------------------------------------------------------------------------
apply_starship() {
    local starship_conf="$HOME/.config/starship.toml"
    local palette_file="$HOME/.local/state/quickshell/user/generated/starship-palette.toml"
    [[ -f "$starship_conf" ]] || return 0
    [[ -f "$palette_file" ]] || return 0

    # Ensure palette = "material" is set at the top level
    if ! grep -q '^palette' "$starship_conf"; then
        sed -i '1s|^|palette = "material"\n|' "$starship_conf"
    else
        sed -i 's/^palette = .*/palette = "material"/' "$starship_conf"
    fi

    # Remove existing [palettes.material] block if present
    sed -i '/^\[palettes\.material\]/,/^\[/{/^\[palettes\.material\]/d;/^\[/!d}' "$starship_conf"

    # Append the new palette
    printf '\n' >> "$starship_conf"
    cat "$palette_file" >> "$starship_conf"

    echo "[applycolor] Starship palette updated"
}

# ---------------------------------------------------------------------------
# Hyprexpo — update bg_col to match Material You surface
# ---------------------------------------------------------------------------
apply_hyprexpo() {
    command -v hyprctl &>/dev/null || return 0

    local surface=""
    for i in "${!colorlist[@]}"; do
        case "${colorlist[$i]}" in
            '$surface') surface="${colorvalues[$i]}" ;;
        esac
    done
    surface="${surface:-#000000}"

    echo "[applycolor] Hyprexpo bg_col skipped (plugin not loaded)"
}
# CONFIG_DIR is only needed for apply_qt, so warn but don't hard-exit
# ---------------------------------------------------------------------------
if [[ -d "$CONFIG_DIR" ]]; then
    cd "$CONFIG_DIR"
else
    echo "[applycolor] Warning: CONFIG_DIR '$CONFIG_DIR' does not exist." >&2
fi

# ---------------------------------------------------------------------------
# Always apply terminal theming — check config if it exists, otherwise
# default to enabled so colours are never silently skipped.
# ---------------------------------------------------------------------------
if [[ -f "$CONFIG_FILE" ]]; then
    enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE")
    if [[ "$enable_terminal" == "true" ]]; then
        apply_term &
    else
        echo "[applycolor] Terminal theming disabled in config." >&2
    fi
else
    echo "[applycolor] Config not found at $CONFIG_FILE — applying terminal theming by default." >&2
    apply_term &
fi

apply_gtk4 &        # GTK4 colors.css — picked up automatically by running apps
apply_gtk3 &         # GTK3 gtk.css @define-color block
apply_hyprlock &     # Hyprlock lock-screen colors
apply_hamr &         # hamr launcher colors
apply_fuzzel &       # fuzzel launcher theme
apply_kitty &        # Kitty terminal config + live reload
apply_tmux &         # Tmux background and status bar colors
apply_rofi &         # Rofi color theme file
# Wire up Chrome theme
apply_chrome &
# VSCode is handled by material-code-set-color.sh (called from switchwall.sh post_process)
apply_borders &  # Always apply
apply_cava &         # Cava gradient colors
apply_starship &     # Starship prompt palette
apply_hyprexpo &     # Hyprexpo overview background — hyprctl is safe to call any time Hyprland is running
# apply_qt &  # Qt theming already handled by kde-material-colors

# ---------------------------------------------------------------------------
# Icon theme — Papirus-Light for light mode, Papirus-Dark for dark mode
# Detects mode from gsettings (set by fetchwall pre_process)
# ---------------------------------------------------------------------------
apply_icons() {
    local mode
    mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
    local icon_theme="Papirus-Dark"
    [[ "$mode" == "prefer-light" ]] && icon_theme="Papirus-Light"

    # GTK 3
    sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$icon_theme/" \
        "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null
    # GTK 4
    sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$icon_theme/" \
        "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null
    # GTK 2
    sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=\"$icon_theme\"/" \
        "$HOME/.gtkrc-2.0" 2>/dev/null
    # xsettingsd
    sed -i "s|Net/IconThemeName \".*\"|Net/IconThemeName \"$icon_theme\"|" \
        "$HOME/.config/xsettingsd/xsettingsd.conf" 2>/dev/null
    pkill -HUP xsettingsd 2>/dev/null || true
    # KDE
    sed -i "s/^Theme=.*/Theme=$icon_theme/" \
        "$HOME/.config/kdeglobals" 2>/dev/null
    # Hyprland env (runtime)
    hyprctl eval "hl.env('GTK_ICON_THEME', '${icon_theme}')" 2>/dev/null
    # GNOME/GTK settings daemon — this is what actually sticks across apps
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null

    echo "[applycolor] Icon theme set to $icon_theme"
}

apply_icons &

# ---------------------------------------------------------------------------
# Discord (BetterDiscord "Midnight M3") — generated from the live scheme so it
# tracks custom themes and wallpaper colors alike. BetterDiscord hot-reloads.
# ---------------------------------------------------------------------------
apply_discord() {
    local theme_dir="$HOME/.config/BetterDiscord/themes"
    local colors_json="$STATE_DIR/user/generated/colors.json"
    [[ -d "$theme_dir" && -f "$colors_json" ]] || return 0
    python3 "$SCRIPT_DIR/generate_discord_theme.py" "$colors_json" \
        "$theme_dir/MidnightM3.theme.css" 2>/dev/null \
        && echo "[applycolor] Discord theme written"
}

apply_discord &

wait
