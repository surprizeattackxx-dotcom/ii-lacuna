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
RAW_JSON_PATH="/tmp/quickshell/ai/theme-raw.json"
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

# Required Material 3 keys — Catppuccin aliases are derived locally afterwards
M3_KEYS=(
    background surface surface_dim surface_bright
    surface_container_lowest surface_container_low surface_container surface_container_high surface_container_highest
    surface_variant surface_tint
    on_background on_surface on_surface_variant
    primary primary_container primary_fixed primary_fixed_dim
    on_primary on_primary_container on_primary_fixed on_primary_fixed_variant
    secondary secondary_container secondary_fixed secondary_fixed_dim
    on_secondary on_secondary_container on_secondary_fixed on_secondary_fixed_variant
    tertiary tertiary_container tertiary_fixed tertiary_fixed_dim
    on_tertiary on_tertiary_container on_tertiary_fixed on_tertiary_fixed_variant
    error error_container on_error on_error_container
    outline outline_variant
    shadow scrim
    inverse_surface inverse_on_surface inverse_primary
    success on_success success_container on_success_container
)

# Analyze the wallpaper (reuses scheme_for_image.py) so Gemini knows whether
# to go muted or punchy instead of guessing from a 400px thumbnail alone
STATS_LINE=""
if [[ -x "$VENV_PYTHON" && -f "$SCRIPT_DIR/scheme_for_image.py" ]]; then
    CF=$("$VENV_PYTHON" "$SCRIPT_DIR/scheme_for_image.py" "$RESIZED_IMG_PATH" --colorfulness 2>/dev/null)
    BR=$("$VENV_PYTHON" "$SCRIPT_DIR/scheme_for_image.py" "$RESIZED_IMG_PATH" --brightness 2>/dev/null)
    if [[ "$CF" =~ ^[0-9.]+$ && "$BR" =~ ^[0-9.]+$ ]]; then
        CVIBE=$(awk -v c="$CF" 'BEGIN{
            if (c<20) print "near-greyscale and very muted: keep the palette subdued and low-saturation with one gentle accent";
            else if (c<40) print "low colour: favour soft neutral tones with restrained accents";
            else if (c<70) print "moderately colourful: aim for a balanced, naturalistic palette";
            else if (c<100) print "vivid: use expressive, saturated accents";
            else print "extremely colourful: go bold with punchy high-chroma accents";
        }')
        BVIBE=$(awk -v b="$BR" 'BEGIN{
            if (b<64) print "very dark"; else if (b<128) print "dark";
            else if (b<200) print "bright"; else print "very bright";
        }')
        STATS_LINE="Image analysis: colorfulness ${CF} (${CVIBE}). Average brightness ${BR}/255 (${BVIBE} image)."
    fi
fi

# Respect the configured color mode instead of hardcoding dark
MODE_PREF=$(jq -r '.appearance.colorMode // "dark"' "$SHELL_CONFIG_FILE" 2>/dev/null)
[[ "$MODE_PREF" == "light" ]] || MODE_PREF="dark"
if [[ "$MODE_PREF" == "dark" ]]; then
    MODE_RULES='- dark theme: background deep (~#101018 territory, tinted with the wallpaper hue, not pure black); surfaces deep but not pure black; on_* colors light'
else
    MODE_RULES='- light theme: background near-white (~#f6f2fb territory, tinted with the wallpaper hue, not pure white); surfaces light; on_* colors dark'
fi

PROMPT="You are a Material 3 color scheme generator. Study this wallpaper and generate a cohesive ${MODE_PREF} Material 3 color palette that captures its mood and dominant colors.
${STATS_LINE}

Fill every key in the response schema with a hex color in #rrggbb lowercase format.

Rules:
${MODE_RULES}
- primary should be the most distinctive/accent color from the wallpaper
- secondary and tertiary should harmonize — analogous or complementary to primary
- surface_container_lowest through surface_container_highest must form a smooth, evenly spaced tonal ramp tinted with the primary hue
- every on_* color must contrast clearly (WCAG >= 4.5) against its counterpart
- error stays reddish and success stays greenish, both tinted to fit the palette
- Extract actual colors from the wallpaper, dont invent them"

