pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Widgets

// Cover-art game card (ported from illogical-impulse).
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
        var n = root.gameData.name || ""
        for (var i = 0; i < n.length; i++)
            h = ((h << 5) - h) + n.charCodeAt(i)
        return (Math.abs(h) % 360) / 360
    }
    readonly property color fallbackColor1: Qt.hsla(root.nameHue, 0.45, 0.45, 1)
    readonly property color fallbackColor2: Qt.hsla((root.nameHue + 0.5) % 1.0, 0.5, 0.25, 1)

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

    function fmtPlaytime(min) {
        if (min >= 60) return Math.round(min / 60) + "h"
        return min + "m"
    }

    Rectangle {
        id: cardBg
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.cardHeight
        radius: Style.radiusL
        color: Color.mSurfaceVariant

        transform: Scale {
            origin.x: cardBg.width / 2; origin.y: cardBg.height / 2
            xScale: root.selected ? 1.05 : 1
            yScale: root.selected ? 1.05 : 1
            Behavior on xScale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on yScale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        Item {
            id: artClip
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle { width: artClip.width; height: artClip.height; radius: cardBg.radius }
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
                source: !root.gameData.art ? "" : (("" + root.gameData.art).startsWith("http") ? root.gameData.art : "file://" + root.gameData.art)
                fillMode: root.gameData.iconArt ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                sourceSize.height: root.gameData.iconArt ? 256 : 0
                asynchronous: true
                visible: status === Image.Ready
                opacity: root.gameData.installed ? 1.0 : 0.4

                // ROM art is generated lazily via the artGen command on first miss.
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
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 36
                visible: !root.gameData.iconArt
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.5) }
                }
            }
        }

        // platform badge
        Rectangle {
            anchors { top: parent.top; left: parent.left; margins: 6 }
            height: 18
            implicitWidth: badgeText.implicitWidth + 12
            radius: Style.radiusXS
            color: root.platformColor
            NText {
                id: badgeText
                anchors.centerIn: parent
                text: root.gameData.platform
                color: "white"
                pointSize: 9
                font.weight: Font.DemiBold
            }
        }

        // NEW badge
        Rectangle {
            anchors { top: parent.top; left: parent.left; topMargin: 28; leftMargin: 6 }
            height: 18
            implicitWidth: newText.implicitWidth + 12
            radius: Style.radiusXS
            color: Color.mPrimary
            visible: Games.isNew(root.gameData.appId)
            NText {
                id: newText
                anchors.centerIn: parent
                text: "NEW"; color: Color.mOnPrimary; pointSize: 9; font.weight: Font.Bold
            }
        }

        // playtime
        NText {
            anchors { bottom: parent.bottom; left: parent.left; margins: 8 }
            visible: root.gameData.playMinutes > 0
            text: root.fmtPlaytime(root.gameData.playMinutes)
            color: "white"; pointSize: 9; font.weight: Font.DemiBold
        }

        readonly property bool installing: Games.installingId === root.gameData.appId

        NIcon {
            anchors.centerIn: parent
            icon: "download-cloud"
            pointSize: 36
            color: "white"
            opacity: 0.85
            visible: !root.gameData.installed && !cardBg.installing
        }

        // install overlay
        Rectangle {
            anchors.fill: parent
            radius: cardBg.radius
            visible: cardBg.installing
            color: Qt.rgba(0, 0, 0, 0.65)
            Column {
                anchors.centerIn: parent
                spacing: 8
                NText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(Games.installProgress) + "%"
                    color: Games.progressColor(Games.installProgress)
                    pointSize: 20; font.weight: Font.Bold
                }
                NText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Installing"; color: "white"; pointSize: 10; font.weight: Font.DemiBold
                }
            }
        }

        // play button (hover/select, installed)
        Rectangle {
            anchors.centerIn: parent
            width: 48; height: 48; radius: 24
            color: Color.mPrimary
            visible: root.selected && root.gameData.installed && !cardBg.installing
            NIcon { anchors.centerIn: parent; icon: "play"; pointSize: 24; color: Color.mOnPrimary }
        }

        // selection border
        Rectangle {
            anchors.fill: parent
            radius: cardBg.radius
            color: "transparent"
            border.width: 2
            border.color: Color.mPrimary
            visible: root.selected
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

        // favorite star
        Rectangle {
            anchors { top: parent.top; right: parent.right; margins: 6 }
            width: 28; height: 28; radius: 14
            color: Qt.rgba(0, 0, 0, 0.4)
            property bool fav: Games.isFavorite(root.gameData.appId)
            NIcon {
                anchors.centerIn: parent
                icon: parent.fav ? "star" : "star"
                pointSize: 16
                color: parent.fav ? "#FFD54F" : "white"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Games.toggleFavorite(root.gameData.appId)
            }
        }
    }

    NText {
        id: nameLabel
        anchors { top: cardBg.bottom; topMargin: 6; left: parent.left; right: parent.right }
        text: root.gameData.name
        pointSize: Style.fontSizeXS
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.Wrap
    }
}
