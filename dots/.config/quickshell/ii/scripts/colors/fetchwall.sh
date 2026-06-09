#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
MATUGEN_DIR="$XDG_CONFIG_HOME/matugen"
WPE_ASSETS_DIR="/mnt/wwn-0x50014ee65ea3c55b-part1/SteamLibrary/steamapps/common/wallpaper_engine/assets"
terminalscheme="$SCRIPT_DIR/terminal/scheme-base.json"

handle_kde_material_you_colors() {
    # Check if Qt app theming is enabled in config
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        enable_qt_apps=$(jq -r '.appearance.wallpaperTheming.enableQtApps' "$SHELL_CONFIG_FILE")
        if [ "$enable_qt_apps" == "false" ]; then
            return
        fi
    fi

    # Map $type_flag to allowed scheme variants for kde-material-you-colors-wrapper.sh
    local kde_scheme_variant=""
    case "$type_flag" in
        scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot)
            kde_scheme_variant="$type_flag"
            ;;
        *)
            kde_scheme_variant="scheme-content" # default
            ;;
    esac
    "$XDG_CONFIG_HOME"/matugen/templates/kde/kde-material-you-colors-wrapper.sh --scheme-variant "$kde_scheme_variant"
}


post_process() {
    local screen_width="$1"
    local screen_height="$2"
    local wallpaper_path="$3"

    handle_kde_material_you_colors &
    "$SCRIPT_DIR/code/material-code-set-color.sh" &
}

check_and_prompt_upscale() {
    local img="$1"
    min_width_desired="$(hyprctl monitors -j | jq '([.[].width] | max)' | xargs)" # max monitor width
    min_height_desired="$(hyprctl monitors -j | jq '([.[].height] | max)' | xargs)" # max monitor height

    if command -v identify &>/dev/null && [ -f "$img" ]; then
        local img_width img_height
        if is_video "$img"; then # Not check resolution for videos, just let em pass
            img_width=$min_width_desired
            img_height=$min_height_desired
        else
            img_width=$(identify -format "%w" "$img" 2>/dev/null)
            img_height=$(identify -format "%h" "$img" 2>/dev/null)
        fi
        if [[ "$img_width" -lt "$min_width_desired" || "$img_height" -lt "$min_height_desired" ]]; then
            action=$(notify-send "Upscale?" \
                "Image resolution (${img_width}x${img_height}) is lower than screen resolution (${min_width_desired}x${min_height_desired})" \
                -A "open_upscayl=Open Upscayl"\
                -a "Wallpaper switcher")
            if [[ "$action" == "open_upscayl" ]]; then
                if command -v upscayl &>/dev/null; then
                    nohup upscayl > /dev/null 2>&1 &
                else
                    action2=$(notify-send \
                        -a "Wallpaper switcher" \
                        -c "im.error" \
                        -A "install_upscayl=Install Upscayl (Arch)" \
                        "Install Upscayl?" \
                        "yay -S upscayl-bin")
                    if [[ "$action2" == "install_upscayl" ]]; then
                        kitty -1 yay -S upscayl-bin
                        if command -v upscayl &>/dev/null; then
                            nohup upscayl > /dev/null 2>&1 &
                        fi
                    fi
                fi
            fi
        fi
    fi
}

CUSTOM_DIR="$XDG_CONFIG_HOME/hypr/custom"
RESTORE_SCRIPT_DIR="$CUSTOM_DIR/scripts"
RESTORE_SCRIPT="$RESTORE_SCRIPT_DIR/__restore_video_wallpaper.sh"
THUMBNAIL_DIR="$RESTORE_SCRIPT_DIR/mpvpaper_thumbnails"
VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5 load-scripts=no"
# Monitor whose wallpaper drives matugen theming. Override with the env var;
# otherwise prefer DP-1, then the focused monitor, then the first connected one.
PREFERRED_MATUGEN_MONITOR="${PREFERRED_MATUGEN_MONITOR:-$(hyprctl monitors -j 2>/dev/null | jq -r '
    (.[] | select(.name == "DP-1") | .name),
    ([.[] | select(.focused == true) | .name][0]),
    (.[0].name)' 2>/dev/null | grep -v '^null$' | head -n1)}"
