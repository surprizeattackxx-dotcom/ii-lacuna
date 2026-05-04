import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    Loader {
        id: changerLoader
        active: GlobalStates.wallpaperChangerOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
            property bool monitorIsFocused: Hyprland.focusedMonitor?.id == monitor?.id

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperChanger"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            implicitHeight: changerContent.implicitHeight
            implicitWidth: changerContent.implicitWidth

            mask: Region { item: changerContent }

            Component.onCompleted: GlobalFocusGrab.addDismissable(panelWindow)
            Component.onDestruction: GlobalFocusGrab.removeDismissable(panelWindow)

            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.wallpaperChangerOpen = false
                }
            }

            WallpaperChangerContent {
                id: changerContent
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
            }
        }
    }

    IpcHandler {
        target: "wallpaperChanger"
        function toggle(): void { GlobalStates.wallpaperChangerOpen = !GlobalStates.wallpaperChangerOpen }
    }

    GlobalShortcut {
        name: "wallpaperChangerToggle"
        description: "Toggle live wallpaper changer"
        onPressed: GlobalStates.wallpaperChangerOpen = !GlobalStates.wallpaperChangerOpen
    }
}
