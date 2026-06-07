#!/usr/bin/env bash
SOUND="$HOME/.local/share/sounds/custom/dry-pop-notification.ogg"
dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null |
while read -r line; do
  case "$line" in
    *member=Notify*) pw-play "$SOUND" 2>/dev/null & ;;
  esac
done
