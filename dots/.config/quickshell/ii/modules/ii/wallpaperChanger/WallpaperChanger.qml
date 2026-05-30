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
            
            // Center the window on the screen
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperChanger"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            // Remove illegal anchors.fill, let PanelWindow autosize to implicit content
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
