#!/usr/bin/env bash
hyprctl reload
systemctl --user restart noctalia.service
