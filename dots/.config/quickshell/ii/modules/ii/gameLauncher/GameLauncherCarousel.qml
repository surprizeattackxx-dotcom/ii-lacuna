import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var model: []
    property int currentIndex: 0
    signal launchRequested(var gameData)

    function focusSearch() {}
    function selectFirst() { view.currentIndex = 0 }

    PathView {
        id: view
        anchors.fill: parent
        anchors.bottomMargin: infoArea.height + 32
        model: root.model
        focus: true
        interactive: true
        snapMode: PathView.SnapToItem
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        pathItemCount: Math.min(root.model.length, 3)

        path: Path {
            startX: -view.width * 0.25; startY: view.height * 0.5
            PathAttribute { name: "itemScale"; value: 0.65 }
            PathAttribute { name: "itemOpacity"; value: 0.4 }
            PathLine { x: view.width * 0.5; y: view.height * 0.5 }
            PathAttribute { name: "itemScale"; value: 1.0 }
            PathAttribute { name: "itemOpacity"; value: 1.0 }
            PathLine { x: view.width * 1.25; y: view.height * 0.5 }
            PathAttribute { name: "itemScale"; value: 0.65 }
            PathAttribute { name: "itemOpacity"; value: 0.4 }
        }

        delegate: Item {
            required property var modelData
            required property int index

            width: 440
            height: 660

            scale: PathView.itemScale
            opacity: PathView.itemOpacity

            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            readonly property color fallbackTop: {
                var h = 0
                for (var i = 0; i < modelData.name.length; i++)
                    h = ((h << 5) - h) + modelData.name.charCodeAt(i)
                return Qt.hsla(Math.abs(h) % 360 / 360, 0.45, 0.45, 1)
            }
            readonly property color fallbackBot: {
                var h = 0
                for (var i = 0; i < modelData.name.length; i++)
                    h = ((h << 5) - h) + modelData.name.charCodeAt(i)
                return Qt.hsla((Math.abs(h) + 180) % 360 / 360, 0.5, 0.25, 1)
            }

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                clip: true

                Image {
                    id: cardImage
                    anchors.fill: parent
                    source: !modelData.art ? "" : (modelData.art.startsWith("http") ? modelData.art : "file://" + modelData.art)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    opacity: modelData.installed ? 1.0 : 0.4
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !cardImage.visible
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: fallbackTop }
                        GradientStop { position: 1.0; color: fallbackBot }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 32
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (view.currentIndex === index)
                        root.launchRequested(modelData)
                    else
                        view.currentIndex = index
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "cloud_download"
                iconSize: 64
                color: "white"
                opacity: 0.85
                visible: !modelData.installed
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 10
                width: 40
                height: 40
                radius: 20
                color: Qt.rgba(0, 0, 0, 0.4)
                visible: view.currentIndex === index

                property bool fav: Games.isFavorite(modelData.appId)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: parent.fav ? "star" : "star_outline"
                    iconSize: 24
                    color: parent.fav ? "#FFD54F" : "white"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Games.toggleFavorite(modelData.appId)
                }
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left) {
                if (view.currentIndex > 0) view.currentIndex--
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                if (view.currentIndex < root.model.length - 1) view.currentIndex++
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                var item = root.model[view.currentIndex]
                if (item) root.launchRequested(item)
                event.accepted = true
            }
        }

        onCurrentIndexChanged: root.currentIndex = view.currentIndex
    }

    Rectangle {
        id: infoArea
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: infoLayout.implicitWidth + 32
        height: 56
        radius: Appearance.rounding.full
        color: Appearance.colors.colLayer2

        RowLayout {
            id: infoLayout
            anchors.centerIn: parent
            spacing: 12

            StyledText {
                text: root.model[view.currentIndex]?.name ?? ""
                font {
                    family: Appearance.font.family.body
                    pixelSize: Appearance.font.pixelSize.normal
                    weight: Font.DemiBold
                }
                color: Appearance.m3colors.m3onSurface
            }

            Rectangle {
                height: 22
                implicitWidth: badgeText.implicitWidth + 12
                radius: 4
                color: {
                    var item = root.model[view.currentIndex]
                    if (!item) return "#666"
                    switch (item.platform) {
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
                    text: root.model[view.currentIndex]?.platform ?? ""
                    color: "white"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        width: 44
        height: 28
        radius: 14
        color: Qt.rgba(0, 0, 0, 0.35)

        StyledText {
            anchors.centerIn: parent
            text: (view.currentIndex + 1) + "/" + root.model.length
            color: "white"
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }
}
