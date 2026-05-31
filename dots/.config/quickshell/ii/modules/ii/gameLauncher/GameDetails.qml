import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property var game: null
    property bool shown: false
    signal launchRequested(var game)
    signal requestClose()

    visible: shown || sheet.x < width

    function fmtPlaytime(min) {
        if (!min || min <= 0) return "Never played"
        if (min >= 60) return Math.floor(min / 60) + "h " + (min % 60) + "m"
        return min + "m"
    }
    function fmtSize(bytes) {
        if (!bytes || bytes <= 0) return ""
        if (bytes >= 1e9) return (bytes / 1e9).toFixed(1) + " GB"
        return Math.round(bytes / 1e6) + " MB"
    }
    function fmtDate(sec) {
        if (!sec || sec <= 0) return "Never"
        return new Date(sec * 1000).toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }
    function heroUrl() {
        if (!root.game) return ""
        var h = root.game.hero || root.game.art
        if (!h || h.length === 0) return ""
        return h.startsWith("http") ? h : "file://" + h
    }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Appearance.m3colors.m3scrim, 0.4)
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.requestClose()
        }
    }

    Rectangle {
        id: sheet
        width: 460
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: root.shown ? parent.width - width : parent.width
        color: Appearance.m3colors.m3surfaceContainer

        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }  // swallow clicks

        Flickable {
            anchors.fill: parent
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: content
                width: sheet.width
                spacing: 0

                // ---- hero ----
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 240

                    Rectangle {
                        anchors.fill: parent
                        color: Appearance.m3colors.m3surfaceContainerHighest
                    }

                    Image {
                        id: heroImg
                        anchors.fill: parent
                        source: root.heroUrl()
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.4; color: "transparent" }
                            GradientStop { position: 1.0; color: Appearance.m3colors.m3surfaceContainer }
                        }
                    }

                    RippleButton {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        implicitWidth: 36
                        implicitHeight: 36
                        buttonRadius: 18
                        colBackground: ColorUtils.transparentize(Appearance.m3colors.m3scrim, 0.5)
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: root.requestClose()
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 22
                            color: "white"
                        }
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 18
                        text: root.game ? root.game.name : ""
                        color: Appearance.m3colors.m3onSurface
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 18
                    Layout.rightMargin: 18
                    Layout.topMargin: 16
                    Layout.bottomMargin: 18
                    spacing: 16

                    // ---- meta chips ----
                    RowLayout {
                        spacing: 8

                        Rectangle {
                            implicitWidth: platBadge.implicitWidth + 16
                            implicitHeight: 24
                            radius: Appearance.rounding.small
                            color: Appearance.m3colors.m3secondaryContainer
                            StyledText {
                                id: platBadge
                                anchors.centerIn: parent
                                text: root.game ? root.game.platform : ""
                                color: Appearance.m3colors.m3onSecondaryContainer
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            visible: root.game && !root.game.installed
                            implicitWidth: instBadge.implicitWidth + 16
                            implicitHeight: 24
                            radius: Appearance.rounding.small
                            color: Appearance.m3colors.m3surfaceContainerHighest
                            StyledText {
                                id: instBadge
                                anchors.centerIn: parent
                                text: "Not installed"
                                color: Appearance.m3colors.m3onSurfaceVariant
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }

                    // ---- stats ----
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 16

                        StyledText { text: "Playtime"; color: Appearance.m3colors.m3onSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.small }
                        StyledText { text: root.fmtPlaytime(root.game ? root.game.playMinutes : 0); color: Appearance.m3colors.m3onSurface; font.pixelSize: Appearance.font.pixelSize.small }

                        StyledText { text: "Last played"; color: Appearance.m3colors.m3onSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.small }
                        StyledText { text: root.fmtDate(root.game ? root.game.lastPlayed : 0); color: Appearance.m3colors.m3onSurface; font.pixelSize: Appearance.font.pixelSize.small }

                        StyledText { visible: root.game && root.game.size > 0; text: "Size on disk"; color: Appearance.m3colors.m3onSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.small }
                        StyledText { visible: root.game && root.game.size > 0; text: root.fmtSize(root.game ? root.game.size : 0); color: Appearance.m3colors.m3onSurface; font.pixelSize: Appearance.font.pixelSize.small }
                    }

                    // ---- launch button ----
                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.m3colors.m3primary
                        colBackgroundHover: Appearance.m3colors.m3primary
                        onClicked: root.launchRequested(root.game)

                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            MaterialSymbol {
                                text: (root.game && root.game.installed) ? "play_arrow" : "download"
                                iconSize: 22
                                fill: 1
                                color: Appearance.m3colors.m3onPrimary
                            }
                            StyledText {
                                text: (root.game && root.game.installed) ? "Launch" : "Install"
                                color: Appearance.m3colors.m3onPrimary
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    // ---- secondary actions ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        DetailAction {
                            Layout.fillWidth: true
                            icon: root.game && Games.isFavorite(root.game.appId) ? "star" : "star_outline"
                            label: root.game && Games.isFavorite(root.game.appId) ? "Favorited" : "Favorite"
                            active: root.game && Games.isFavorite(root.game.appId)
                            onTriggered: if (root.game) Games.toggleFavorite(root.game.appId)
                        }
                        DetailAction {
                            Layout.fillWidth: true
                            icon: root.game && Games.isHidden(root.game.appId) ? "visibility" : "visibility_off"
                            label: root.game && Games.isHidden(root.game.appId) ? "Unhide" : "Hide"
                            active: root.game && Games.isHidden(root.game.appId)
                            onTriggered: if (root.game) Games.toggleHidden(root.game.appId)
                        }
                        DetailAction {
                            Layout.fillWidth: true
                            visible: root.game && root.game.storeUrl && root.game.storeUrl.length > 0
                            icon: "open_in_new"
                            label: "Store"
                            onTriggered: if (root.game) Games.openStorePage(root.game)
                        }
                    }

                    // ---- launch options ----
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        visible: root.game && root.game.installed
                        spacing: 4

                        StyledText {
                            text: "Launch options"
                            color: Appearance.m3colors.m3onSurfaceVariant
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                        }

                        OptToggle { optKey: "gamescope"; label: "Gamescope (fullscreen)" }
                        OptToggle { optKey: "mangohud"; label: "MangoHud overlay" }
                        OptToggle { optKey: "gamemode"; label: "GameMode" }
                    }
                }
            }
        }
    }

    component DetailAction: Rectangle {
        property string icon: ""
        property string label: ""
        property bool active: false
        signal triggered()
        implicitHeight: 56
        radius: Appearance.rounding.small
        color: active ? Appearance.m3colors.m3secondaryContainer
            : (actMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.m3colors.m3surfaceContainerHigh)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.icon
                iconSize: 20
                color: parent.parent.active ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurface
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: parent.parent.active ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
        MouseArea {
            id: actMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.triggered()
        }
    }

    component OptToggle: RowLayout {
        property string optKey: ""
        property string label: ""
        Layout.fillWidth: true
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: parent.label
            color: Appearance.m3colors.m3onSurface
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledSwitch {
            checked: root.game ? (Games.getLaunchOpts(root.game.appId)[parent.optKey] === true) : false
            onToggled: if (root.game) Games.setLaunchOpt(root.game.appId, parent.optKey, checked)
        }
    }
}
