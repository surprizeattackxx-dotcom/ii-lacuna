pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Services.UI

// IPC + shortcut for the keybindings cheatsheet (centered SmartPanel).
Singleton {
    id: root

    function focusedScreen() {
        const fm = Hyprland.focusedMonitor;
        if (fm) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === fm.name) return Quickshell.screens[i];
            }
        }
        return PanelService.findScreenForPanels();
    }

    function toggle() {
        const s = focusedScreen();
        if (s) PanelService.getPanel("cheatsheetPanel", s)?.toggle(null, "Cheatsheet");
    }
    function show() {
        const s = focusedScreen();
        if (s) PanelService.getPanel("cheatsheetPanel", s)?.open(null, "Cheatsheet");
    }
    function hide() {
        const s = focusedScreen();
        if (s) PanelService.getPanel("cheatsheetPanel", s)?.close();
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle() { root.toggle(); }
        function open() { root.show(); }
        function close() { root.hide(); }
    }

    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggle the keybindings cheatsheet"
        onPressed: root.toggle()
    }
}
