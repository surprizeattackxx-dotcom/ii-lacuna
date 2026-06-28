pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Widgets

// Bar-attached game launcher panel (ported from illogical-impulse).
SmartPanel {
    id: root

    preferredWidth: Math.round(1100 * Style.uiScaleRatio)
    preferredHeight: Math.round(740 * Style.uiScaleRatio)

    readonly property var platforms: ["steam", "heroic", "native", "appimage", "rom"]
    property int tabIndex: 0   // 0 = all, 1..5 = platform
    readonly property bool romsActive: tabIndex === 5
    property int sortMode: 0   // 0 name, 1 recent, 2 playtime
    property string searchQuery: ""
    property string pendingSearch: ""
    property var filteredGames: []
    property var selectedGame: null

    Timer { id: searchDebounce; interval: 220; onTriggered: root.searchQuery = root.pendingSearch }

    function fmtPlaytime(min) { return min >= 60 ? (Math.round(min / 60) + "h") : (min + "m"); }
    function fmtSize(b) {
        if (!b) return "";
        const gb = b / 1073741824;
        return gb >= 1 ? (gb.toFixed(1) + " GB") : (Math.round(b / 1048576) + " MB");
    }
    function fmtDate(ts) {
        if (!ts) return "Never";
        return new Date(ts * 1000).toLocaleDateString(Qt.locale(), Locale.ShortFormat);
    }

    // Coalesce rebuild requests — the scan appends games one-by-one (480+ count
    // changes); without this that's hundreds of full grid rebuilds = freeze.
    Timer { id: rebuildTimer; interval: 60; onTriggered: root.rebuild() }
    function rebuildLater() { rebuildTimer.restart(); }

    function rebuild() {
        const arr = [];
        for (var i = 0; i < Games.gameModel.count; i++) {
            const g = Games.gameModel.get(i);
            if (Games.isHidden(g.appId)) continue;
            if (root.tabIndex > 0 && g.platform !== root.platforms[root.tabIndex - 1]) continue;
            if (root.searchQuery.length > 0 && (g.name || "").toLowerCase().indexOf(root.searchQuery.toLowerCase()) < 0) continue;
            arr.push(g);
        }
        arr.sort((a, b) => {
            if (!!a.installed !== !!b.installed) return a.installed ? -1 : 1;
            const fa = Games.isFavorite(a.appId), fb = Games.isFavorite(b.appId);
            if (fa !== fb) return fa ? -1 : 1;
            if (root.sortMode === 1) return (b.lastPlayed || 0) - (a.lastPlayed || 0);
            if (root.sortMode === 2) return (b.playMinutes || 0) - (a.playMinutes || 0);
            return ("" + a.name).localeCompare("" + b.name);
        });
        root.filteredGames = arr;
    }

    Connections { target: Games; function onAvailableChanged() { root.rebuildLater(); } }
    Connections { target: Games.gameModel; function onCountChanged() { root.rebuildLater(); } }
    onTabIndexChanged: rebuildLater()
    onSortModeChanged: rebuildLater()
    onSearchQueryChanged: rebuildLater()
    onIsPanelOpenChanged: { if (isPanelOpen) { if (!Games.available && !Games.scanning) Games.scan(); rebuildLater(); } }
    Component.onCompleted: rebuildLater()

    panelContent: Item {
        id: pc
        anchors.fill: parent
        readonly property real contentPreferredWidth: Math.round(1100 * Style.uiScaleRatio)
        readonly property real contentPreferredHeight: Math.round(740 * Style.uiScaleRatio)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            // ─── Header ───
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM
                NIcon { icon: "gamepad-2"; pointSize: 26; color: Color.mPrimary }
                NText { text: "Game Library"; pointSize: Style.fontSizeXL; font.weight: Style.fontWeightBold; color: Color.mOnSurface }
                NText { text: root.filteredGames.length + " games"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant; Layout.alignment: Qt.AlignVCenter }
                Item { Layout.fillWidth: true }
                NTextInput {
                    Layout.preferredWidth: Math.round(260 * Style.uiScaleRatio)
                    label: ""
                    placeholderText: "Search…"
                    inputIconName: "search"
                    onTextChanged: { root.pendingSearch = text; searchDebounce.restart(); }
                }
                NIconButton {
                    icon: ["arrow-down-a-z", "history", "clock"][root.sortMode]
                    tooltipText: ["Sort: Name", "Sort: Recent", "Sort: Playtime"][root.sortMode]
                    onClicked: root.sortMode = (root.sortMode + 1) % 3
                }
                NIconButton { icon: "refresh-cw"; tooltipText: "Rescan"; enabled: !Games.scanning; onClicked: Games.scan() }
                NIconButton { icon: "x"; tooltipText: "Close"; onClicked: root.close() }
            }

            // ─── Platform tabs ───
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                Repeater {
                    model: ["All", "Steam", "Heroic", "Native", "AppImage", "ROMs"]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool active: root.tabIndex === index
                        implicitWidth: tabLabel.implicitWidth + Style.marginL
                        implicitHeight: Math.round(30 * Style.uiScaleRatio)
                        radius: Style.radiusM
                        color: active ? Color.mPrimary : Color.mSurfaceVariant
                        NText {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: parent.active ? Color.mOnPrimary : Color.mOnSurfaceVariant
                            pointSize: Style.fontSizeS
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tabIndex = parent.index }
                    }
                }
                Item { Layout.fillWidth: true }
                NBusyIndicator { running: Games.scanning; visible: Games.scanning; size: 22 }
            }

            // ─── Body: grid + details ───
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Style.marginM

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    NScrollView {
                        anchors.fill: parent
                        visible: !root.romsActive
                        GridView {
                            id: grid
                            anchors.fill: parent
                            cellWidth: Math.round(196 * Style.uiScaleRatio)
                            cellHeight: Math.round(300 * Style.uiScaleRatio)
                            model: root.filteredGames
                            clip: true
                            cacheBuffer: cellHeight * 2
                            reuseItems: true
                            delegate: Item {
                                required property var modelData
                                width: grid.cellWidth
                                height: grid.cellHeight
                                GameCard {
                                    anchors.centerIn: parent
                                    cardWidth: Math.round(180 * Style.uiScaleRatio)
                                    gameData: parent.modelData
                                    externalSelected: root.selectedGame && root.selectedGame.appId === parent.modelData.appId
                                    onClicked: {
                                        if (parent.modelData.installed) Games.launchGame(parent.modelData);
                                        else root.selectedGame = parent.modelData;
                                    }
                                    onContextRequested: root.selectedGame = parent.modelData
                                }
                            }
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: root.romsActive
                        visible: active
                        sourceComponent: RomBrowser {
                            searchText: root.searchQuery
                            onSelected: (g) => root.selectedGame = g
                        }
                    }
                }

                // ─── Details panel ───
                Loader {
                    active: root.selectedGame !== null
                    visible: active
                    Layout.preferredWidth: active ? Math.round(380 * Style.uiScaleRatio) : 0
                    Layout.fillHeight: true
                    sourceComponent: GameDetails {
                        game: root.selectedGame
                        onRequestClose: root.selectedGame = null
                    }
                }
            }
        }
    }
}
