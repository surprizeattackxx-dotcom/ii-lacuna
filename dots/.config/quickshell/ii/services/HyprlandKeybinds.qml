pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property var keybinds: []
    property var keybindCategories: []

    property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/hyprland/parse_binds_lua.py`)
    property string bindsPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/binds.lua`)

    property bool _hyprctlDone: false
    property var _hyprctlData: []
    property bool _luaDone: false
    property var _luaData: []

    function merge() {
        if (!root._hyprctlDone || !root._luaDone) return

        var hyprBinds = root._hyprctlData
        var luaBinds = root._luaData

        var cats = []
        for (var i = 0; i < hyprBinds.length; i++) {
            var lua = i < luaBinds.length ? luaBinds[i] : null
            hyprBinds[i].category = lua ? (lua.category || "") : ""
            hyprBinds[i].description = lua ? (lua.description || "") : ""

            if (hyprBinds[i].category && !cats.includes(hyprBinds[i].category)) {
                cats.push(hyprBinds[i].category)
            }
        }

        root.keybinds = hyprBinds
        root.keybindCategories = cats
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name == "configreloaded") {
                root._hyprctlDone = false
                root._luaDone = false
                hyprctlBinds.running = true
            }
        }
    }

    Process {
        id: hyprctlBinds
        running: true
        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._hyprctlData = JSON.parse(text)
                    root._hyprctlDone = true
                    luaBinds.running = true
                } catch (e) {
                    console.error("[HyprlandKeybinds] Error parsing hyprctl output:", e)
                }
            }
        }
    }

    Process {
        id: luaBinds
        running: false
        command: ["python3", root.scriptPath, root.bindsPath]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._luaData = JSON.parse(text)
                } catch (e) {
                    root._luaData = []
                    console.error("[HyprlandKeybinds] Error parsing Lua binds:", e)
                }
                root._luaDone = true
                root.merge()
            }
        }
    }
}
