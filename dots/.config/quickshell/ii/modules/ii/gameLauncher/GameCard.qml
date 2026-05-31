import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Qt5Compat.GraphicalEffects

Item {
    id: root

    required property var gameData
    property int cardWidth: 180
    property int cardHeight: cardWidth * 1.4
    property bool hovering: false
    property bool externalSelected: false
    readonly property bool selected: hovering || externalSelected
    signal clicked()
    signal contextRequested(real globalX, real globalY)

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

    StyledRectangularShadow {
        target: cardBg
        blur: 1.3 * Appearance.sizes.elevationMargin
        offset: Qt.vector2d(0, 5)
        opacity: root.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: cardBg
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: cardHeight
        radius: Appearance.rounding.large
        color: Appearance.m3colors.m3surfaceContainerHighest

        Item {
            id: artClip
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: artClip.width
                    height: artClip.height
                    radius: cardBg.radius
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: !artImage.visible || root.gameData.iconArt
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: root.fallbackColor1 }
                    GradientStop { position: 1; color: root.fallbackColor2 }
                }
            }

            Image {
                id: artImage
                anchors.fill: parent
                anchors.margins: root.gameData.iconArt ? 26 : 0
                source: !root.gameData.art ? "" : (root.gameData.art.startsWith("http") ? root.gameData.art : "file://" + root.gameData.art)
                fillMode: root.gameData.iconArt ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                sourceSize.height: root.gameData.iconArt ? 256 : 0
                asynchronous: true
                visible: status === Image.Ready
                opacity: root.gameData.installed ? 1.0 : 0.4

                property bool artTried: false
                onStatusChanged: {
                    if ((status === Image.Error || status === Image.Null) && !artTried
                            && root.gameData.artGen && root.gameData.art) {
                        artTried = true
                        artGenProc.running = true
                    }
                }
            }

            Process {
                id: artGenProc
                command: ["bash", "-c", root.gameData.artGen || ""]
                onExited: (code, status) => {
                    var s = artImage.source
                    artImage.source = ""
                    artImage.source = s
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 36
                visible: !root.gameData.iconArt
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.5) }
                }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 6
            height: 18
            implicitWidth: badgeText.implicitWidth + 12
            radius: Appearance.rounding.small
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
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 28
            anchors.leftMargin: 6
            height: 18
            implicitWidth: newText.implicitWidth + 12
            radius: Appearance.rounding.small
            color: Appearance.m3colors.m3primary
            visible: Games.isNew(root.gameData.appId)

            StyledText {
                id: newText
                anchors.centerIn: parent
                text: "NEW"
                color: Appearance.m3colors.m3onPrimary
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }

        StyledText {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 8
            visible: root.gameData.playMinutes > 0
            text: root.fmtPlaytime(root.gameData.playMinutes)
            color: "white"
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        readonly property bool installing: Games.installingId === root.gameData.appId

        MaterialSymbol {
            anchors.centerIn: parent
            text: "cloud_download"
            iconSize: 40
            color: "white"
            opacity: 0.85
            visible: !root.gameData.installed && !cardBg.installing
        }

        Rectangle {
            anchors.fill: parent
            radius: cardBg.radius
            visible: cardBg.installing
            color: ColorUtils.transparentize(Appearance.m3colors.m3scrim, 0.35)

            Column {
                anchors.centerIn: parent
                spacing: 8

                Item {
                    width: 76
                    height: 76
                    anchors.horizontalCenter: parent.horizontalCenter

                    CircularProgress {
                        anchors.fill: parent
                        implicitSize: 76
                        lineWidth: 6
                        value: Games.installProgress / 100
                        colPrimary: Games.progressColor(Games.installProgress)
                        colSecondary: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.6)
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: Math.round(Games.installProgress) + "%"
                        color: Games.progressColor(Games.installProgress)
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Installing"
                    color: "white"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 48
            height: 48
            radius: 24
            color: Appearance.m3colors.m3primary
            visible: root.selected && root.gameData.installed

            MaterialSymbol {
                anchors.centerIn: parent
                text: "play_arrow"
                iconSize: 28
                fill: 1
                color: Appearance.m3colors.m3onPrimary
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: cardBg.radius
            color: "transparent"
            border.width: 2
            border.color: Appearance.m3colors.m3primary
            visible: root.selected
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
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    var p = mapToItem(null, mouse.x, mouse.y)
                    root.contextRequested(p.x, p.y)
                } else {
                    root.clicked()
                }
            }
            onEntered: root.hovering = true
            onExited: root.hovering = false
        }

        Rectangle {
            id: favBadge
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
                text: favBadge.fav ? "star" : "star_outline"
                iconSize: 18
                color: favBadge.fav ? "#FFD54F" : "white"
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

    function fmtPlaytime(min) {
        if (min >= 60) return Math.round(min / 60) + "h"
        return min + "m"
    }

    readonly property color platformColor: {
        switch (root.gameData.platform) {
            case "steam": return "#1b2838"
            case "heroic": return "#8B5CF6"
            case "appimage": return "#5F9B4E"
            case "native": return "#7C4DFF"
            case "rom": return "#E0794B"
            default: return "#666"
        }
    }
}
