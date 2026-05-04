#!/usr/bin/env bash

# File: toggle_suspend_games.sh
# This script toggles SIGSTOP and SIGCONT for the active Hyprland window's PID.

# Get the PID of the active window
PID=$(hyprctl activewindow -j | jq -r '.pid')

if [ -z "$PID" ] || [ "$PID" == "null" ]; then
    notify-send "Games" "Could not find active window PID"
    exit 1
fi

# Check if the process is in stopped state (T)
if ps -o state= -p "$PID" | grep -q 'T'; then
    # If stopped, resume
    kill -CONT "$PID"
    notify-send "Games" "Process $PID resumed"
else
    # Otherwise, suspend
    kill -STOP "$PID"
    notify-send "Games" "Process $PID suspended"
fi
