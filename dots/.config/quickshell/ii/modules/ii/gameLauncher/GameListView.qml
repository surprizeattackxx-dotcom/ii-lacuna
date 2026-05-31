import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property var model: []
    property int currentIndex: -1
    signal launchRequested(var gameData)
    signal contextRequested(var gameData, real globalX, real globalY)

    function focusSearch() {}
    function selectFirst() {
        listView.currentIndex = 0
        listView.focus = true
    }
    function ensureSelected() { if (listView.currentIndex < 0) listView.currentIndex = 0 }
    function navUp() { if (listView.currentIndex > 0) listView.currentIndex-- }
    function navDown() { if (listView.currentIndex < root.model.length - 1) listView.currentIndex++ }
    function navLeft() {}
    function navRight() {}
    function activate() {
        var it = root.model[listView.currentIndex]
        if (it) root.launchRequested(it)
    }
    function selectedGame() { return root.model[listView.currentIndex] }
    function fmtPlaytime(min) {
        if (min >= 60) return Math.round(min / 60) + "h"
        return min + "m"
    }

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        model: root.model
        focus: true
        spacing: 4

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Item {
                required property var modelData
                required property int index

                width: listView.width
                height: 64

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: listView.currentIndex === index
                        ? Appearance.m3colors.m3primaryContainer
                        : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 12

                        Rectangle {
                            id: thumbBg
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 64
                            Layout.leftMargin: 0
                            radius: Appearance.rounding.small
                            color: Appearance.m3colors.m3surfaceContainerHighest

                            Item {
                                id: thumbClip
                                anchors.fill: parent
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: thumbClip.width
                                        height: thumbClip.height
                                        radius: thumbBg.radius
                                    }
                                }

                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: !modelData.art ? "" : (modelData.art.startsWith("http") ? modelData.art : "file://" + modelData.art)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible: !artImg.visible
                                    color: {
                                        var h = 0
                                        for (var i = 0; i < modelData.name.length; i++)
                                            h = ((h << 5) - h) + modelData.name.charCodeAt(i)
                                        return Qt.hsla(Math.abs(h) % 360 / 360, 0.45, 0.4, 1)
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: listView.currentIndex === index
                                ? Appearance.m3colors.m3onPrimaryContainer
                                : Appearance.m3colors.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            visible: modelData.playMinutes > 0
                            text: root.fmtPlaytime(modelData.playMinutes)
                            color: Appearance.m3colors.m3onSurfaceVariant
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        Rectangle {
                            height: 22
                            implicitWidth: badgeText.implicitWidth + 12
                            radius: 4
                            color: {
                                switch (modelData.platform) {
                                    case "steam": return "#1b2838"
                                    case "heroic": return "#8B5CF6"
                                    case "appimage": return "#5F9B4E"
                                    case "native": return "#7C4DFF"
                                    default: return "#666"
                                }
                            }

                            StyledText {
                                id: badgeText
                                anchors.centerIn: parent
                                text: modelData.platform
                                color: "white"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }

                        MaterialSymbol {
                            visible: !modelData.installed
                            text: "cloud_download"
                            iconSize: 18
                            color: Appearance.m3colors.m3onSurfaceVariant
                        }

                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: 18
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            onClicked: Games.toggleFavorite(modelData.appId)

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: Games.isFavorite(modelData.appId) ? "star" : "star_outline"
                                iconSize: 20
                                color: Games.isFavorite(modelData.appId) ? "#FFD54F" : Appearance.m3colors.m3onSurfaceVariant
                            }
                        }

                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: 18
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            onClicked: root.launchRequested(modelData)

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "play_arrow"
                                iconSize: 20
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        listView.currentIndex = index
                        if (mouse.button === Qt.RightButton) {
                            var p = mapToItem(null, mouse.x, mouse.y)
                            root.contextRequested(modelData, p.x, p.y)
                        } else {
                            root.launchRequested(modelData)
                        }
                    }
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {}
                else if (event.key === Qt.Key_Up) {
                    if (listView.currentIndex > 0) listView.currentIndex--
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    if (listView.currentIndex < root.model.length - 1) listView.currentIndex++
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                    var item = root.model[listView.currentIndex]
                    if (item) root.launchRequested(item)
                    event.accepted = true
                }
            }

        onCurrentIndexChanged: root.currentIndex = listView.currentIndex
    }
}