[ -z "$PREFERRED_MATUGEN_MONITOR" ] && PREFERRED_MATUGEN_MONITOR="DP-1"
MATUGEN_WALLPAPER_PATH_FILE="$STATE_DIR/user/generated/wallpaper/path.txt"
MONITOR_STATE_DIR="$STATE_DIR/user/generated/wallpaper/monitors"

is_video() {
    local extension="${1##*.}"
    [[ "$extension" == "mp4" || "$extension" == "webm" || "$extension" == "mkv" || "$extension" == "avi" || "$extension" == "mov" ]] && return 0 || return 1
}

is_wpe_wallpaper() {
    [[ -d "$1" && -f "$1/project.json" ]]
}

kill_existing_mpvpaper() {
    pkill -f -9 mpvpaper || true
}

# awww paints the actual compositor wallpaper; if the daemon died, `awww img`
# silently fails and the switch appears to revert. Make sure it's up first.
ensure_awww_daemon() {
    command -v awww-daemon &>/dev/null || return 0
    if ! pgrep -x awww-daemon >/dev/null; then
        awww-daemon >/dev/null 2>&1 &
        sleep 0.3
    fi
}

create_restore_script() {
    local video_path=$1
    cat > "$RESTORE_SCRIPT.tmp" << EOF
#!/bin/bash
# Generated by switchwall.sh - Don't modify it by yourself.
# Time: $(date)

pkill -f -9 mpvpaper

for monitor in \$(hyprctl monitors -j | jq -r '.[] | .name'); do
    mpvpaper -o "$VIDEO_OPTS" "\$monitor" "$video_path" &
    sleep 0.1
done
EOF
    mv "$RESTORE_SCRIPT.tmp" "$RESTORE_SCRIPT"
    chmod +x "$RESTORE_SCRIPT"
}

remove_restore() {
    cat > "$RESTORE_SCRIPT.tmp" << EOF
#!/bin/bash
# The content of this script will be generated by switchwall.sh - Don't modify it by yourself.
EOF
    mv "$RESTORE_SCRIPT.tmp" "$RESTORE_SCRIPT"
}

set_wallpaper_path() {
    local path="$1"
    if [[ -z "$path" || "$path" == "--restore" || "$path" == "null" ]]; then
        return
    fi
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        jq --indent 4 --arg path "$path" '.background.wallpaperPath = $path' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    fi
}

set_thumbnail_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        jq --indent 4 --arg path "$path" '.background.thumbnailPath = $path' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    fi
}

get_config_wallpaper_path() {
    jq -r '.background.wallpaperPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null || true
}

get_config_thumbnail_path() {
    jq -r '.background.thumbnailPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null || true
}

get_config_color_mode() {
    jq -r '.appearance.colorMode // empty' "$SHELL_CONFIG_FILE" 2>/dev/null || true
}

get_focused_monitor_name() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null
}

get_monitor_state_path() {
    local monitor="$1"
    [[ -z "$monitor" ]] && return

    local state_file="$MONITOR_STATE_DIR/${monitor}.json"
    [[ -f "$state_file" ]] || return

    jq -r '.matugenPath // .thumbnailPath // .previewPath // .path // empty' "$state_file" 2>/dev/null || true
}

get_any_monitor_state_path() {
    [[ -d "$MONITOR_STATE_DIR" ]] || return

    local state_file
    state_file="$(find "$MONITOR_STATE_DIR" -name "*.json" 2>/dev/null | sort | head -1)"
    [[ -n "$state_file" ]] || return

    jq -r '.matugenPath // .thumbnailPath // .previewPath // .path // empty' "$state_file" 2>/dev/null || true
}

