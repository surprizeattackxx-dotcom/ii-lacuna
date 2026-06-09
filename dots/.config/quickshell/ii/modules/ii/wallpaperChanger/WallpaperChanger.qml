import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
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

    property bool _awaitingStateWrite: false

    Timer {
        id: previewClearTimer
        interval: 15000
        onTriggered: {
            _awaitingStateWrite = false
            GlobalStates.wallpaperPreviewPath = ""
        }
    }

    // Brief delay so Background's FileView watcher picks up the new state file
    // before we clear the preview path — otherwise perMonitorWallpaperPath reads
    // stale content and wallpaperPath briefly flips to the old image.
    Timer {
        id: applyFlushTimer
        interval: 200
        onTriggered: {
            if (_awaitingStateWrite) {
                _awaitingStateWrite = false
                GlobalStates.wallpaperPreviewPath = ""
            }
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperChangerOpenChanged() {
            if (GlobalStates.wallpaperChangerOpen) {
                previewClearTimer.stop()
                applyFlushTimer.stop()
                _awaitingStateWrite = false
            } else if (GlobalStates.wallpaperPreviewCommitted) {
                GlobalStates.wallpaperPreviewCommitted = false
                _awaitingStateWrite = true
                previewClearTimer.restart()
            } else {
                _awaitingStateWrite = false
                GlobalStates.wallpaperPreviewPath = ""
            }
        }
    }

    Connections {
        target: Wallpapers
        function onApplyFinished() {
            if (_awaitingStateWrite) {
                previewClearTimer.stop()
                applyFlushTimer.restart()
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
