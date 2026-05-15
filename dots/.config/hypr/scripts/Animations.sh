#!/usr/bin/env bash
# Animations preset manager for Quickshell animations picker
ANIM_DIR="$HOME/.config/hypr/animations"
STATE="$HOME/.local/state/quickshell/user/active-animation"

case "$1" in
    list)
        for f in "$ANIM_DIR"/*.lua; do
            [[ -f "$f" ]] && basename "$f" .lua
        done | sort
        ;;
    active)
        cat "$STATE" 2>/dev/null
        ;;
    preview)
        # Output pipe-delimited info for each preset
        # Format: name|x1|y1|x2|y2|speed|style
        # For spring curves, outputs approximated bezier values
        for f in "$ANIM_DIR"/*.lua; do
            [[ -f "$f" ]] || continue
            name=$(basename "$f" .lua)

            # Check if preset is disabled (global disabled)
            disabled=$(grep -P 'leaf\s*=\s*"global"' "$f" | grep -c 'enabled\s*=\s*false')
            [[ "$disabled" -gt 0 ]] && { echo "${name}|0.25|0.1|0.25|1.0|0|slide"; continue; }

            # Get windowsIn animation (or windows fallback)
            anim_line=$(grep -P 'leaf\s*=\s*"windowsIn"' "$f" | head -1)
            [[ -z "$anim_line" ]] && anim_line=$(grep -P 'leaf\s*=\s*"windows"' "$f" | head -1)

            # Parse speed from: speed = <number>
            speed=$(echo "$anim_line" | grep -oP 'speed\s*=\s*\K[\d.]+' | head -1)
            [[ -z "$speed" ]] && speed="4"

            # Parse style
            style=$(echo "$anim_line" | grep -oP 'style\s*=\s*"\K[^"]+' | head -1)
            [[ -z "$style" ]] && style="slide"
            style_base=$(echo "$style" | awk '{print $1}')

            # Parse bezier name
            bezier_name=$(echo "$anim_line" | grep -oP 'bezier\s*=\s*"\K[^"]+' | head -1)

            x1="0.25"; y1="0.1"; x2="0.25"; y2="1.0"
            if [[ -n "$bezier_name" && "$bezier_name" != "default" ]]; then
                # Find hl.curve("name", { type = "bezier", points = { {x1,y1},{x2,y2} } })
                curve_line=$(grep -P "hl\.curve\(\s*\"${bezier_name}\"" "$f" | head -1)
                if [[ -n "$curve_line" ]]; then
                    # Extract all numbers from points block
                    nums=$(echo "$curve_line" | grep -oP '[\d.-]+' | tail -n +2)
                    x1=$(echo "$nums" | sed -n '1p')
                    y1=$(echo "$nums" | sed -n '2p')
                    x2=$(echo "$nums" | sed -n '3p')
                    y2=$(echo "$nums" | sed -n '4p')
                    [[ -z "$x1" ]] && x1="0.25"
                    [[ -z "$y1" ]] && y1="0.1"
                    [[ -z "$x2" ]] && x2="0.25"
                    [[ -z "$y2" ]] && y2="1.0"
                fi
            fi

            echo "${name}|${x1}|${y1}|${x2}|${y2}|${speed}|${style_base}"
        done | sort
        ;;
    apply)
        preset="$2"
        lua_file="$ANIM_DIR/${preset}.lua"
        if [[ ! -f "$lua_file" ]]; then
            echo "Preset not found: $preset" >&2
            exit 1
        fi

        cp "$lua_file" "$HOME/.config/hypr/animations.lua"

        mkdir -p "$(dirname "$STATE")"
        echo "$preset" > "$STATE"

        hyprctl reload
        ;;
    *)
        echo "Usage: $0 {list|apply <preset>|active|preview}" >&2
        exit 1
        ;;
esac
