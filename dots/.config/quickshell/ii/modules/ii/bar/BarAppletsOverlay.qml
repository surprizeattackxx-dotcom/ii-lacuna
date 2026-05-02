pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets

PanelWindow {
    id: root
    visible: GlobalStates.barAppletsOpen
    color: "transparent"

    WlrLayershell.namespace: "quickshell:bar-applets"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    onVisibleChanged: {
        if (visible) {
            panel._shown = false
            Qt.callLater(() => { panel._shown = true })
        }
    }

    readonly property var themeNames: ["Mocha", "Glass", "Matugen", "Gruvbox", "Apple", "Nord"]
    property string activeTheme: "Matugen"

    function addComponent(compId) {
        let arr = Config.options.bar.layouts.right.slice()
        arr.push({ id: compId, visible: true })
        Config.options.bar.layouts.right = arr
    }

    function removeComponent(compId) {
        for (const section of ["left", "center", "right"]) {
            let arr = Config.options.bar.layouts[section].slice()
            const idx = arr.findIndex(x => x.id === compId)
            if (idx !== -1) {
                arr.splice(idx, 1)
                Config.options.bar.layouts[section] = arr
                return
            }
        }
    }

    // Backdrop — click outside to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: GlobalStates.barAppletsOpen = false
    }

    Rectangle {
        id: panel
        property bool _shown: false

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: Appearance.sizes.barHeight + 8
        }

        width: Math.min(560, parent.width - 32)
        height: panelCol.implicitHeight + 32

        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.large
        border.width: 1
        border.color: Qt.rgba(
            Appearance.m3colors.m3outlineVariant.r,
            Appearance.m3colors.m3outlineVariant.g,
            Appearance.m3colors.m3outlineVariant.b, 0.6)

        opacity: _shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        transform: Translate {
            y: panel._shown ? 0 : -10
            Behavior on y {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            }
        }

        // Consume clicks so backdrop doesn't fire
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: panelCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 16
            }
            spacing: 10

            // ── Header ──────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Bar Applets"
                    color: Appearance.colors.colOnLayer0
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: doneBtnLabel.implicitWidth + 24
                    height: 30
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimary

                    Text {
                        id: doneBtnLabel
                        anchors.centerIn: parent
                        text: "Done"
                        color: Appearance.m3colors.m3onPrimary
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.barAppletsOpen = false
                    }
                }
            }

            // ── Theme ────────────────────────────────────
            Text {
                text: "THEME"
                color: Qt.rgba(Appearance.colors.colOnLayer0.r,
                               Appearance.colors.colOnLayer0.g,
                               Appearance.colors.colOnLayer0.b, 0.45)
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.themeNames
                    delegate: Rectangle {
                        id: themeChip
                        required property string modelData
                        readonly property bool isActive: root.activeTheme === modelData

                        height: 30
                        width: themeChipText.implicitWidth + 22
                        radius: Appearance.rounding.full

                        color: isActive
                            ? Appearance.colors.colPrimary
                            : Appearance.m3colors.m3surfaceContainerHigh

                        border.width: 1
                        border.color: isActive
                            ? "transparent"
                            : Qt.rgba(Appearance.m3colors.m3outlineVariant.r,
                                      Appearance.m3colors.m3outlineVariant.g,
                                      Appearance.m3colors.m3outlineVariant.b, 0.5)

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        Text {
                            id: themeChipText
                            anchors.centerIn: parent
                            text: themeChip.modelData
                            color: themeChip.isActive
                                ? Appearance.m3colors.m3onPrimary
                                : Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: themeChip.isActive ? Font.Medium : Font.Normal
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTheme = themeChip.modelData
                        }
                    }
                }
            }

            // ── Applets ──────────────────────────────────
            Text {
                text: "APPLETS"
                color: Qt.rgba(Appearance.colors.colOnLayer0.r,
                               Appearance.colors.colOnLayer0.g,
                               Appearance.colors.colOnLayer0.b, 0.45)
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: BarComponentRegistry.allComponents
                    delegate: Rectangle {
                        id: appletChip
                        required property var modelData
                        required property int index

                        readonly property bool onBar: {
                            const l = Config.options.bar.layouts.left
                            const c = Config.options.bar.layouts.center
                            const r = Config.options.bar.layouts.right
                            return (l || []).concat(c || []).concat(r || []).some(x => x.id === appletChip.modelData.id)
                        }

                        height: 32
                        width: appletRow.implicitWidth + 20
                        radius: Appearance.rounding.full

                        color: onBar
                            ? Qt.rgba(Appearance.m3colors.m3surfaceContainerHighest.r,
                                      Appearance.m3colors.m3surfaceContainerHighest.g,
                                      Appearance.m3colors.m3surfaceContainerHighest.b, 0.9)
                            : Qt.rgba(Appearance.m3colors.m3surfaceContainer.r,
                                      Appearance.m3colors.m3surfaceContainer.g,
                                      Appearance.m3colors.m3surfaceContainer.b, 0.5)

                        border.width: 1
                        border.color: onBar
                            ? Qt.rgba(Appearance.m3colors.m3outlineVariant.r,
                                      Appearance.m3colors.m3outlineVariant.g,
                                      Appearance.m3colors.m3outlineVariant.b, 0.5)
                            : "transparent"

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        RowLayout {
                            id: appletRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                text: appletChip.modelData.icon
                                iconSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                            }

                            Text {
                                text: appletChip.modelData.title
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: appletChip.onBar
                                    ? Qt.rgba(Appearance.colors.colError.r,
                                              Appearance.colors.colError.g,
                                              Appearance.colors.colError.b, 0.15)
                                    : Qt.rgba(Appearance.colors.colPrimary.r,
                                              Appearance.colors.colPrimary.g,
                                              Appearance.colors.colPrimary.b, 0.15)

                                Text {
                                    anchors.centerIn: parent
                                    text: appletChip.onBar ? "−" : "+"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    color: appletChip.onBar
                                        ? Appearance.colors.colError
                                        : Appearance.colors.colPrimary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (appletChip.onBar)
                                            root.removeComponent(appletChip.modelData.id)
                                        else
                                            root.addComponent(appletChip.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Pagination dots ───────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 18; height: 6; radius: 3
                    color: Appearance.colors.colPrimary
                }
                Item { Layout.fillWidth: true }
            }
        }
    }
}
