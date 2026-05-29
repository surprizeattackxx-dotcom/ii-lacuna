import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Handles EasyEffects active state and presets.
 */
Singleton {
    id: root

    property bool available: false
    property bool active: false
    property list<string> outputPresets: []
    property string activePreset: ""

    function fetchAvailability() {
        fetchAvailabilityProc.running = true
    }

    function fetchActiveState() {
        fetchActiveStateProc.running = true
    }

    function fetchPresets() {
        fetchPresetsProc.running = true
    }

    function applyPreset(name) {
        root.activePreset = name
        Quickshell.execDetached(["bash", "-c", `easyeffects -l '${name}' || flatpak run com.github.wwmm.easyeffects -l '${name}'`])
    }

    function disable() {
        root.active = false
        Quickshell.execDetached(["bash", "-c", "pkill easyeffects || flatpak pkill com.github.wwmm.easyeffects"])
    }

    function enable() {
        root.active = true
        Quickshell.execDetached(["bash", "-c", "easyeffects --hide-window --service-mode || flatpak run com.github.wwmm.easyeffects --hide-window --service-mode"])
    }

    function toggle() {
        if (root.active) {
            root.disable()
        } else {
            root.enable()
        }
    }

    Process {
        id: fetchAvailabilityProc
        running: true
        command: ["bash", "-c", "command -v easyeffects || flatpak info com.github.wwmm.easyeffects > /dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            root.available = exitCode === 0
        }
    }

    Process {
        id: fetchActiveStateProc
        running: true
        command: ["bash", "-c", "pidof easyeffects || flatpak ps | grep com.github.wwmm.easyeffects > /dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            root.active = exitCode === 0
        }
    }

    Process {
        id: fetchPresetsProc
        running: true
        command: ["bash", "-c", 'd="${XDG_CONFIG_HOME:-$HOME/.config}/easyeffects/output"; [ -d "$d" ] && ls -1 "$d"/*.json 2>/dev/null | sed -e "s|.*/||" -e "s|\\.json$||"']
        stdout: StdioCollector {
            onStreamFinished: {
                root.outputPresets = text.trim().split("\n").filter(l => l.length > 0)
            }
        }
    }
}
