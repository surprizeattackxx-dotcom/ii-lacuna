#!/usr/bin/env bash
# Generate a Material 3 color scheme from the current wallpaper using Gemini AI.
# Writes colors.json + material_colors.scss, runs applycolor.sh.

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
STATE_DIR="$XDG_STATE_HOME/quickshell"
COLORS_JSON="$STATE_DIR/user/generated/colors.json"
SCSS_FILE="$STATE_DIR/user/generated/material_colors.scss"
WALLPAPER_PATH_FILE="$STATE_DIR/user/generated/wallpaper/path.txt"
SHELL_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
TERMSCHEME="$SCRIPT_DIR/terminal/scheme-base.json"
VENV_PYTHON="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}/bin/python3"
VENV_PYTHON="${VENV_PYTHON/#\~/$HOME}"
RESIZED_IMG_PATH="/tmp/quickshell/ai/theme-wallpaper.jpg"
MODEL="${GEMINI_THEME_MODEL:-gemini-3.1-flash-lite}"
MONITOR_STATE_DIR="$STATE_DIR/user/generated/wallpaper/monitors"

# Parse --monitor argument
TARGET_MONITOR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --monitor) TARGET_MONITOR="$2"; shift 2 ;;
        *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
done

# Resolve the wallpaper path — prefers the specified monitor's wallpaper
resolve_wallpaper_path() {
    local monitor="$1"
    local path=""

    # 1. If a monitor is specified, check its state file first
    if [[ -n "$monitor" ]]; then
        local mon_state="$MONITOR_STATE_DIR/${monitor}.json"
        if [[ -f "$mon_state" ]]; then
            path="$(jq -r '.matugenPath // .thumbnailPath // .previewPath // .path // empty' "$mon_state" 2>/dev/null)"
        fi
    fi

    # 2. Fall back to path.txt (Matugen's generic path)
    if [[ -z "$path" || "$path" == "null" ]]; then
        if [[ -f "$WALLPAPER_PATH_FILE" ]]; then
            path="$(<"$WALLPAPER_PATH_FILE")"
        fi
    fi

    # 3. Config wallpaperPath
    if [[ -z "$path" || "$path" == "null" ]]; then
        path="$(jq -r '.background.wallpaperPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null)"
    fi

    # 4. Any monitor state file as last resort
    if [[ -z "$path" || "$path" == "null" ]]; then
        if [[ -d "$MONITOR_STATE_DIR" ]]; then
            local state_file
            state_file="$(find "$MONITOR_STATE_DIR" -name "*.json" 2>/dev/null | sort | head -1)"
            if [[ -n "$state_file" ]]; then
                path="$(jq -r '.matugenPath // .thumbnailPath // .previewPath // .path // empty' "$state_file" 2>/dev/null)"
            fi
        fi
    fi

    printf '%s\n' "$path"
}

IMGPATH="$(resolve_wallpaper_path "$TARGET_MONITOR")"
if [[ -z "$IMGPATH" || "$IMGPATH" == "null" ]]; then
    echo "Error: No wallpaper path found." >&2
    exit 1
fi

# Get API key
API_KEY=$(secret-tool lookup 'application' 'illogical-impulse' | jq -r '.apiKeys.gemini')
if [[ -z "$API_KEY" || "$API_KEY" == "null" ]]; then
    echo "Error: Gemini API key not found." >&2
    exit 1
fi

# Resize image for speed
mkdir -p "$(dirname "$RESIZED_IMG_PATH")"
magick "$IMGPATH" -thumbnail 400x -quality 60 "$RESIZED_IMG_PATH"

if [[ "$(base64 --version 2>&1)" = *"FreeBSD"* ]]; then
    B64FLAGS="--input"
else
    B64FLAGS="-w0"
fi
B64DATA="$(base64 "$B64FLAGS" "$RESIZED_IMG_PATH")"

# Prompt: asks Gemini to study the wallpaper and produce M3 colors
PROMPT='You are a Material 3 color scheme generator. Study this wallpaper and generate a cohesive dark Material 3 color palette that captures its mood and dominant colors.

Return ONLY a JSON object with these exact keys — all hex colors in #rrggbb lowercase format, dark theme:

background, surface, surface_dim, surface_bright,
surface_container_lowest, surface_container_low, surface_container, surface_container_high, surface_container_highest,
surface_variant, surface_tint,
on_background, on_surface, on_surface_variant,
primary, primary_container, primary_fixed, primary_fixed_dim,
on_primary, on_primary_container, on_primary_fixed, on_primary_fixed_variant,
secondary, secondary_container, secondary_fixed, secondary_fixed_dim,
on_secondary, on_secondary_container, on_secondary_fixed, on_secondary_fixed_variant,
tertiary, tertiary_container, tertiary_fixed, tertiary_fixed_dim,
on_tertiary, on_tertiary_container, on_tertiary_fixed, on_tertiary_fixed_variant,
error, error_container, on_error, on_error_container,
outline, outline_variant,
shadow, scrim,
inverse_surface, inverse_on_surface, inverse_primary,
success, on_success, success_container, on_success_container

