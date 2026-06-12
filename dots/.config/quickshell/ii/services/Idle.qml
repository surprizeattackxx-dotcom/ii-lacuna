pragma Singleton
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled
    inhibit: false

    readonly property string _sessionId: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""

    Timer {
        id: restoreTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (!Persistent.ready) return
            const storedId = Persistent.states.idle.sessionId || ""
            if (storedId === root._sessionId) {
                root.inhibit = Persistent.states.idle.inhibit ?? false
            } else {
                root.inhibit = false
            }
        }
    }

    Connections {
        target: Persistent
        function onReadyChanged() { restoreTimer.restart() }
    }

    function toggleInhibit(active = null) {
        root.inhibit = active !== null ? active : !root.inhibit
        Persistent.states.idle.inhibit = root.inhibit
        Persistent.states.idle.sessionId = root._sessionId
    }

    // Native idle handling (replaces hypridle, which crashes Hyprland here)
    IdleMonitor {
        enabled: Config.options.lock.idle.enable && Config.options.lock.idle.lockTimeout > 0
        respectInhibitors: true
        timeout: Config.options.lock.idle.lockTimeout
        onIsIdleChanged: {
            if (!isIdle || GlobalStates.screenLocked) return
            if (Config.options.lock.useHyprlock) {
                Quickshell.execDetached(["bash", "-c", "pidof hyprlock || hyprlock"])
            } else {
                GlobalStates.screenLocked = true
            }
        }
    }

    IdleMonitor {
        enabled: Config.options.lock.idle.enable && Config.options.lock.idle.dpmsTimeout > 0
        respectInhibitors: true
        timeout: Config.options.lock.idle.dpmsTimeout
        onIsIdleChanged: Quickshell.execDetached(["hyprctl", "dispatch", "dpms", isIdle ? "off" : "on"])
    }

    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            // Inhibitor requires a "visible" surface
            // Actually not lol
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            // Just in case...
            anchors {
                right: true
                bottom: true
            }
            // Make it not interactable
            mask: Region {
                item: null
            }
        }
    }
}
