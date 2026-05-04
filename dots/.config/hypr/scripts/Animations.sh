#!/usr/bin/env bash
# Animations preset manager for Quickshell animations picker
ANIM_DIR="$HOME/.config/hypr/animations"
TARGET="$HOME/.config/hypr/hyprland/general.conf"
STATE="$HOME/.local/state/quickshell/user/active-animation"

case "$1" in
    list)
        for f in "$ANIM_DIR"/*.conf; do
            [[ -f "$f" ]] && basename "$f" .conf
        done | sort
        ;;
    active)
        cat "$STATE" 2>/dev/null
        ;;
    preview)
        # Output JSON with bezier + animation info for each preset
        # Format: {"name": "...", "bezier": [x1,y1,x2,y2], "speed": N, "style": "slide|popin|fade", "enabled": true}
        for f in "$ANIM_DIR"/*.conf; do
            [[ -f "$f" ]] || continue
            name=$(basename "$f" .conf)
            enabled=$(grep -m1 'enabled\s*=' "$f" | grep -oP '(?:true|1|yes)' | head -1)
            [[ -z "$enabled" ]] && enabled="true"

            # Get windowsIn animation line (or fallback to windows)
            anim_line=$(grep -P '^\s*animation\s*=\s*windowsIn\b' "$f" | head -1)
            [[ -z "$anim_line" ]] && anim_line=$(grep -P '^\s*animation\s*=\s*windows\b' "$f" | head -1)

            # Parse: animation = name, on, speed, bezier_name, style
            speed=$(echo "$anim_line" | awk -F',' '{gsub(/^[ \t]+/,"",$3); print $3}')
            bezier_name=$(echo "$anim_line" | awk -F',' '{gsub(/^[ \t]+/,"",$4); gsub(/[ \t]+$/,"",$4); print $4}')
            style=$(echo "$anim_line" | awk -F',' '{gsub(/^[ \t]+/,"",$5); gsub(/[ \t#]+.*/,"",$5); print $5}')

            [[ -z "$speed" ]] && speed="4"
            [[ -z "$style" ]] && style="slide"
            # Strip any % from popin style
            style_base=$(echo "$style" | awk '{print $1}')

            # Find the bezier curve values
            if [[ -n "$bezier_name" && "$bezier_name" != "default" ]]; then
                bezier_vals=$(grep -P "^\s*bezier\s*=\s*${bezier_name}\b" "$f" | head -1 | \
                    sed 's/.*=\s*[^,]*,//' | sed 's/#.*//' | tr -d ' ')
            fi
            # Default bezier if not found
            [[ -z "$bezier_vals" ]] && bezier_vals="0.25,0.1,0.25,1.0"

            # Parse into 4 values
            x1=$(echo "$bezier_vals" | cut -d',' -f1)
            y1=$(echo "$bezier_vals" | cut -d',' -f2)
            x2=$(echo "$bezier_vals" | cut -d',' -f3)
            y2=$(echo "$bezier_vals" | cut -d',' -f4)

            echo "${name}|${x1}|${y1}|${x2}|${y2}|${speed}|${style_base}"
        done | sort
        ;;
    apply)
        preset="$2"
        conf="$ANIM_DIR/${preset}.conf"
        if [[ ! -f "$conf" ]]; then
            echo "Preset not found: $preset" >&2
            exit 1
        fi

        new_block=$(cat "$conf")

        awk -v block="$new_block" '
            /^animations \{/ { skip=1; print block; next }
            /^# END_ANIMATIONS/ { skip=0; print; next }
            !skip { print }
        ' "$TARGET" > "${TARGET}.tmp" && mv "${TARGET}.tmp" "$TARGET"

        mkdir -p "$(dirname "$STATE")"
        echo "$preset" > "$STATE"

        hyprctl reload
        ;;
    *)
        echo "Usage: $0 {list|apply <preset>|active|preview}" >&2
        exit 1
        ;;
esac
