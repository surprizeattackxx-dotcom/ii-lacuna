import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

StyledPopup {
    id: root

    property var windows: []
    property var toplevels: []
    property int workspaceId: -1

    readonly property var monitor: windows.length > 0
        ? (HyprlandData.monitors.find(m => m.id === windows[0].monitor) ?? null)
        : null

    readonly property real reservedLeft:   monitor?.reserved?.[0] ?? 0
    readonly property real reservedTop:    monitor?.reserved?.[1] ?? 0
    readonly property real reservedRight:  monitor?.reserved?.[2] ?? 0
    readonly property real reservedBottom: monitor?.reserved?.[3] ?? 0

    readonly property real logicalWidth:  monitor ? monitor.width  / monitor.scale : 1920
    readonly property real logicalHeight: monitor ? monitor.height / monitor.scale : 1080
    readonly property real contentWidth:  logicalWidth  - reservedLeft - reservedRight
    readonly property real contentHeight: logicalHeight - reservedTop  - reservedBottom

    readonly property real thumbW: 280
    readonly property real thumbH: thumbW * contentHeight / contentWidth
    readonly property real thumbScale: thumbW / contentWidth

    contentItem: Item {
        implicitWidth: Math.max(root.thumbW + 20, windowList.implicitWidth + 20)
        implicitHeight: root.thumbH + 14 + windowList.implicitHeight + 14 + 8

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 7
            spacing: 8

            Item {
                Layout.fillWidth: true
                implicitWidth: root.thumbW
                implicitHeight: root.thumbH
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.colors.colLayer0
                    radius: Appearance.rounding.small
                }

                Repeater {
                    model: root.toplevels
                    delegate: ScreencopyView {
                        property var winData: HyprlandData.windowByAddress["0x" + modelData.HyprlandToplevel?.address]
                        captureSource: modelData
                        live: true
                        clip: true
                        x: winData ? (winData.at[0] - (root.monitor?.x ?? 0) - root.reservedLeft) * root.thumbScale : 0
                        y: winData ? (winData.at[1] - (root.monitor?.y ?? 0) - root.reservedTop)  * root.thumbScale : 0
                        width:  winData ? winData.size[0] * root.thumbScale : 0
                        height: winData ? winData.size[1] * root.thumbScale : 0
                    }
                }
            }

            ColumnLayout {
                id: windowList
                Layout.alignment: Qt.AlignLeft
                spacing: 5

                Repeater {
                    model: root.windows
                    delegate: RowLayout {
                        required property var modelData
                        spacing: 8

                        IconImage {
                            source: Quickshell.iconPath(AppSearch.guessIcon(modelData?.class ?? ""), "image-missing")
                            implicitSize: 20
                        }

                        StyledText {
                            readonly property string raw: modelData?.title ?? modelData?.class ?? "?"
                            text: raw.length > 38 ? raw.substring(0, 35) + "…" : raw
                            font.pixelSize: Appearance.font.pixelSize.small
                            Layout.maximumWidth: 240
                        }
                    }
                }
            }
        }
    }
}
