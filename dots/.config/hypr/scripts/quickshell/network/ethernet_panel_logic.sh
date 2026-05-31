#!/usr/bin/env bash

IFACE=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="ethernet"{print $1; exit}')

if [ -z "$IFACE" ]; then
    echo '{"power":"off","killed":false,"connected":null,"networks":[]}'
    exit 0
fi

STATE=$(nmcli -t -f DEVICE,STATE device | awk -F: -v d="$IFACE" '$1==d{print $2}')

if [ "$STATE" == "connected" ]; then
    CONN_NAME=$(nmcli -t -f DEVICE,CONNECTION device | awk -F: -v d="$IFACE" '$1==d{print $2}')
    [ -z "$CONN_NAME" ] && CONN_NAME="$IFACE"

    IP=$(ip -4 addr show dev "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    [ -z "$IP" ] && IP="No IP"

    SPEED=$(cat /sys/class/net/"$IFACE"/speed 2>/dev/null)
    if [[ "$SPEED" =~ ^[0-9]+$ ]] && [ "$SPEED" -gt 0 ]; then
        if [ "$SPEED" -ge 1000 ]; then SPEED="$((SPEED / 1000)) Gb/s"; else SPEED="${SPEED} Mb/s"; fi
    else
        SPEED="Unknown"
    fi

    name_esc="${CONN_NAME//\"/\\\"}"
    CONNECTED_JSON="{\"id\":\"$name_esc\",\"ssid\":\"$name_esc\",\"icon\":\"󰈀\",\"signal\":\"100\",\"security\":\"Wired\",\"ip\":\"$IP\",\"freq\":\"$SPEED\"}"
    echo "{\"power\":\"on\",\"killed\":false,\"connected\":$CONNECTED_JSON,\"networks\":[]}"
    exit 0
fi

# Not connected: is the killswitch armed? (all wired profiles autoconnect off)
mapfile -t WIRED < <(nmcli -t -f NAME,TYPE connection show | awk -F: '$2 ~ /ethernet/ {print $1}')
KILLED=false
if [ ${#WIRED[@]} -gt 0 ]; then
    KILLED=true
    for p in "${WIRED[@]}"; do
        ac=$(nmcli -t -f connection.autoconnect connection show "$p" | cut -d: -f2)
        [ "$ac" == "yes" ] && { KILLED=false; break; }
    done
fi

if [ "$KILLED" == true ]; then
    echo '{"power":"off","killed":true,"connected":null,"networks":[]}'
    exit 0
fi

CARRIER=$(cat /sys/class/net/"$IFACE"/carrier 2>/dev/null)
if [ "$CARRIER" != "1" ]; then
    echo '{"power":"off","killed":false,"connected":null,"networks":[]}'
    exit 0
fi

# Cable plugged in but not connected: offer inactive wired profiles to bring up
NETWORKS_JSON=$(nmcli -t -f NAME,TYPE,ACTIVE connection show | awk -F: '
    $2 ~ /ethernet/ && $3 != "yes" {
        name=$1;
        gsub(/"/, "\\\"", name);
        printf "{\"id\":\"%s\",\"ssid\":\"%s\",\"icon\":\"󰈀\",\"signal\":\"100\",\"security\":\"Wired\",\"action\":\"Connect\"}\n", name, name
    }
' | head -n 24 | paste -sd, -)

if [ -z "$NETWORKS_JSON" ]; then
    NETWORKS_JSON="[]"
else
    NETWORKS_JSON="[$NETWORKS_JSON]"
fi

echo "{\"power\":\"on\",\"killed\":false,\"connected\":null,\"networks\":$NETWORKS_JSON}"
