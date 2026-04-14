#!/bin/bash

INTERVAL=2
TOTAL_DURATION=30
SOURCE_TYPE="monitor"  # monitor | input
FIFO=$(mktemp -u /tmp/songrec_out_XXXXXX)

while getopts "i:t:s:" opt; do
  case $opt in
    i) INTERVAL=$OPTARG ;;
    t) TOTAL_DURATION=$OPTARG ;;
    s) SOURCE_TYPE=$OPTARG ;;
    *) exit 1 ;;
  esac
done

if ! command -v songrec >/dev/null 2>&1; then
    exit 1
fi

if [ "$SOURCE_TYPE" = "monitor" ]; then
    AUDIO_DEVICE=$(pactl get-default-sink).monitor
elif [ "$SOURCE_TYPE" = "input" ]; then
    AUDIO_DEVICE=$(pactl info | grep "Default Source:" | awk '{print $3}' || true)
else
    echo "Invalid source type"
    exit 1
fi

if [ -z "$AUDIO_DEVICE" ] || ! pactl list short sources | grep -q "$AUDIO_DEVICE"; then
    exit 1
fi

if [ -z "$MONITOR_SOURCE" ] || ! pactl list short sources | grep -qF "$MONITOR_SOURCE"; then
    exit 1
fi

cleanup() {
    kill "$SONGREC_PID" 2>/dev/null || true
    wait "$SONGREC_PID" 2>/dev/null
    rm -f "$FIFO"
}
trap cleanup EXIT

songrec listen --audio-device "$AUDIO_DEVICE" --request-interval "$INTERVAL" --json --disable-mpris > "$FIFO" &
SONGREC_PID=$!

( sleep "$TOTAL_DURATION" && kill "$SONGREC_PID" 2>/dev/null ) &

while IFS= read -r line; do
    if echo "$line" | grep -q '"matches": \['; then
        echo "$line"
        exit 0
    fi
done < "$FIFO"

    ffmpeg -f s16le -ar 44100 -ac 2 -i "$TMP_RAW" -acodec libmp3lame -y -hide_banner -loglevel error "$TMP_MP3" 2>/dev/null
    RESULT=$(songrec audio-file-to-recognized-song "$TMP_MP3" 2>/dev/null || true)

    if echo "$RESULT" | grep -q '"matches": \[' && [ ${#RESULT} -gt $MIN_VALID_RESULT_LENGTH ]; then
        echo "$RESULT"
        exit 0
    fi
done
