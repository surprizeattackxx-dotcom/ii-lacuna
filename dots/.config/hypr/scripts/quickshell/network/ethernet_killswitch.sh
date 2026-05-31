#!/usr/bin/env bash
# Persistent ethernet killswitch via NetworkManager (no root needed).
# Armed = all wired profiles autoconnect off + device downed, so it stays dead
# across replug/reboot until disarmed.

IFACE=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="ethernet"{print $1; exit}')
[ -z "$IFACE" ] && exit 1

mapfile -t PROFILES < <(nmcli -t -f NAME,TYPE connection show | awk -F: '$2 ~ /ethernet/ {print $1}')

armed_state() {
    [ ${#PROFILES[@]} -eq 0 ] && { echo no; return; }
    for p in "${PROFILES[@]}"; do
        ac=$(nmcli -t -f connection.autoconnect connection show "$p" | cut -d: -f2)
        [ "$ac" == "yes" ] && { echo no; return; }
    done
    echo yes
}

case "${1:---toggle}" in
    --status)
        armed_state
        ;;
    --toggle)
        if [ "$(armed_state)" == "yes" ]; then
            for p in "${PROFILES[@]}"; do nmcli connection modify "$p" connection.autoconnect yes; done
            nmcli device connect "$IFACE"
        else
            for p in "${PROFILES[@]}"; do nmcli connection modify "$p" connection.autoconnect no; done
            nmcli device disconnect "$IFACE"
        fi
        ;;
esac