resolve_matugen_source_path() {
    local imgpath=""
    local preferred_monitor=""
    local focused_monitor=""
    local config_wallpaper=""
    local config_thumbnail=""

    preferred_monitor="$PREFERRED_MATUGEN_MONITOR"
    if [[ -n "$preferred_monitor" ]]; then
        imgpath="$(get_monitor_state_path "$preferred_monitor")"
    fi

    if [[ -z "$imgpath" || "$imgpath" == "null" || "$imgpath" == "--restore" ]]; then
        focused_monitor="$(get_focused_monitor_name)"
    fi
    if [[ -z "$imgpath" || "$imgpath" == "null" || "$imgpath" == "--restore" ]] && [[ -n "$focused_monitor" ]]; then
        imgpath="$(get_monitor_state_path "$focused_monitor")"
    fi

    if [[ -z "$imgpath" || "$imgpath" == "null" || "$imgpath" == "--restore" ]]; then
        config_wallpaper="$(get_config_wallpaper_path)"
        config_thumbnail="$(get_config_thumbnail_path)"
        if [[ -n "$config_thumbnail" && -f "$config_thumbnail" ]] && [[ -n "$config_wallpaper" ]] && is_video "$config_wallpaper"; then
            imgpath="$config_thumbnail"
        else
            imgpath="$config_wallpaper"
        fi
    fi

    if [[ -z "$imgpath" || "$imgpath" == "null" || "$imgpath" == "--restore" ]]; then
        imgpath="$(get_any_monitor_state_path)"
    fi

    printf '%s\n' "$imgpath"
}

set_matugen_wallpaper_path_file() {
    local path="$1"
    [[ -z "$path" || "$path" == "null" || "$path" == "--restore" ]] && return

    mkdir -p "$(dirname "$MATUGEN_WALLPAPER_PATH_FILE")"
    printf '%s\n' "$path" > "${MATUGEN_WALLPAPER_PATH_FILE}.tmp"
    mv "${MATUGEN_WALLPAPER_PATH_FILE}.tmp" "$MATUGEN_WALLPAPER_PATH_FILE"
}

write_monitor_state() {
    local monitor="$1"
    local wallpaper_path="$2"
    local preview_path="$3"
    local matugen_path="$4"
    local kind="${5:-image}"
    local wpe_id="$6"
    local wpe_path="$7"

    [[ -z "$monitor" ]] && return

    local _existing_mon
    _existing_mon="$(jq -r '.monitor // empty' "${MONITOR_STATE_DIR}/${monitor}.json" 2>/dev/null || true)"
    if [[ -n "$_existing_mon" && "$_existing_mon" != "$monitor" ]]; then
        logger -t switchwall-debug "fetchwall write_monitor_state: MISMATCH — file has $_existing_mon but called with $monitor, rejecting"
        return
    fi

    mkdir -p "$MONITOR_STATE_DIR"

    jq -n \
        --arg monitor "$monitor" \
        --arg path "$wallpaper_path" \
        --arg previewPath "$preview_path" \
        --arg thumbnailPath "$preview_path" \
        --arg matugenPath "$matugen_path" \
        --arg kind "$kind" \
        --arg wpeId "$wpe_id" \
        --arg wpePath "$wpe_path" \
        '{
            monitor: $monitor,
            path: $path,
            previewPath: $previewPath,
            thumbnailPath: $thumbnailPath,
            matugenPath: $matugenPath,
            kind: $kind
        }
        + (if $kind == "wpe" then {
            wpe: true,
            wpe_id: $wpeId,
            wpe_path: $wpePath
        } else {} end)' > "${MONITOR_STATE_DIR}/${monitor}.tmp" &&
        mv "${MONITOR_STATE_DIR}/${monitor}.tmp" "${MONITOR_STATE_DIR}/${monitor}.json"
}