Plus these Catppuccin aliases (same hex values as their M3 counterparts):
mauve=primary, blue=secondary, teal=tertiary, red=error,
base=background, mantle=surface_container_low, text=on_surface, subtext0=on_surface_variant,
overlay0=outline, overlay1=surface_container_high, surface0=surface_container, surface1=surface_container_high, surface2=surface_container_highest

Rules:
- dark theme (background ~#0f0a1a range, not light)
- primary should be the most distinctive/accent color from the wallpaper
- secondary, tertiary should harmonize — analogous or complementary to primary
- surfaces should be deep but not pure black
- on_* colors must contrast well against their container
- Extract actual colors from the wallpaper, dont invent them'

payload=$(jq -n \
    --arg b64 "$B64DATA" \
    --arg prompt "$PROMPT" \
    '{
        contents: [{
            parts: [
                { inline_data: { mime_type: "image/jpeg", data: $b64 } },
                { text: $prompt }
            ]
        }],
        generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.3
        }
    }')

echo "[Gemini] Sending wallpaper to Gemini ($MODEL)..." >&2

response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent" \
    -H "x-goog-api-key: $API_KEY" \
    -H 'Content-Type: application/json' \
    -X POST \
    -d "$payload")

generated=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null)

if [[ -z "$generated" || "$generated" == "null" ]]; then
    echo "Error: Gemini returned empty response." >&2
    echo "$response" | jq '.' >&2
    exit 1
fi

echo "$generated" | jq '.' > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Error: Invalid JSON from Gemini." >&2
    echo "$generated" >&2
    exit 1
fi

# Write colors.json
mkdir -p "$(dirname "$COLORS_JSON")"
echo "$generated" | jq '.' > "$COLORS_JSON"

# Generate SCSS from colors.json (same camelCase conversion as apply_custom_theme.sh)
python3 - "$COLORS_JSON" > "$SCSS_FILE" << 'PYEOF'
import json, re, sys

def snake_to_camel(name):
    return re.sub(r'_([a-z])', lambda m: m.group(1).upper(), name)

with open(sys.argv[1]) as f:
    d = json.load(f)

for k, v in d.items():
    if isinstance(v, str) and v.startswith('#'):
        print(f"${snake_to_camel(k)}: {v};")
PYEOF

# Append terminal colors if scheme-base.json and venv exist
PRIMARY=$(jq -r '.primary // "#ffffff"' "$COLORS_JSON")
if jq -e '.term0' "$COLORS_JSON" > /dev/null 2>&1; then
    : # already in SCSS
elif [[ -f "$TERMSCHEME" && -x "$VENV_PYTHON" ]]; then
    "$VENV_PYTHON" "$SCRIPT_DIR/generate_colors_material.py" \
        --color "$PRIMARY" --mode "dark" \
        --termscheme "$TERMSCHEME" --blend_bg_fg 2>/dev/null \
        | grep -E '^\$term[0-9]+:' >> "$SCSS_FILE"
fi

# Detect dark/light mode from background color lightness
BG=$(jq -r '.background // "#1e1e2e"' "$COLORS_JSON")
R=$(( 16#${BG:1:2} )); G=$(( 16#${BG:3:2} )); B=$(( 16#${BG:5:2} ))
L=$(( (R + G + B) / 3 ))
[[ $L -lt 128 ]] && MODE="dark" || MODE="light"

# Sync colorMode in shell config
jq --indent 4 --arg mode "$MODE" '.appearance.colorMode = $mode' "$SHELL_CONFIG_FILE" \
    > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"

# Also write to per-monitor color caches so focus switching doesn't revert
MONITOR_STATE_DIR="$STATE_DIR/user/generated/wallpaper/monitors"
if [[ -d "$MONITOR_STATE_DIR" ]]; then
    for _moncolors in "$MONITOR_STATE_DIR"/*-colors.json; do
        [[ -f "$_moncolors" ]] || continue
        cp "$COLORS_JSON" "$_moncolors"
    done
fi

# Apply all colors: GTK4, Kitty, Rofi, Hyprland borders, terminal sequences
bash "$SCRIPT_DIR/applycolor.sh"

# GNOME color-scheme
if [[ "$MODE" == "dark" ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' 2>/dev/null
fi

# Theme Qt/KDE apps via MTYC's color scheme generator directly (no daemon)
VENV_DIR="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}"
VENV_DIR="${VENV_DIR/#\~/$HOME}"
if [[ -x "$VENV_DIR/bin/python3" ]]; then
    "$VENV_DIR/bin/python3" "$SCRIPT_DIR/mtyc_apply.py" "${PRIMARY}" "$MODE"
fi

echo "[Gemini] Theme generated and applied from: $IMGPATH"
