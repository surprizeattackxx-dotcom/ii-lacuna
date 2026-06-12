#!/bin/bash
read -r cx cy < <(hyprctl cursorpos -j | jq -r '"\(.x) \(.y)"')

pid=$(hyprctl clients -j | jq -r --argjson cx "$cx" --argjson cy "$cy" '
  [ .[] | select(.mapped and .hidden == false)
        | select($cx >= .at[0] and $cx < .at[0] + .size[0]
             and $cy >= .at[1] and $cy < .at[1] + .size[1]) ]
  | sort_by(.focusHistoryID) | .[0].pid // empty')

[ -n "$pid" ] && kill -9 "$pid"
