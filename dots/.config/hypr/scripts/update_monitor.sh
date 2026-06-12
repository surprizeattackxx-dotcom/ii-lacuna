#!/bin/bash
# Rewrite one monitor's mode/position/scale in monitors.lua, keeping the
# remaining fields (bitdepth, cm, sdr*) intact. Called by BarAppletsOverlay.

export OUTPUT="$1" MODE="$2" POSITION="$3" SCALE="$4"
FILE="$HOME/.config/hypr/monitors.lua"

perl -0777 -i -pe '
  my ($o, $m, $p, $s) = @ENV{qw(OUTPUT MODE POSITION SCALE)};
  s{
    hl\.monitor\(\{\s*
    output\s*=\s*"\Q$o\E".*?
    mode\s*=\s*".*?",.*?
    position\s*=\s*".*?",.*?
    scale\s*=\s*[\d\.]+
  }!hl.monitor({
    output = "$o",
    mode = "$m",
    position = "$p",
    scale = $s!gsx
' "$FILE"

hyprctl reload
