pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Services.UI
import qs.Services.Ai

// IPC + shortcut for the AI panel. Toggles the registered bar-attached
// SmartPanel ("aiChatPanel"), anchoring it to the "AiChat" bar widget.
Singleton {
    id: root

    // Force-load AiService at startup (the controller itself is force-loaded from
    // shell.qml) so the keyring read finishes well before the first message.
    Component.onCompleted: AiService.reloadKeys()

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
        AiService.reloadKeys();
        AiService.refreshOllama();
        const s = focusedScreen();
        if (s) PanelService.getPanel("aiChatPanel", s)?.toggle(null, "AiChat");
    }
    function open() {
        AiService.reloadKeys();
        AiService.refreshOllama();
        const s = focusedScreen();
        if (s) PanelService.getPanel("aiChatPanel", s)?.open(null, "AiChat");
    }
    function close() {
        const s = focusedScreen();
        if (s) PanelService.getPanel("aiChatPanel", s)?.close();
    }

    IpcHandler {
        target: "ai"
        function toggle() { root.toggle(); }
        function open() { root.open(); }
        function close() { root.close(); }
    }

    GlobalShortcut {
        name: "aiSidebarToggle"
        description: "Toggle the AI assistant sidebar"
        onPressed: root.toggle()
    }
}