M3_KEYS_JSON=$(printf '%s\n' "${M3_KEYS[@]}" | jq -R . | jq -s .)
SCHEMA=$(jq -n --argjson keys "$M3_KEYS_JSON" \
    '{type: "OBJECT", properties: ($keys | map({(.): {type: "STRING"}}) | add), required: $keys}')

payload=$(jq -n \
    --arg b64 "$B64DATA" \
    --arg prompt "$PROMPT" \
    --argjson schema "$SCHEMA" \
    '{
        contents: [{
            parts: [
                { inline_data: { mime_type: "image/jpeg", data: $b64 } },
                { text: $prompt }
            ]
        }],
        generationConfig: {
            responseMimeType: "application/json",
            responseSchema: $schema,
            temperature: 0.3
        }
    }')

mkdir -p "$(dirname "$COLORS_JSON")"
export M3_KEYS_STR="${M3_KEYS[*]}"

# Validate, contrast-fix, alias, and write colors.json; exits 1 on bad input
validate_and_write() {
    python3 - "$RAW_JSON_PATH" "$COLORS_JSON" << 'PYEOF'
import json, os, re, sys

req = os.environ["M3_KEYS_STR"].split()
ALIASES = {
    "mauve": "primary", "blue": "secondary", "teal": "tertiary", "red": "error",
    "base": "background", "mantle": "surface_container_low",
    "text": "on_surface", "subtext0": "on_surface_variant",
    "overlay0": "outline", "overlay1": "surface_container_high",
    "surface0": "surface_container", "surface1": "surface_container_high",
    "surface2": "surface_container_highest",
}

def norm(v):
    if not isinstance(v, str):
        return None
    v = v.strip().lower()
    m = re.fullmatch(r'#?([0-9a-f]{6})', v)
    if m:
        return '#' + m.group(1)
    m = re.fullmatch(r'#?([0-9a-f]{3})', v)
    if m:
        return '#' + ''.join(c * 2 for c in m.group(1))
    return None

def rgb(h):
    return tuple(int(h[i:i+2], 16) for i in (1, 3, 5))

def lum(h):
    def f(c):
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = rgb(h)
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

def blend(a, b, t):
    ra, rb = rgb(a), rgb(b)
    return '#%02x%02x%02x' % tuple(round(ra[i] + (rb[i] - ra[i]) * t) for i in range(3))

with open(sys.argv[1]) as f:
    raw = json.load(f)

d = {}
for k in req:
    v = norm(raw.get(k))
    if v is None:
        print(f"[Gemini] invalid/missing key: {k} = {raw.get(k)!r}", file=sys.stderr)
        sys.exit(1)
    d[k] = v

# Repair only clearly broken pairs (< 3.0); push them to a readable 4.5
for k in req:
    if not k.startswith('on_'):
        continue
    base = k[3:]
    if base not in d or ratio(d[k], d[base]) >= 3.0:
        continue
    target = max(('#000000', '#ffffff'), key=lambda c: ratio(c, d[base]))
    fixed = d[k]
    for _ in range(12):
        fixed = blend(fixed, target, 0.15)
        if ratio(fixed, d[base]) >= 4.5:
            break
    d[k] = fixed

for alias, src in ALIASES.items():
    d[alias] = d[src]

with open(sys.argv[2], 'w') as f:
    json.dump(d, f, indent=4)
PYEOF
}

echo "[Gemini] Sending wallpaper to Gemini ($MODEL)..." >&2

ok=""
for attempt in 1 2; do
    response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent" \
        -H "x-goog-api-key: $API_KEY" \
        -H 'Content-Type: application/json' \
        -X POST \
        -d "$payload")

    generated=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
    if [[ -z "$generated" ]]; then
        echo "[Gemini] Attempt $attempt: empty response." >&2
        echo "$response" | jq -r '.error.message // empty' >&2
        continue
    fi

    if ! printf '%s' "$generated" | jq -e . > "$RAW_JSON_PATH" 2>/dev/null; then
        echo "[Gemini] Attempt $attempt: invalid JSON." >&2
        continue
    fi

    if validate_and_write; then
        ok=1
        break
    fi
    echo "[Gemini] Attempt $attempt: palette failed validation, retrying..." >&2
done

if [[ -z "$ok" ]]; then
    echo "Error: Gemini did not return a usable palette after 2 attempts." >&2
    exit 1
fi

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
        --color "$PRIMARY" --mode "$MODE_PREF" \
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
