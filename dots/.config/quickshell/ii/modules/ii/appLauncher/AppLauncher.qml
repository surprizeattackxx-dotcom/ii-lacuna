import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    PanelWindow {
        id: panelWindow
        visible: GlobalStates.appLauncherOpen

        function hide() {
            GlobalStates.appLauncherOpen = false
        }

        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:appLauncher"
        WlrLayershell.keyboardFocus: GlobalStates.appLauncherOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow)
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow)
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                panelWindow.hide()
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
        }

        Loader {
            id: contentLoader
            active: GlobalStates.appLauncherOpen
            asynchronous: true
            anchors.fill: parent
            focus: GlobalStates.appLauncherOpen

            sourceComponent: SphereLauncher {
                onCloseRequested: panelWindow.hide()
            }
        }
    }

    IpcHandler {
        target: "appLauncher"

        function toggle(): void {
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen
        }

        function close(): void {
            GlobalStates.appLauncherOpen = false
        }

        function open(): void {
            GlobalStates.appLauncherOpen = true
        }
    }

    GlobalShortcut {
        name: "appLauncherToggle"
        description: "Toggles app launcher"
        onPressed: {
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen
        }
    }
}
