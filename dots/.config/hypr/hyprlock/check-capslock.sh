#!/usr/bin/env bash
# Emits a warning string for the hyprlock Caps Lock label.
# Reads the keyboard LED state directly from sysfs (no hyprctl dependency, so it
# works even before the compositor IPC is reachable).
for led in /sys/class/leds/*::capslock/brightness; do
    [ -r "$led" ] || continue
    if [ "$(< "$led")" != "0" ]; then
        printf '%s\n' "Caps Lock is ON"
        exit 0
    fi
done
exit 0
