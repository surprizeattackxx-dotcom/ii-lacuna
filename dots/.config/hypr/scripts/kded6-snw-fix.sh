#!/bin/bash
# Prevent kded6 from owning org.kde.StatusNotifierWatcher.
#
# kded6 registers StatusNotifierWatcher at startup. If it starts before
# Quickshell, it claims the DBus name first — Quickshell can't reclaim it
# and tray icons disappear. However, if Quickshell already owns the name,
# kded6 cannot take it (it doesn't use DBUS_NAME_FLAG_REPLACE_EXISTING).
#
# Fix: kill kded6 on first detection, giving Quickshell the name. After
# Quickshell owns it, re-activations of kded6 (for KDE Connect etc.) are
# harmless — kded6 runs fine without owning StatusNotifierWatcher.

get_owner() {
    dbus-send --session --print-reply \
        --dest=org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus.GetNameOwner "string:$1" 2>/dev/null \
        | grep -o '":[0-9.]*"' | tr -d '"'
}

kill_kded6_if_owns_snw() {
    local snw_owner kded_owner
    snw_owner=$(get_owner org.kde.StatusNotifierWatcher)
    kded_owner=$(get_owner org.kde.kded6)
    if [[ -n "$snw_owner" && "$snw_owner" == "$kded_owner" ]]; then
        echo "[kded6-snw-fix] kded6 owns StatusNotifierWatcher — killing kded6"
        pkill -x kded6 2>/dev/null || true
        # After kded6 dies, Quickshell reclaims org.kde.StatusNotifierWatcher.
        # Subsequent kded6 restarts (DBus-activated for KDE Connect etc.) will
        # start fine but won't be able to steal the name from Quickshell.
    fi
}

# Fix current state if kded6 already owns it at startup
kill_kded6_if_owns_snw

# Watch for future ownership changes
dbus-monitor --session "type=signal,sender=org.freedesktop.DBus,member=NameOwnerChanged" 2>/dev/null \
    | grep --line-buffered "org.kde.StatusNotifierWatcher" \
    | while IFS= read -r _; do
        sleep 0.3
        kill_kded6_if_owns_snw
    done
