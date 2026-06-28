pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Open-state + IPC/shortcut for the fullscreen game launcher.
Singleton {
    id: root

    property bool open: false

    function toggle() { root.open = !root.open; }
    function show() { root.open = true; }
    function hide() { root.open = false; }

    IpcHandler {
        target: "gameLauncher"
        function toggle() { root.toggle(); }
        function open() { root.show(); }
        function close() { root.hide(); }
    }

    GlobalShortcut {
        name: "gameLauncherToggle"
        description: "Toggle the game launcher"
        onPressed: root.toggle()
    }
}
