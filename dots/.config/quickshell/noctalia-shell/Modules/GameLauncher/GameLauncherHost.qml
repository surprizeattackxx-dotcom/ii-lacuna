import QtQuick
import Quickshell
import Quickshell.Hyprland

// Instantiates the fullscreen launcher on the focused screen while open.
// Referencing GameLauncherController loads the singleton (IPC + shortcut).
Variants {
    model: Quickshell.screens

    delegate: Loader {
        id: loader
        required property var modelData

        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(loader.modelData)
        readonly property bool monitorIsFocused: (Hyprland.focusedMonitor?.id === monitor?.id)

        active: GameLauncherController.open && monitorIsFocused

        sourceComponent: GameLauncher {
            screen: loader.modelData
            onRequestClose: GameLauncherController.hide()
        }
    }
}
