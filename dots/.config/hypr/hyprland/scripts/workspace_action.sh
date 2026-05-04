#!/usr/bin/env bash

curr_workspace="$(hyprctl activeworkspace -j | jq -r ".id")"
dispatcher="$1"
shift

if [[ -z "$dispatcher" || -z "$1" || "$dispatcher" == "--help" || "$dispatcher" == "-h" ]]; then
  echo "Usage: $0 <workspace|movetoworkspace> <target>"
  exit 1
fi

target="$1"

# relative workspace change (+1, -1)
if [[ "$target" == *"+"* || "$target" == *"-"* ]]; then
  hyprctl dispatch "$dispatcher" "$target"

# number inside 10-group logic (1–10 mapped into current group)
elif [[ "$1" =~ ^[0-9]+$ ]]; then
  target_workspace=$((((curr_workspace - 1) / 10 ) * 10 + $1))

  if [[ "$dispatcher" == "movetoworkspace" ]]; then
    hyprctl dispatch movetoworkspacesilent "$target_workspace"
  else
    hyprctl dispatch "$dispatcher" "$target_workspace"
  fi

# named / special workspaces
else
  hyprctl dispatch "$dispatcher" "$target"
fi
