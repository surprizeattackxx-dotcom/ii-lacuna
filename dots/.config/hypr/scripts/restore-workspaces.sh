#!/bin/bash
# Boot-time workspace placement, keyed to explicit monitor names so focus lands
# on DP-2 regardless of the order Hyprland enumerates outputs. Matches the
# monitor→workspace blocks in hyprland/workspaces.lua:
#   DP-2 → ws 1-10   DP-1 → ws 11-20   HDMI-A-1 → ws 21-30
#
# NOTE: this is a Lua-config Hyprland — `hyprctl dispatch` evaluates its argument
# as Lua, so dispatchers must be written as hl.dsp.<name>(...), not the classic
# "moveworkspacetomonitor 11 DP-1" string form.
has() { hyprctl monitors -j | jq -e --arg m "$1" 'any(.[]; .name == $m)' >/dev/null; }

has DP-1     && hyprctl dispatch 'hl.dsp.workspace.move({ workspace = 11, monitor = "DP-1" })'
has HDMI-A-1 && hyprctl dispatch 'hl.dsp.workspace.move({ workspace = 21, monitor = "HDMI-A-1" })'
# Force DP-2 to be the focused/active monitor for new windows (do this last).
has DP-2 && hyprctl dispatch 'hl.dsp.focus({ monitor = "DP-2" })'
