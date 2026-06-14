import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.utils
import qs.modules.common.functions
import "./widgets"

Item {
    id: root

    property bool isVertical: false

    readonly property real buttonSize: Appearance.sizes.dockButtonSize
    readonly property real dotMargin: (Config.options?.dock.height ?? 60) * 0.2
    readonly property real slotSize: buttonSize + dotMargin * 2
    readonly property real fixedSlots: isVertical ? 2.5 : 3
    readonly property real fixedLength: fixedSlots * slotSize

    readonly property real artSize: Math.round(buttonSize * 0.9)
    readonly property real artInner: artSize

    readonly property real controlSize: Math.round(buttonSize * 0.68)

    readonly property int textSizeL: Math.round(buttonSize * (isVertical ? 0.24 : 0.26))
    readonly property int textSizeS: Math.round(buttonSize * (isVertical ? 0.20 : 0.22))
    readonly property int marqueeRunningThreshold: isVertical ? 10 : 14

    implicitWidth: isVertical ? slotSize : fixedLength
    implicitHeight: isVertical ? buttonSize + dotMargin * 1.3 : slotSize

    property MprisPlayer player: MprisController.activePlayer
    readonly property MprisPlayer currentPlayer: player
    readonly property bool isPlaying: currentPlayer?.isPlaying ?? false

    readonly property string finalTitle: StringUtils.cleanMusicTitle(currentPlayer?.trackTitle) || Translation.tr("Unknown Title")
    readonly property string finalArtist: currentPlayer?.trackArtist || Translation.tr("Unknown Artist")
    readonly property string finalArtUrl: currentPlayer?.trackArtUrl || ""

    readonly property bool mediaHovered: mediaMouseArea.containsMouse || closeBtnArea.containsMouse

    MouseArea {
        id: mediaMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton || mouse.button === Qt.LeftButton) {
                root.currentPlayer?.togglePlaying();
            } else if (mouse.button === Qt.RightButton) {
                root.currentPlayer?.next();
            } else if (mouse.button === Qt.BackButton) {
                root.currentPlayer?.previous();
            } else if (mouse.button === Qt.ForwardButton) {
                root.currentPlayer?.next();
            }
        }
    }

    component ArtworkItem: Item {
        width: root.artSize
        height: root.artSize

        Rectangle {
            id: artRect
            anchors.centerIn: parent
            width: root.artInner
            height: root.artInner
            radius: Appearance.rounding.small
            color: Appearance.colors.colPrimaryContainer

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: artRect.width
                    height: artRect.height
                    radius: Appearance.rounding.small
                }
            }

            Image {
                id: artImg
                anchors.fill: parent
                source: root.finalArtUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width, height)
                cache: true
                antialiasing: true
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        MaterialSymbol {
            anchors.centerIn: artRect
            visible: artImg.status !== Image.Ready
            text: "music_note"
            iconSize: root.artInner * 0.48
            color: Appearance.colors.colPrimary
        }
    }


    Loader {
        active: !root.isVertical
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent

            ArtworkItem {
                id: artH
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
            }

            ColumnLayout {
                anchors.left: artH.right
                anchors.right: parent.right
                anchors.leftMargin: root.dotMargin * 0.6
                anchors.rightMargin: root.dotMargin * 0.6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Item {
                    Layout.fillWidth: true
                    implicitHeight: titleH.implicitHeight
                    clip: true
                    MarqueeText {
                        id: titleH
                        width: parent.width
                        text: root.finalTitle
                        fontSize: root.textSizeL
                        fontWeight: Font.DemiBold
                        textColor: Appearance.colors.colOnLayer0
                        running: root.mediaHovered && text.length > root.marqueeRunningThreshold
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: artistH.implicitHeight
                    clip: true
                    StyledText {
                        id: artistH
                        width: parent.width
                        text: root.finalArtist
                        font.pixelSize: root.textSizeS
                        font.weight: Font.Normal
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }
    
    Loader {
        active: root.isVertical
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent

            ArtworkItem {
                id: artV
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Hover ✕ to remove this player from the dock (quits it if it can, e.g. mpv;
    // otherwise just hides the widget — useful for stale browser media sessions)
    Rectangle {
        id: closeBtn
        z: 10
        visible: opacity > 0
        opacity: root.mediaHovered ? 1 : 0
        width: Math.round(root.buttonSize * 0.34)
        height: width
        radius: Appearance.rounding.full
        color: closeBtnArea.containsMouse ? Appearance.colors.colError : Appearance.colors.colSurfaceContainerHighest
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.dotMargin * 0.4
        anchors.rightMargin: root.dotMargin * 0.4

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(closeBtn)
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "close"
            iconSize: parent.width * 0.7
            color: closeBtnArea.containsMouse ? Appearance.colors.colOnError : Appearance.colors.colOnSurface
        }

        MouseArea {
            id: closeBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: MprisController.dismissPlayer(root.currentPlayer)
        }
    }

    DockTooltip {
        id: mediaTooltip
        parentItem: root
        text: root.finalTitle + " - " + root.finalArtist
        showTooltip: root.mediaHovered && !closeBtnArea.containsMouse
        tooltipOffset: -root.dotMargin * 0.5
    }
}