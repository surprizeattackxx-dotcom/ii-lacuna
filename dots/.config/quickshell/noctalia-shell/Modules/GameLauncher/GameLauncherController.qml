pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Services.UI

// IPC + shortcut for the game launcher. Toggles the registered bar-attached
// SmartPanel ("gameLauncherPanel"), anchoring it to the "GameLauncher" bar widget.
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
        if (s) PanelService.getPanel("gameLauncherPanel", s)?.toggle(null, "GameLauncher");
    }
    function show() {
        const s = focusedScreen();
        if (s) PanelService.getPanel("gameLauncherPanel", s)?.open(null, "GameLauncher");
    }
    function hide() {
        const s = focusedScreen();
        if (s) PanelService.getPanel("gameLauncherPanel", s)?.close();
    }

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
