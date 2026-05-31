#!/usr/bin/env bash
# Full reload: Hyprland config + Quickshell

# Reload Hyprland config
hyprctl reload

# Restart quickshell via its systemd service (keeps the raised FD limit)
systemctl --user restart quickshell-ii.service
