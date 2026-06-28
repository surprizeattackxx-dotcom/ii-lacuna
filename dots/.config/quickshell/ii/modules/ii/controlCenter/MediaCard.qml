import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Services.Mpris

Rectangle {
    id: root
    implicitHeight: 140
    radius: Appearance.rounding.medium
    color: Appearance.m3colors.m3surfaceContainer

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasPlayer: activePlayer && activePlayer.trackTitle

    function formatTime(seconds) {
        if (seconds === undefined || seconds === null || isNaN(seconds) || seconds < 0)
            return "--:--"
        var total = Math.floor(seconds)
        var m = Math.floor(total / 60)
        var s = total % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        StyledText {
            text: Translation.tr("Media")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: Appearance.m3colors.m3onSurfaceVariant
        }

        StyledText {
            text: root.hasPlayer ? activePlayer.trackTitle : Translation.tr("No media playing")
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            color: Appearance.m3colors.m3onSurface
            elide: Text.ElideRight
        }

        StyledText {
            text: root.hasPlayer ? (activePlayer.artist || "") : ""
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.m3colors.m3onSurfaceVariant
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: Appearance.m3colors.m3surfaceContainerHigh

            Rectangle {
                width: parent.width * (root.hasPlayer ? (activePlayer.length > 0 ? activePlayer.position / activePlayer.length : 0) : 0)
                height: parent.height
                radius: 2
                color: Appearance.colors.colPrimary
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            StyledText {
                text: root.hasPlayer ? root.formatTime(activePlayer.position) : "--:--"
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.m3colors.m3onSurfaceVariant
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: root.hasPlayer ? root.formatTime(activePlayer.length) : "--:--"
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.m3colors.m3onSurfaceVariant
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Layout.alignment: Qt.AlignHCenter

            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                enabled: root.hasPlayer
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "skip_previous"
                    iconSize: 20
                    color: enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                }
                onClicked: activePlayer.previous()
            }

            RippleButton {
                implicitWidth: 40
                implicitHeight: 40
                buttonRadius: 20
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                enabled: root.hasPlayer
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: (root.hasPlayer && activePlayer.isPlaying) ? "pause" : "play_arrow"
                    iconSize: 24
                    color: Appearance.colors.colOnPrimaryContainer
                }
                onClicked: activePlayer.playPause()
            }

            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                enabled: root.hasPlayer
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "skip_next"
                    iconSize: 20
                    color: enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                }
                onClicked: activePlayer.next()
            }
        }
    }
}
