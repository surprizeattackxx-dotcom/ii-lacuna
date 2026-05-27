#!/bin/bash
# Apply a custom or built-in theme JSON, theming GTK4, Kitty, Rofi, Hyprland, and terminal.
# Usage: apply_custom_theme.sh <theme.json> [THEME_NAME]
THEME_FILE="$1"
THEME_NAME="${2:-}"
[[ -z "$THEME_FILE" || ! -f "$THEME_FILE" ]] && { echo "Usage: apply_custom_theme.sh <theme.json>" >&2; exit 1; }

declare -A KDE_SCHEME=(
    [Mocha]="CatppuccinMochaMauve"
    [Frappe]="CatppuccinFrappeMauve"
    [Latte]="CatppuccinLatteMauve"
    [Macchiato]="CatppuccinMacchiatoMauve"
    [Dracula]="Dracula-kde"
    [Nord]="Nordic"
    [Rose_pine]="RosePineMoon"
    [Gruvbox]="GruvboxColors"
    [Glass]="kvGlass"
    [Kanagawa]="KanagawaWave"
    [Rose_pine_dawn]="RosePineDawn"
    [Solarized_light]="SolarizedLight"
    [Everforest_light]="Everforest-Light-Medium"
    [Ayu_light]="Ayu-Light"
    [One_light]="OneLight"
)

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
STATE_DIR="$XDG_STATE_HOME/quickshell"
VENV_PYTHON="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}/bin/python3"
VENV_PYTHON="${VENV_PYTHON/#\~/$HOME}"
COLORS_JSON="$STATE_DIR/user/generated/colors.json"
SCSS_FILE="$STATE_DIR/user/generated/material_colors.scss"
TERMSCHEME="$SCRIPT_DIR/terminal/scheme-base.json"

mkdir -p "$(dirname "$COLORS_JSON")"

# Catppuccin → M3 key mapping so MaterialThemeLoader's applyColors matches m3colors properties
python3 - "$THEME_FILE" > "$COLORS_JSON" << 'PYMAP'
import json, sys

CATPPUCCIN_TO_M3 = {
    "base": "background", "mantle": "surface_container_low", "crust": "surface_container_lowest",
    "text": "on_surface", "subtext0": "on_surface_variant", "subtext1": "outline",
    "surface0": "surface_container", "surface1": "surface_container_high",
    "surface2": "surface_container_highest",
    "overlay0": "outline", "overlay1": "outline_variant", "overlay2": "surface_variant",
    "mauve": "primary", "blue": "primary", "sapphire": "secondary",
    "peach": "tertiary", "green": "success", "red": "error",
    "teal": "success", "pink": "secondary", "yellow": "tertiary", "maroon": "error",
    "rosewater": "tertiary", "flamingo": "error", "sky": "secondary",
    "lavender": "primary", "white": "on_surface"
}

with open(sys.argv[1]) as f:
    raw = json.load(f)

# Start with all original keys
out = dict(raw)

# Only fill missing M3 keys from Catppuccin aliases
for k, v in raw.items():
    m3_key = CATPPUCCIN_TO_M3.get(k, k)
    if m3_key != k and m3_key not in raw and isinstance(v, str) and v.startswith("#"):
        out[m3_key] = v

# Ensure common M3 surface keys that MaterialThemeLoader needs
for fallback_m3, fallback_ctp in [("surface", "base"), ("surface_dim", "base"),
    ("surface_bright", "base"),
    ("on_background", "text"), ("on_surface", "text"),
    ("on_primary", "white"), ("on_secondary", "white"), ("on_tertiary", "white"),
    ("on_error", "white"), ("on_success", "white"),
    ("primary_container", "mauve"), ("secondary_container", "sapphire"),
    ("tertiary_container", "peach"), ("error_container", "red"),
    ("success_container", "green"),
    ("inverse_surface", "crust"), ("inverse_on_surface", "text"),
    ("inverse_primary", "mauve"),
    ("scrim", "crust"), ("shadow", "crust"),
    ("on_surface_variant", "subtext0")]:
    if fallback_m3 not in out and fallback_ctp in raw:
        out[fallback_m3] = raw[fallback_ctp]

json.dump(out, sys.stdout, indent=2)
PYMAP

# Detect dark/light mode from background color lightness
BG=$(jq -r '.background // "#1e1e2e"' "$COLORS_JSON")
R=$(( 16#${BG:1:2} )); G=$(( 16#${BG:3:2} )); B=$(( 16#${BG:5:2} ))
L=$(( (R + G + B) / 3 ))
[[ $L -lt 128 ]] && MODE="dark" || MODE="light"

# Set GNOME color-scheme so system-wide dark/light is consistent
if [[ "$MODE" == "dark" ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' 2>/dev/null
fi

# Sync colorMode in shell config so switchwall.sh picks up the correct mode
SHELL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
if [[ -f "$SHELL_CONFIG" ]]; then
    jq --indent 4 --arg mode "$MODE" '.appearance.colorMode = $mode' "$SHELL_CONFIG" \
        > "$SHELL_CONFIG.tmp" && mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
fi

# Convert theme JSON colors → camelCase SCSS variables (preserving actual theme colors)
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

# Append terminal colors (term0-term15)
# If the theme JSON already has term0..term15, use those directly (skip Python generation)
PRIMARY=$(jq -r '.primary // "#ffffff"' "$COLORS_JSON")
if jq -e '.term0' "$COLORS_JSON" > /dev/null 2>&1; then
    : # term colors already in SCSS via the Python conversion above — skip generator
elif [[ -f "$TERMSCHEME" && -x "$VENV_PYTHON" ]]; then
    "$VENV_PYTHON" "$SCRIPT_DIR/generate_colors_material.py" \
        --color "$PRIMARY" --mode "$MODE" \
        --termscheme "$TERMSCHEME" --blend_bg_fg 2>/dev/null \
        | grep -E '^\$term[0-9]+:' >> "$SCSS_FILE"
fi

# Apply all colors: GTK4, Kitty, Rofi, Hyprland borders, terminal sequences
bash "$SCRIPT_DIR/applycolor.sh"

# Theme Qt/KDE apps via color scheme (non-Matugen) or dynamic kde-material-you-colors (Matugen)
VENV_DIR="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}"
VENV_DIR="${VENV_DIR/#\~/$HOME}"
KDE_BIN="$VENV_DIR/bin/kde-material-you-colors"
KDE_DYNAMIC() {
    [[ ! -x "$KDE_BIN" ]] && return
    printf '%s' "${PRIMARY#\#}" > "$COLOR_TXT"
    [[ "$MODE" == "dark" ]] && KDE_MODE_FLAG="-d" || KDE_MODE_FLAG="-l"
    "$KDE_BIN" "$KDE_MODE_FLAG" --color "${PRIMARY#\#}" -sv 5 &
}

if [[ "$THEME_NAME" == "Matugen" || -z "$THEME_NAME" ]]; then
    KDE_DYNAMIC
elif [[ -n "${KDE_SCHEME[$THEME_NAME]+_}" ]]; then
    plasma-apply-colorscheme "${KDE_SCHEME[$THEME_NAME]}"
else
    KDE_DYNAMIC
fi

