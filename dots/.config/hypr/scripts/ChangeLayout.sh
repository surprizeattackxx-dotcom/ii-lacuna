#!/bin/bash
# Cycle multilayout algorithms via layoutmsg.
# hl.dsp.layout('next') routes to our Lua layout_msg handler which re-tiles windows.

STATE_FILE="/tmp/multilayout_current"

hyprctl eval "hl.dispatch(hl.dsp.layout('next'))"

sleep 0.05

if [[ -f "$STATE_FILE" ]]; then
    NAME=$(< "$STATE_FILE")
else
    NAME="?"
fi

notify-send -e -u low "Layout" "$NAME" -t 1500
