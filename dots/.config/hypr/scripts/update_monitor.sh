#!/bin/bash

OUTPUT="$1"
MODE="$2"
POSITION="$3"
SCALE="$4"

FILE="$HOME/.config/hypr/monitors.lua"

echo "Updating $OUTPUT with $MODE, $POSITION, $SCALE" >> /tmp/monitor_debug.log

perl -0777 -i -pe '
  s{
    hl\.monitor\(\{\s*
    output\s*=\s*"'$OUTPUT'".*?
    mode\s*=\s*".*?",.*?
    position\s*=\s*".*?",.*?
    scale\s*=\s*[\d\.]+
  }{
    hl.monitor({
      output = "'$OUTPUT'",
      mode = "'$MODE'",
      position = "'$POSITION'",
      scale = '$SCALE'
  }gsx
' "$FILE"

# Reload Hyprland config
hyprctl reload
