#!/usr/bin/env bash
DISP="--bus 9"

read -r CUR MAX <<< "$(ddcutil $DISP --brief getvcp 10 2>/dev/null | awk '{print $4, $5}')"
[[ -z "$CUR" || -z "$MAX" ]] && exit 1

ddcutil $DISP setvcp 10 "$MAX" 2>/dev/null

PERCENT=$((MAX * 100 / MAX))
echo "brightness|${PERCENT}" > /tmp/qs_osd
