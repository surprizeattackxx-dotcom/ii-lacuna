#!/bin/bash
# Boot-time workspace placement: ws 11 → 2nd active monitor, ws 21 → 3rd, focus 1st.
mapfile -t MONS < <(hyprctl monitors -j | jq -r '.[].name' | head -3)
[[ ${#MONS[@]} -ge 2 ]] && hyprctl dispatch moveworkspacetomonitor 11 "${MONS[1]}"
[[ ${#MONS[@]} -ge 3 ]] && hyprctl dispatch moveworkspacetomonitor 21 "${MONS[2]}"
[[ ${#MONS[@]} -ge 1 ]] && hyprctl dispatch focusmonitor "${MONS[0]}"