detect_brightness_mode() {
    local img="$1"

    # Handle Wallpaper Engine (folder)
    if is_wpe_wallpaper "$img"; then
        if [[ -f "$img/preview.png" ]]; then
            img="$img/preview.png"
        elif [[ -f "$img/preview.jpg" ]]; then
            img="$img/preview.jpg"
        else
            echo "dark"
            return
        fi
    fi

    # Skip videos
    if is_video "$img"; then
        echo "dark"
        return
    fi

    local brightness=""
    if command -v magick &>/dev/null; then
        brightness=$(magick "$img" -colorspace Gray -format "%[fx:mean]" info: 2>/dev/null)
    else
        echo "dark"
        return
    fi

    awk -v b="$brightness" 'BEGIN {
        if (b < 0.5) print "dark";
        else print "light";
    }'
}

pre_process() {
    local mode_flag="$1"
    if [[ "$mode_flag" == "dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        gsettings set org.gnome.desktop.interface gtk-theme 'Colloid-Dark-Gruvbox'
    elif [[ "$mode_flag" == "light" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
        gsettings set org.gnome.desktop.interface gtk-theme 'Colloid-Light-Gruvbox'
    fi

    if [ ! -d "$CACHE_DIR"/user/generated ]; then
        mkdir -p "$CACHE_DIR"/user/generated
    fi
}

switch() {
    imgpath="$1"
    mode_flag="$2"
    type_flag="$3"
    color_flag="$4"
    color="$5"
    monitor_flag="$6"

    # Start Gemini auto-categorization if enabled
    aiStylingEnabled=$(jq -r '.background.widgets.clock.cookie.aiStyling' "$SHELL_CONFIG_FILE")
    aiStylingModel=$(jq -r '.background.widgets.clock.cookie.aiStylingModel' "$SHELL_CONFIG_FILE")
    if [[ "$aiStylingEnabled" == "true" && -f "$imgpath" ]]; then
        if [[ "$aiStylingModel" == "gemini" ]]; then
            "$SCRIPT_DIR/../ai/gemini-categorize-wallpaper.sh" "$imgpath" > "$STATE_DIR/user/generated/wallpaper/category.txt" &
        fi
        if [[ "$aiStylingModel" == "openrouter" ]]; then
            "$SCRIPT_DIR/../ai/openrouter-categorize-wallpaper.sh" "$imgpath" > "$STATE_DIR/user/generated/wallpaper/category.txt" &
        fi
    fi

    read scale screenx screeny screensizey < <(hyprctl monitors -j | jq '.[] | select(.focused) | .scale, .x, .y, .height' | xargs)
    cursorposx=$(hyprctl cursorpos -j | jq '.x' 2>/dev/null) || cursorposx=960
    cursorposx=$(bc <<< "scale=0; ($cursorposx - $screenx) * $scale / 1")
    cursorposy=$(hyprctl cursorpos -j | jq '.y' 2>/dev/null) || cursorposy=540
    cursorposy=$(bc <<< "scale=0; ($cursorposy - $screeny) * $scale / 1")

    if [[ "$color_flag" == "1" ]]; then
        matugen_args=(color hex "$color")
        generate_colors_material_args=(--color "$color")
    else
        if [[ -z "$imgpath" ]]; then
            echo 'Aborted'
            exit 0
        fi

        kill_existing_mpvpaper

        if is_wpe_wallpaper "$imgpath"; then
            local wpe_id
            wpe_id="$(basename "$imgpath")"
            local wpe_thumbnail="$THUMBNAIL_DIR/wpe_${wpe_id}.png"
            mkdir -p "$THUMBNAIL_DIR"

            # Determine output monitor(s)
            local _wpe_output
            if [[ -n "$monitor_flag" ]]; then
                _wpe_output="$monitor_flag"
            else
                _wpe_output=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name' 2>/dev/null)
            fi

            # Use WPE preview image for color gen (clean, no desktop windows)
            if [[ -f "$imgpath/preview.gif" ]]; then
                magick "$imgpath/preview.gif[0]" "$wpe_thumbnail" 2>/dev/null || \
                    grim ${_wpe_output:+-o "$_wpe_output"} "$wpe_thumbnail" 2>/dev/null || true
            elif [[ -f "$imgpath/preview.jpg" ]]; then
                magick "$imgpath/preview.jpg" "$wpe_thumbnail" 2>/dev/null || cp "$imgpath/preview.jpg" "$wpe_thumbnail" 2>/dev/null || true
            elif [[ -f "$imgpath/preview.png" ]]; then
                cp "$imgpath/preview.png" "$wpe_thumbnail" 2>/dev/null || true
            else
                sleep 1.5
                grim ${_wpe_output:+-o "$_wpe_output"} "$wpe_thumbnail" 2>/dev/null || true
            fi

            set_thumbnail_path "$wpe_thumbnail"
            [[ -z "$no_save_flag" && -z "$noswitch_flag" ]] && set_wallpaper_path "$imgpath"

            if [[ -f "$wpe_thumbnail" ]]; then
                matugen_args=(image "$wpe_thumbnail")
                generate_colors_material_args=(--path "$wpe_thumbnail")
            else
                echo "WPE: could not get thumbnail for color gen, skipping"
                return
            fi

            # Write per-monitor state file with real wallpaper path plus preview/matugen sources
            if [[ -n "$_wpe_output" ]]; then
                write_monitor_state "$_wpe_output" "$imgpath" "$wpe_thumbnail" "$wpe_thumbnail" "wpe" "$wpe_id" "$imgpath"
                systemctl --user restart "wpe@${_wpe_output}.service" 2>/dev/null || true
            fi

        elif is_video "$imgpath"; then
            [[ -z "$no_save_flag" ]] && check_and_prompt_upscale "$imgpath" &
            mkdir -p "$THUMBNAIL_DIR"

            missing_deps=()
            if ! command -v mpvpaper &> /dev/null; then
                missing_deps+=("mpvpaper")
            fi
            if ! command -v ffmpeg &> /dev/null; then
                missing_deps+=("ffmpeg")
            fi
            if [ ${#missing_deps[@]} -gt 0 ]; then
                echo "Missing deps: ${missing_deps[*]}"
                echo "Arch: sudo pacman -S ${missing_deps[*]}"
                action=$(notify-send \
                    -a "Wallpaper switcher" \
                    -c "im.error" \
                    -A "install_arch=Install (Arch)" \
                    "Can't switch to video wallpaper" \
                    "Missing dependencies: ${missing_deps[*]}")
                if [[ "$action" == "install_arch" ]]; then
                    kitty -1 sudo pacman -S "${missing_deps[*]}"
                    if command -v mpvpaper &>/dev/null && command -v ffmpeg &>/dev/null; then
                        notify-send 'Wallpaper switcher' 'Alright, try again!' -a "Wallpaper switcher"
                    fi
                fi
                exit 0
            fi

            # Set wallpaper path
            [[ -z "$no_save_flag" && -z "$noswitch_flag" ]] && set_wallpaper_path "$imgpath"

            # Set video wallpaper
            local video_path="$imgpath"
            monitors=$(hyprctl monitors -j | jq -r '.[] | .name')
            for monitor in $monitors; do
                nohup mpvpaper -o "$VIDEO_OPTS" "$monitor" "$video_path" >/dev/null 2>&1 &
                sleep 0.1
            done

            # Extract first frame for color generation
            thumbnail="$THUMBNAIL_DIR/$(basename "$imgpath").jpg"
            ffmpeg -y -i "$imgpath" -vframes 1 "$thumbnail" 2>/dev/null

            # Set thumbnail path
            set_thumbnail_path "$thumbnail"
            for monitor in $monitors; do
                write_monitor_state "$monitor" "$imgpath" "$thumbnail" "$thumbnail" "video"
            done

            if [ -f "$thumbnail" ]; then
                matugen_args=(image "$thumbnail")
                generate_colors_material_args=(--path "$thumbnail")
                create_restore_script "$video_path"
            else
                echo "Cannot create image to colorgen"
                remove_restore
                exit 1
            fi
        else
            matugen_args=(image "$imgpath")
            generate_colors_material_args=(--path "$imgpath")
            # Update wallpaper path in config
            [[ -z "$no_save_flag" && -z "$noswitch_flag" ]] && set_wallpaper_path "$imgpath"
            remove_restore

            # Iris-close transition — skipped when --noswitch (palette-only change)
            if [[ -z "$noswitch_flag" ]] && command -v awww &>/dev/null; then
                local _awww_output
                if [[ -n "$monitor_flag" ]]; then
                    _awww_output="$monitor_flag"
                else
                    _awww_output=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name' 2>/dev/null)
                fi
                ensure_awww_daemon
                awww img "$imgpath" \
                    ${_awww_output:+--outputs "$_awww_output"} \
                    --transition-type grow \
                    --transition-pos "${cursorposx},${cursorposy}" \
                    --transition-duration 0.8 \
                    --transition-fps 60 \
                    --transition-step 90

                # Write per-monitor state file
                if [[ -n "$_awww_output" ]]; then
                    write_monitor_state "$_awww_output" "$imgpath" "$imgpath" "$imgpath" "image"

                    # Stop any existing WPE service for this monitor when setting a regular wallpaper
                    systemctl --user stop "wpe@${_awww_output}.service" 2>/dev/null || true
                fi
            fi
        fi
    fi

    if [[ -z "$mode_flag" ]]; then
        config_mode="$(get_config_color_mode)"
        if [[ "$config_mode" == "dark" || "$config_mode" == "light" ]]; then
            mode_flag="$config_mode"
        fi
    fi

    # Auto-detect mode from wallpaper brightness only if config did not set it
if [[ -z "$mode_flag" && -n "$imgpath" ]]; then
    detected_mode=$(detect_brightness_mode "$imgpath")

    if [[ -n "$detected_mode" ]]; then
        mode_flag="$detected_mode"
    else
        # fallback (safe default)
        mode_flag="light"
    fi
fi

    # Apply detected mode consistently (no forcing)
if [[ -n "$mode_flag" ]]; then
    matugen_prefer="darkness"
    [[ "$mode_flag" == "light" ]] && matugen_prefer="lightness"
    if [[ "$color_flag" != "1" ]]; then
        matugen_source_path="$(resolve_matugen_source_path)"
        if [[ -n "$matugen_source_path" && "$matugen_source_path" != "null" && "$matugen_source_path" != "--restore" ]]; then
            set_matugen_wallpaper_path_file "$matugen_source_path"
            matugen_args=(image "$matugen_source_path")
            generate_colors_material_args=(--path "$matugen_source_path")
        fi
    fi
    matugen_args+=(--mode "$mode_flag" --prefer "$matugen_prefer")
    generate_colors_material_args+=(--mode "$mode_flag")
fi
    [[ -n "$type_flag" ]] && matugen_args+=(--type "$type_flag") && generate_colors_material_args+=(--scheme "$type_flag")
    generate_colors_material_args+=(--termscheme "$terminalscheme" --blend_bg_fg)
    generate_colors_material_args+=(--cache "$STATE_DIR/user/generated/color.txt")
    generate_colors_material_args+=(--json-out "$STATE_DIR/user/generated/colors.json")

    pre_process "$mode_flag"

    # Check if app and shell theming is enabled in config
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell' "$SHELL_CONFIG_FILE")
        if [ "$enable_apps_shell" == "false" ]; then
            echo "App and shell theming disabled, skipping matugen and color generation"
            return
        fi
    fi

    # Set harmony and related properties
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        harmony=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmony' "$SHELL_CONFIG_FILE")
        harmonize_threshold=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold' "$SHELL_CONFIG_FILE")
        term_fg_boost=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost' "$SHELL_CONFIG_FILE")
        [[ "$harmony" != "null" && -n "$harmony" ]] && generate_colors_material_args+=(--harmony "$harmony")
        [[ "$harmonize_threshold" != "null" && -n "$harmonize_threshold" ]] && generate_colors_material_args+=(--harmonize_threshold "$harmonize_threshold")
        [[ "$term_fg_boost" != "null" && -n "$term_fg_boost" ]] && generate_colors_material_args+=(--term_fg_boost "$term_fg_boost")
    fi

    echo "1" | matugen "${matugen_args[@]}"
    source "${ILLOGICAL_IMPULSE_VIRTUAL_ENV/#\~/$HOME}/bin/activate"
    python3 "$SCRIPT_DIR/generate_colors_material.py" "${generate_colors_material_args[@]}" \
        > "$STATE_DIR"/user/generated/material_colors.scss
    sleep 1
    touch "$STATE_DIR/user/generated/colors.json"
    bash "$SCRIPT_DIR/applycolor.sh"
    curl -X POST http://localhost:8080/reload || true
    deactivate

    # Pass screen width, height, and wallpaper path to post_process
    max_width_desired="$(hyprctl monitors -j | jq '([.[].width] | min)' | xargs)"
    max_height_desired="$(hyprctl monitors -j | jq '([.[].height] | min)' | xargs)"
    post_process "$max_width_desired" "$max_height_desired" "$imgpath"
}

main() {
    imgpath=""
    mode_flag=""
    type_flag=""
    color_flag=""
    color=""
    noswitch_flag=""
    no_save_flag=""
    monitor_flag=""
    wpe_property_args=()

    get_type_from_config() {
        jq -r '.appearance.palette.type' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "auto"
    }
    get_accent_color_from_config() {
        jq -r '.appearance.palette.accentColor' "$SHELL_CONFIG_FILE" 2>/dev/null || echo ""
    }
    set_accent_color() {
        local color="$1"
        jq --indent 4 --arg color "$color" '.appearance.palette.accentColor = $color' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    }

    detect_scheme_type_from_image() {
        local img="$1"
        source "${ILLOGICAL_IMPULSE_VIRTUAL_ENV/#\~/$HOME}/bin/activate"
        "$SCRIPT_DIR"/scheme_for_image.py "$img" 2>/dev/null | tr -d '\n'
        deactivate
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                mode_flag="$2"
                shift 2
                ;;
            --type)
                type_flag="$2"
                shift 2
                ;;
            --color)
                if [[ "$2" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
                    set_accent_color "$2"
                    shift 2
                elif [[ "$2" == "clear" ]]; then
                    set_accent_color ""
                    shift 2
                else
                    set_accent_color $(hyprpicker --no-fancy)
                    shift
                fi
                ;;
            --image)
                imgpath="$2"
                shift 2
                ;;
            --restore)
                noswitch_flag="1"
                # Restore per-monitor wallpapers from state files
                _monitors_dir="$MONITOR_STATE_DIR"
                _restored=0
                if [[ -d "$_monitors_dir" ]]; then
                    _video_restored=0
                    for _state_file in "$_monitors_dir"/*.json; do
                        [[ -f "$_state_file" ]] || continue
                        _mon=$(jq -r '.monitor // empty' "$_state_file" 2>/dev/null)
                        _path=$(jq -r '.path // empty' "$_state_file" 2>/dev/null)
                        _is_wpe=$(jq -r '.wpe // false' "$_state_file" 2>/dev/null)
                        _kind=$(jq -r '.kind // empty' "$_state_file" 2>/dev/null)
                        if [[ "$_is_wpe" == "true" && -n "$_mon" ]]; then
                            systemctl --user start "wpe@${_mon}.service" 2>/dev/null || true
                            _restored=1
                        elif [[ "$_kind" == "video" && $_video_restored -eq 0 && -x "$RESTORE_SCRIPT" ]]; then
                            "$RESTORE_SCRIPT" >/dev/null 2>&1 &
                            _video_restored=1
                            _restored=1
                        elif [[ -n "$_mon" && -n "$_path" && -f "$_path" ]]; then
                            awww img "$_path" --outputs "$_mon" --transition-type none 2>/dev/null &
                            _restored=1
                        fi
                    done
                fi
                [[ $_restored -eq 0 ]] && awww restore 2>/dev/null || true
                imgpath="$(resolve_matugen_source_path)"
                shift
                ;;
            --noswitch)
                noswitch_flag="1"
                imgpath="$(resolve_matugen_source_path)"
                shift
                ;;
            --no-save)
                no_save_flag="1"
                shift
                ;;
            --wpe-property)
                wpe_property_args+=(--property "$2" "$3")
                shift 3
                ;;
            --monitor)
                monitor_flag="$2"
                shift 2
                ;;
            *)
                if [[ -z "$imgpath" ]]; then
                    imgpath="$1"
                fi
                shift
                ;;
        esac
    done

    # If accentColor is set in config, use it
    config_color="$(get_accent_color_from_config)"
    if [[ "$config_color" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
        color_flag="1"
        color="$config_color"
    fi

    # If type_flag is not set, get it from config
    if [[ -z "$type_flag" ]]; then
        type_flag="$(get_type_from_config)"
    fi

    # Validate type_flag (allow 'auto' as well)
    allowed_types=(scheme-content scheme-expressive scheme-fidelity scheme-fruit-salad scheme-monochrome scheme-neutral scheme-rainbow scheme-tonal-spot auto)
    valid_type=0
    for t in "${allowed_types[@]}"; do
        if [[ "$type_flag" == "$t" ]]; then
            valid_type=1
            break
        fi
    done
    if [[ $valid_type -eq 0 ]]; then
        echo "[switchwall.sh] Warning: Invalid type '$type_flag', defaulting to 'auto'" >&2
        type_flag="auto"
    fi

    # Only prompt for wallpaper if not using --color and not using --noswitch and no imgpath set
    if [[ -z "$imgpath" && -z "$color_flag" && -z "$noswitch_flag" ]]; then
        cd "$(xdg-user-dir PICTURES)/Wallpapers/showcase" 2>/dev/null || cd "$(xdg-user-dir PICTURES)/Wallpapers" 2>/dev/null || cd "$(xdg-user-dir PICTURES)" || return 1
        imgpath="$(kdialog --getopenfilename . --title 'Choose wallpaper')"
    fi

    if [[ -n "$imgpath" && -z "$noswitch_flag" ]]; then
        set_accent_color ""
        color_flag=""
        color=""
    fi

    # If type_flag is 'auto', detect scheme type from image (after imgpath is set)
    if [[ "$type_flag" == "auto" ]]; then
        type_detection_path="$imgpath"
        effective_monitor="${monitor_flag:-$(get_focused_monitor_name)}"
        if [[ -n "$PREFERRED_MATUGEN_MONITOR" && "$effective_monitor" != "$PREFERRED_MATUGEN_MONITOR" ]]; then
            preferred_detection_path="$(get_monitor_state_path "$PREFERRED_MATUGEN_MONITOR")"
            if [[ -n "$preferred_detection_path" && -f "$preferred_detection_path" ]]; then
                type_detection_path="$preferred_detection_path"
            fi
        fi
        if [[ -n "$type_detection_path" && -f "$type_detection_path" ]]; then
            detected_type="$(detect_scheme_type_from_image "$type_detection_path")"
            # Only use detected_type if it's valid
            valid_detected=0
            for t in "${allowed_types[@]}"; do
                if [[ "$detected_type" == "$t" && "$detected_type" != "auto" ]]; then
                    valid_detected=1
                    break
                fi
            done
            if [[ $valid_detected -eq 1 ]]; then
                type_flag="$detected_type"
            else
                echo "[switchwall] Warning: Could not auto-detect a valid scheme, defaulting to 'scheme-tonal-spot'" >&2
                type_flag="scheme-content"
            fi
        else
            echo "[switchwall] Warning: No image to auto-detect scheme from, defaulting to 'scheme-tonal-spot'" >&2
            type_flag="scheme-content"
        fi
    fi

    switch "$imgpath" "$mode_flag" "$type_flag" "$color_flag" "$color" "$monitor_flag"
}

main "$@"
