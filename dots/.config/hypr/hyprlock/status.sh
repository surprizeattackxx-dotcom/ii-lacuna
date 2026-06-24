#!/usr/bin/env bash
# Status line shown top-left on the hyprlock screen.
# Placeholder: shows uptime + load (desktop has no battery). Edit freely.
read -r up _ < /proc/uptime
secs=${up%.*}
d=$(( secs/86400 )); h=$(( (secs%86400)/3600 )); m=$(( (secs%3600)/60 ))
if [ "$d" -gt 0 ]; then
    uptime_str="up ${d}d ${h}h ${m}m"
else
    uptime_str="up ${h}h ${m}m"
fi
read -r l1 _ < /proc/loadavg
printf '%s   load %s\n' "$uptime_str" "$l1"
