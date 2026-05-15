#!/usr/bin/env bash
ACTION="${1:-up}"
STEP="${2:-5}"
DISP="--bus 9"

read -r CUR MAX <<< "$(ddcutil $DISP --brief getvcp 10 2>/dev/null | awk '{print $4, $5}')"
[[ -z "$CUR" || -z "$MAX" ]] && exit 1

case "$ACTION" in
    up)   NEW=$((CUR + STEP)) ;;
    down) NEW=$((CUR - STEP)) ;;
esac

[[ "$NEW" -lt 0 ]] && NEW=0
[[ "$NEW" -gt "$MAX" ]] && NEW=$MAX

ddcutil $DISP setvcp 10 "$NEW" 2>/dev/null

PERCENT=$((NEW * 100 / MAX))
echo "brightness|${PERCENT}" > /tmp/qs_osd
