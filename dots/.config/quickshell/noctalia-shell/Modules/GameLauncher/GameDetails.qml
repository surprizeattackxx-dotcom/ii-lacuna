pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Commons
import qs.Services.System
import qs.Widgets

// Game details / actions panel (ported from illogical-impulse).
NBox {
    id: root
    property var game: null
    signal requestClose()

    color: Color.mSurfaceVariant
    radius: Style.radiusL

    readonly property bool installing: game && Games.installingId === game.appId

    function fmtPlaytime(min) { return min >= 60 ? (Math.round(min / 60) + "h " + (min % 60) + "m") : (min + "m"); }
    function fmtSize(b) {
        if (!b) return "—";
        const gb = b / 1073741824;
        return gb >= 1 ? (gb.toFixed(1) + " GB") : (Math.round(b / 1048576) + " MB");
    }
    function fmtDate(ts) {
        if (!ts) return "Never";
        return new Date(ts * 1000).toLocaleDateString(Qt.locale(), Locale.ShortFormat);
    }
    function launchOpt(k) { return root.game ? (Games.getLaunchOpts(root.game.appId)[k] === true) : false; }

    NScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: root.width
            spacing: Style.marginM

            // hero
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(width * 0.46)
                clip: true
                Image {
                    id: heroImg
                    anchors.fill: parent
                    source: {
                        if (!root.game) return "";
                        const h = root.game.hero || root.game.art;
                        return !h ? "" : (("" + h).startsWith("http") ? h : "file://" + h);
                    }
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: heroImg.width; height: heroImg.height; topLeftRadius: Style.radiusL; topRightRadius: Style.radiusL }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !heroImg.visible
                    color: Color.mSurface
                    topLeftRadius: Style.radiusL; topRightRadius: Style.radiusL
                }
                NIconButton {
                    anchors { top: parent.top; right: parent.right; margins: Style.marginS }
                    icon: "x"; baseSize: Style.baseWidgetSize * 0.8
                    onClicked: root.requestClose()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                spacing: Style.marginS

                NText {
                    Layout.fillWidth: true
                    text: root.game ? root.game.name : ""
                    pointSize: Style.fontSizeXL
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                    wrapMode: Text.Wrap
                }
                NText {
                    text: root.game ? root.game.platform : ""
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                }

                // launch / install
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.marginS
                    implicitHeight: Math.round(44 * Style.uiScaleRatio)
                    radius: Style.radiusM
                    color: Color.mPrimary
                    enabled: root.game && !root.installing
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Style.marginS
                        NIcon { icon: (root.game && root.game.installed) ? "play" : "download"; pointSize: 20; color: Color.mOnPrimary }
                        NText {
                            text: root.installing ? (Games.installStatus || "Installing… " + Math.round(Games.installProgress) + "%")
                                  : (root.game && root.game.installed) ? "Play" : "Install"
                            color: Color.mOnPrimary; pointSize: Style.fontSizeL; font.weight: Style.fontWeightBold
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.game) return;
                            if (root.game.installed) Games.launchGame(root.game);
                            else if (Games.canInstall(root.game) || root.game.platform === "heroic") Games.installGame(root.game, "", null);
                        }
                    }
                }

                // quick actions
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.marginXS
                    spacing: Style.marginS
                    NIconButton {
                        icon: "star"
                        tooltipText: (root.game && Games.isFavorite(root.game.appId)) ? "Unfavorite" : "Favorite"
                        colorFg: (root.game && Games.isFavorite(root.game.appId)) ? "#FFD54F" : Color.mPrimary
                        onClicked: if (root.game) { Games.toggleFavorite(root.game.appId); root.gameChanged(); }
                    }
                    NIconButton {
                        icon: (root.game && Games.isHidden(root.game.appId)) ? "eye" : "eye-off"
                        tooltipText: (root.game && Games.isHidden(root.game.appId)) ? "Unhide" : "Hide"
                        onClicked: if (root.game) Games.toggleHidden(root.game.appId)
                    }
                    NIconButton {
                        icon: "external-link"
                        tooltipText: "Store page"
                        enabled: root.game && root.game.storeUrl && root.game.storeUrl.length > 0
                        onClicked: if (root.game) Games.openStorePage(root.game)
                    }
                    Item { Layout.fillWidth: true }
                    NIconButton {
                        icon: "trash-2"
                        tooltipText: "Uninstall"
                        visible: root.game && Games.canUninstall(root.game)
                        colorFg: Color.mError
                        onClicked: if (root.game) Games.uninstall(root.game)
                    }
                }

                // info rows
                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.marginS
                    columns: 2
                    columnSpacing: Style.marginL
                    rowSpacing: Style.marginXS
                    NText { text: "Playtime"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
                    NText { text: root.fmtPlaytime(root.game ? root.game.playMinutes : 0); pointSize: Style.fontSizeS; color: Color.mOnSurface }
                    NText { text: "Last played"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
                    NText { text: root.fmtDate(root.game ? root.game.lastPlayed : 0); pointSize: Style.fontSizeS; color: Color.mOnSurface }
                    NText { text: "Size on disk"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
                    NText { text: root.fmtSize(root.game ? root.game.size : 0); pointSize: Style.fontSizeS; color: Color.mOnSurface }
                }

                // launch options
                NText { Layout.topMargin: Style.marginS; text: "Launch options"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
                Repeater {
                    model: [
                        { key: "gamescope", label: "Gamescope (fullscreen)" },
                        { key: "mangohud", label: "MangoHud overlay" },
                        { key: "gamemode", label: "GameMode" }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        NText { Layout.fillWidth: true; text: modelData.label; pointSize: Style.fontSizeS; color: Color.mOnSurface }
                        Rectangle {
                            width: 40; height: 22; radius: 11
                            color: root.launchOpt(modelData.key) ? Color.mPrimary : Color.mSurface
                            border.color: Color.mOutline; border.width: 1
                            Rectangle {
                                width: 16; height: 16; radius: 8; y: 3
                                x: root.launchOpt(modelData.key) ? 21 : 3
                                color: root.launchOpt(modelData.key) ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.game) { Games.setLaunchOpt(root.game.appId, modelData.key, !root.launchOpt(modelData.key)); root.gameChanged(); }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Style.marginL }
            }
        }
    }
}
