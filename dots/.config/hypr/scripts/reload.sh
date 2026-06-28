#!/usr/bin/env bash
hyprctl reload
pkill qs
systemctl --user restart quickshell-noctalia.service
