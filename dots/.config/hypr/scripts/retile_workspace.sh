#!/bin/bash
# Force-retile all tiled windows on the active workspace by moving them to a
# scratch workspace and back in a single hyprctl --batch call.
# Called by SUPER+ALT+L after MULTILAYOUT_CURRENT is updated in Lua.

WS=$(hyprctl activeworkspace -j | jq '.id')
FOCUSED=$(hyprctl activewindow -j | jq -r '.address // empty')

ADDRS=$(hyprctl clients -j | jq -r --argjson ws "$WS" \
    '.[] | select(.workspace.id == $ws and .floating == false) | .address')

[ -z "$ADDRS" ] && exit 0

BATCH=""
while IFS= read -r addr; do
    BATCH="${BATCH}dispatch movetoworkspacesilent 9998,address:${addr} ; "
done <<< "$ADDRS"
while IFS= read -r addr; do
    BATCH="${BATCH}dispatch movetoworkspacesilent ${WS},address:${addr} ; "
done <<< "$ADDRS"
if [ -n "$FOCUSED" ]; then
    BATCH="${BATCH}dispatch focuswindow address:${FOCUSED}"
fi

hyprctl --batch "$BATCH"
