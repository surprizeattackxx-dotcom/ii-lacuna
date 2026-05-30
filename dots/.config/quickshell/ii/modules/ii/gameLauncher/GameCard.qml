import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

Item {
    id: root

    required property var gameData
    property int cardWidth: 180
    property int cardHeight: cardWidth * 1.4
    property bool selected: false
    signal clicked()

    implicitWidth: cardWidth
    implicitHeight: cardHeight + nameLabel.implicitHeight + 10

    readonly property real nameHue: {
        var h = 0
        for (var i = 0; i < root.gameData.name.length; i++)
            h = ((h << 5) - h) + root.gameData.name.charCodeAt(i)
        return (Math.abs(h) % 360) / 360
    }
    readonly property color fallbackColor1: Qt.hsla(root.nameHue, 0.45, 0.45, 1)
    readonly property color fallbackColor2: Qt.hsla((root.nameHue + 0.5) % 1.0, 0.5, 0.25, 1)

    Rectangle {
        id: cardBg
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: cardHeight
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        clip: true

        Image {
            id: artImage
            anchors.fill: parent
            source: !root.gameData.art ? "" : (root.gameData.art.startsWith("http") ? root.gameData.art : "file://" + root.gameData.art)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
            opacity: root.gameData.installed ? 1.0 : 0.4
        }

        Rectangle {
            anchors.fill: parent
            visible: !artImage.visible
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: root.fallbackColor1 }
                GradientStop { position: 1; color: root.fallbackColor2 }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.5) }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 6
            height: 18
            implicitWidth: badgeText.implicitWidth + 12
            radius: 4
            color: root.platformColor

            StyledText {
                id: badgeText
                anchors.centerIn: parent
                text: root.gameData.platform
                color: "white"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 48
            height: 48
            radius: 24
            color: Qt.rgba(1, 1, 1, 0.9)
            visible: root.selected

            MaterialSymbol {
                anchors.centerIn: parent
                text: "play_arrow"
                iconSize: 28
                color: "#111"
            }
        }

        transform: Scale {
            origin.x: cardBg.width / 2
            origin.y: cardBg.height / 2
            xScale: root.selected ? 1.05 : 1
            yScale: root.selected ? 1.05 : 1

            Behavior on xScale {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on yScale {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
            onEntered: root.selected = true
            onExited: root.selected = false
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "cloud_download"
            iconSize: 40
            color: "white"
            opacity: 0.85
            visible: !root.gameData.installed
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            width: 28
            height: 28
            radius: 14
            color: Qt.rgba(0, 0, 0, 0.4)

            property bool fav: Games.isFavorite(root.gameData.appId)

            MaterialSymbol {
                anchors.centerIn: parent
                text: parent.fav ? "star" : "star_outline"
                iconSize: 18
                color: parent.fav ? "#FFD54F" : "white"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Games.toggleFavorite(root.gameData.appId)
            }
        }
    }

    StyledText {
        id: nameLabel
        anchors.top: cardBg.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        text: root.gameData.name
        font.pixelSize: Appearance.font.pixelSize.smallie
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.Wrap
    }

    readonly property color platformColor: {
        switch (root.gameData.platform) {
            case "steam": return "#1b2838"
            case "heroic": return "#8B5CF6"
            case "appimage": return "#5F9B4E"
            case "native": return "#7C4DFF"
            default: return "#666"
        }
    }
}
