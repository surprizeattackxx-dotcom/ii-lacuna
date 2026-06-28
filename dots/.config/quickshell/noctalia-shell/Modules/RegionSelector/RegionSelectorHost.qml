import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

// Instantiates a RegionSelection overlay on each screen while the selector is
// open. Referencing the RegionSelector singleton here forces it to load, which
// registers its IPC ("region") + global shortcuts. Loaded once from shell.qml.
Variants {
    model: Quickshell.screens

    delegate: Loader {
        id: loader
        required property var modelData

        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(loader.modelData)
        readonly property bool monitorIsFocused: (Hyprland.focusedMonitor?.id === monitor?.id)
        readonly property bool onlyFocused: Settings.data.regionSelector?.showOnlyOnFocusedMonitor ?? false

        active: RegionSelector.open && (!onlyFocused || monitorIsFocused)

        sourceComponent: RegionSelection {
            screen: loader.modelData
            action: RegionSelector.action
            selectionMode: RegionSelector.selectionMode
            onDismiss: RegionSelector.dismiss()
        }
    }
}
