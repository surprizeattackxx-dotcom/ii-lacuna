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

            // Pin the screen chosen at open time — the binding above tracks
            // focusedMonitor, so without this the window (and the apply target)
            // follows the mouse to whatever monitor the cursor wanders onto.
            Component.onCompleted: {
                const s = panelWindow.screen;
                panelWindow.screen = s;
                GlobalFocusGrab.addDismissable(panelWindow)
            }
            Component.onDestruction: GlobalFocusGrab.removeDismissable(panelWindow)

            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.wallpaperChangerOpen = false
                }
            }

            WallpaperChangerContent {
                id: changerContent
                targetMonitor: panelWindow.screen?.name ?? ""
            }
        }
    }

    property bool _awaitingStateWrite: false

    // Safety net only — normal clear happens via applyFlushTimer after
    // applyFinished. Must outlast a slow switchwall run (matugen + applycolor
    // on 4K can take >15s); firing early reverts the background mid-apply.
    Timer {
        id: previewClearTimer
        interval: 60000
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
        interval: 1000
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
        function onApplyFinished(exitCode, exitStatus) {
            console.log(`[WallpaperChanger DEBUG] applyFinished: exitCode=${exitCode} _awaitingStateWrite=${_awaitingStateWrite}`);
            if (exitCode !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "Wallpaper changer",
                    "Wallpaper apply failed", `switchwall.sh exited with code ${exitCode} — background reverted`]);
            }
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
