pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string hyprlandConfigPath: Directories.home.replace("file://", "") + "/.local/share/hyprland/hyprland.conf"
    
    Process {
        id: configWriter
        
        running: false
        property string pendingCommand: ""
        command: ["bash", "-c", pendingCommand]

        onExited: (exitCode, exitStatus) => {
            // NOTE: This will not work bc we are running it detached
            if (exitCode === 1) {
                Quickshell.execDetached(["notify-send", Translation.tr("Couldn't change the setting"), Translation.tr("Make sure you have vynx-cli installed"), "-a", "Shell"])
            }
        }
    }

    function changeKey(key, value) {
        if (/['"\\`$|&;]/.test(String(value)) || /['"\\`$|&;]/.test(String(key))) {
            console.error("[HyprlandSettings] Unsafe characters rejected:", key, value)
            return
        }
        if (!key.includes(":")) return
        Quickshell.execDetached([Directories.cliPath, "hyprset", "key", key, String(value)])
    }

    function changeAnimation(animName, style) {
        if (/['"\\`$|&;]/.test(String(animName)) || /['"\\`$|&;]/.test(String(style))) {
            console.error("[HyprlandSettings] Unsafe characters rejected:", animName, style)
            return
        }
        Quickshell.execDetached([Directories.cliPath, "hyprset", "anim", animName, String(style)])
    }

    function setLayout(layout) {
        if (layout !== "default" && layout !== "scrolling" && layout !== "dwindle" && layout !== "monocle" && layout !== "master") return
        // console.log("[HyprlandSettings] Setting layout to", layout)
        changeKey("general:layout", layout)
        Persistent.states.hyprland.layout = layout
    }

    function setRounding(rounding) {
        changeKey("decoration:rounding", rounding)
    }
}