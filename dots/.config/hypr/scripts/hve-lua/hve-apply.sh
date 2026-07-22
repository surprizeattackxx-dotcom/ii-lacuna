#!/usr/bin/env bash
# Hyprland Visual Editor → Lua bridge.
# Convert the HVE overlay into Lua (hl.* API), persist it so it survives reloads,
# and apply it live to the running session. Arg 1 optionally overrides the overlay path.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="${1:-$HOME/.cache/noctalia/HVE/overlay.conf}"
COLORS="$HOME/.config/hypr/noctalia/noctalia-colors.conf"
OUT="$HOME/.config/hypr/hyprland/hve.lua"

LUA="$(python3 "$HERE/hve2lua.py" "$OVERLAY" "$COLORS")"

# Persist for next Hyprland start (dofile'd by hyprland.lua).
printf '%s\n' "$LUA" > "$OUT"

# Apply to the running session now. Strip `--` comment lines first: hyprctl would
# otherwise treat a leading "-- ..." argument as a flag and bail to usage.
EVAL_LUA="$(printf '%s\n' "$LUA" | grep -v '^[[:space:]]*--')"
[ -n "$EVAL_LUA" ] && hyprctl eval "$EVAL_LUA" >/dev/null 2>&1
exit 0
