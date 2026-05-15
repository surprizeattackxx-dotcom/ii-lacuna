#!/usr/bin/env bash
# Full reload: Hyprland config + Quickshell

# Reload Hyprland config
hyprctl reload

# Restart quickshell (kill then relaunch)
qs kill -c ii
sleep 0.5
qs -c ii &
