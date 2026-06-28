import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.controlCenter

Scope {
    id: root

    Loader {
        id: panelLoader
        active: false
        asynchronous: true

        // Open/close driven imperatively so the close animation can finish before unload.
        Connections {
            target: GlobalStates
            function onControlCenterOpenChanged() {
                if (GlobalStates.controlCenterOpen) {
                    if (panelLoader.item)
                        panelLoader.item.reopen()
                    else
                        panelLoader.active = true
                } else if (panelLoader.item) {
                    panelLoader.item.startClose()
                }
            }
        }

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: true
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell:controlCenter"
            WlrLayershell.layer: WlrLayer.Overlay

            readonly property bool barVerticalRight: Config.options.bar.vertical && Config.barVerticalRight(null)
            // Anchor to bottom only when there's a horizontal bottom bar; otherwise top.
            readonly property bool anchorBottom: Config.options.bar.bottom && !Config.options.bar.vertical
            readonly property int barEdgeMargin: (Appearance.sizes.barHeight || 40) + 8
            // Never overflow the screen height.
            readonly property int availableHeight: (screen?.height ?? 1080) - 32

            implicitWidth: 440
            implicitHeight: Math.min(availableHeight, contentColumn.implicitHeight + 24)

            anchors {
                top: !anchorBottom
                bottom: anchorBottom
                right: true
            }
            margins {
                top: anchorBottom ? 0 : (Config.options.bar.vertical ? 16 : barEdgeMargin)
                bottom: anchorBottom ? barEdgeMargin : 0
                right: barVerticalRight ? (Appearance.sizes.verticalBarWidth + Appearance.rounding.screenRounding + 8) : 8
            }

            // ---- noctalia-style open/close animation ----
            // Grow horizontally from the bar edge when the bar is vertical, else vertically.
            readonly property bool revealHorizontal: Config.options.bar.vertical
            readonly property real revealFull: revealHorizontal ? width : height
            readonly property var bezierCurve: [0.05, 0, 0.133, 0.06, 0.166, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]

            property bool closing: false
            property real progress: 0        // 0 = collapsed, 1 = fully revealed (animated)
            property real contentOpacity: 0  // animated fade

            function reopen() {
                closing = false
                openOpacityTimer.stop()
                progress = 1
                openOpacityTimer.restart()
            }
            function startClose() {
                if (closing) return
                closing = true
                openOpacityTimer.stop()
                contentOpacity = 0 // fade first, then shrink (see Behavior below)
            }

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(panelWindow)
                progress = 1 // animates from 0
                openOpacityTimer.start()
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(panelWindow)
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.controlCenterOpen = false
                }
            }

            // Fade the content in shortly after the size animation begins.
            Timer {
                id: openOpacityTimer
                interval: 90
                repeat: false
                onTriggered: if (!panelWindow.closing) panelWindow.contentOpacity = 1
            }

            mask: Region {
                item: contentBackground
            }

            Rectangle {
                id: contentBackground
                clip: true
                color: Appearance.m3colors.m3surfaceContainerHigh
                radius: Appearance.rounding.large
                opacity: panelWindow.contentOpacity

                // Size: the reveal axis animates 0 -> full; the other axis is full.
                width: panelWindow.revealHorizontal ? (panelWindow.revealFull * panelWindow.progress) : parent.width
                height: panelWindow.revealHorizontal ? parent.height : (panelWindow.revealFull * panelWindow.progress)

                // Anchor to the origin edge so it grows outward from there.
                anchors.right: parent.right
                anchors.top: panelWindow.anchorBottom ? undefined : parent.top
                anchors.bottom: panelWindow.anchorBottom ? parent.bottom : undefined

                Behavior on opacity {
                    NumberAnimation {
                        duration: panelWindow.closing ? 120 : 150
                        easing.type: Easing.OutQuad
                        onRunningChanged: {
                            // When the close fade finishes, shrink the size.
                            if (!running && panelWindow.closing && panelWindow.contentOpacity === 0)
                                panelWindow.progress = 0
                        }
                    }
                }

                StyledRectangularShadow {
                    target: contentBackground
                }

                // Content host is fixed at full panel size and pinned to the origin
                // edge, so the growing/clipping background reveals it without squishing.
                Item {
                    id: contentHost
                    width: panelWindow.width
                    height: panelWindow.height
                    anchors.right: parent.right
                    anchors.top: panelWindow.anchorBottom ? undefined : parent.top
                    anchors.bottom: panelWindow.anchorBottom ? parent.bottom : undefined

                    ScrollView {
                        id: scrollView
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        contentWidth: contentColumn.implicitWidth
                        contentHeight: contentColumn.implicitHeight
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ColumnLayout {
                            id: contentColumn
                            width: scrollView.availableWidth
                            spacing: 13 // noctalia marginL

                            // Card heights mirror noctalia's control center.
                            ProfileCard { Layout.fillWidth: true; Layout.preferredHeight: 64 }
                            ShortcutsCard { Layout.fillWidth: true; Layout.preferredHeight: 52 }
                            AudioCard { Layout.fillWidth: true; Layout.preferredHeight: 60 }
                            // Brightness card intentionally omitted (disabled in noctalia).

                            Loader {
                                Layout.fillWidth: true
                                Layout.preferredHeight: active ? 210 : 0
                                active: Weather.ready && !Weather.hasError
                                visible: active
                                sourceComponent: WeatherCard {}
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 260
                                spacing: 13

                                MediaCard { Layout.fillWidth: true; Layout.fillHeight: true }
                                SystemMonitorCard { Layout.preferredWidth: 140; Layout.fillHeight: true }
                            }
                        }
                    }
                }

                Behavior on width {
                    enabled: panelWindow.revealHorizontal
                    NumberAnimation {
                        duration: panelWindow.closing ? 200 : 300
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: panelWindow.bezierCurve
                        onRunningChanged: {
                            if (!running && panelWindow.closing && panelWindow.progress === 0)
                                panelLoader.active = false
                        }
                    }
                }
                Behavior on height {
                    enabled: !panelWindow.revealHorizontal
                    NumberAnimation {
                        duration: panelWindow.closing ? 200 : 300
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: panelWindow.bezierCurve
                        onRunningChanged: {
                            if (!running && panelWindow.closing && panelWindow.progress === 0)
                                panelLoader.active = false
                        }
                    }
                }
            }
        }
    }
}
