import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: rootScope

    function close() {
        GlobalStates.gameLauncherOpen = false
    }

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)

    Loader {
        id: loader
        active: GlobalStates.gameLauncherOpen

        onActiveChanged: {
            if (active) {
                if (!Games.available && !Games.scanning)
                    Games.scan()
                Qt.callLater(() => searchInput.forceActiveFocus())
            }
        }

        sourceComponent: PanelWindow {
            id: panel
            visible: loader.active

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:gameLauncher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: ColorUtils.transparentize(Appearance.m3colors.m3background, 0.08)

            anchors {
                top: true; left: true; right: true; bottom: true
            }

            implicitWidth: rootScope.focusedScreen?.width ?? 1920
            implicitHeight: rootScope.focusedScreen?.height ?? 1080

            // ---- filter state ----
            property int tabIndex: 0
            property string searchText: ""
            property int viewMode: 0
            property bool installedOnly: false
            property bool showHidden: false
            property int sortMode: 0  // 0 = name, 1 = recent, 2 = playtime
            readonly property bool romsActive: panel.tabIndex === 5

            // ---- filtered model as JS array ----
            property var filteredGames: []
            property var recentGames: []

            function rebuildFilter() {
                var result = []
                var search = panel.searchText.toLowerCase().trim()
                var platforms = ["steam", "heroic", "appimage", "native"]

                for (var i = 0; i < Games.gameModel.count; i++) {
                    var item = Games.gameModel.get(i)
                    if (panel.tabIndex > 0 && item.platform !== platforms[panel.tabIndex - 1])
                        continue
                    if (search.length > 0 && item.name.toLowerCase().indexOf(search) === -1)
                        continue
                    if (Games.isHidden(item.appId) && !panel.showHidden)
                        continue
                    if (panel.installedOnly && !item.installed)
                        continue
                    result.push(item)
                }
                result.sort((a, b) => {
                    var fa = Games.isFavorite(a.appId), fb = Games.isFavorite(b.appId)
                    if (fa !== fb) return fa ? -1 : 1
                    if (panel.sortMode === 1 && a.lastPlayed !== b.lastPlayed)
                        return b.lastPlayed - a.lastPlayed
                    if (panel.sortMode === 2 && a.playMinutes !== b.playMinutes)
                        return b.playMinutes - a.playMinutes
                    if (a.installed !== b.installed) return a.installed ? -1 : 1
                    return a.name.localeCompare(b.name)
                })
                panel.filteredGames = result

                var recent = []
                for (var j = 0; j < Games.gameModel.count; j++) {
                    var g = Games.gameModel.get(j)
                    if (g.lastPlayed > 0 && !Games.isHidden(g.appId))
                        recent.push(g)
                }
                recent.sort((a, b) => b.lastPlayed - a.lastPlayed)
                panel.recentGames = recent.slice(0, 10)
            }

            function scheduleRebuild() { rebuildTimer.restart() }

            Timer {
                id: rebuildTimer
                interval: 32
                onTriggered: panel.rebuildFilter()
            }

            Process {
                id: gamepadProc
                command: ["python3", Directories.scriptPath + "/games/gamepad.py"]
                running: panel.visible
                stdout: SplitParser {
                    onRead: data => panel.handleGamepad(data.trim())
                }
            }

            Connections {
                target: Games.gameModel
                function onCountChanged() { panel.scheduleRebuild() }
                function onRowsInserted() { panel.scheduleRebuild() }
                function onRowsRemoved() { panel.scheduleRebuild() }
                function onModelReset() { panel.scheduleRebuild() }
            }

            Connections {
                target: Games
                function onFavoritesChanged() { panel.scheduleRebuild() }
                function onHiddenChanged() { panel.scheduleRebuild() }
            }

            onTabIndexChanged: panel.rebuildFilter()
            onSearchTextChanged: panel.rebuildFilter()
            onInstalledOnlyChanged: panel.rebuildFilter()
            onShowHiddenChanged: panel.rebuildFilter()
            onSortModeChanged: panel.rebuildFilter()
            Component.onCompleted: panel.rebuildFilter()

            // ---- context menu ----
            property var ctxGame: null
            property var detailsGame: null

            function openContextMenu(game, x, y) {
                panel.ctxGame = game
                contextMenu.x = Math.max(8, Math.min(x, panel.width - contextMenu.width - 8))
                contextMenu.y = Math.max(8, Math.min(y, panel.height - contextMenu.height - 8))
                contextMenu.visible = true
            }

            property var confirmGame: null

            function openDetails(game) {
                panel.detailsGame = game
                gameDetails.shown = true
                contextMenu.visible = false
            }

            function surpriseMe() {
                var pool = panel.filteredGames.filter(g => g.installed)
                if (pool.length === 0) pool = panel.filteredGames
                if (pool.length === 0) return
                var g = pool[Math.floor(Math.random() * pool.length)]
                Games.launchGame(g)
                rootScope.close()
            }

            function handleGamepad(action) {
                if (gameDetails.shown) {
                    if (action === "b") gameDetails.shown = false
                    else if ((action === "a" || action === "start") && panel.detailsGame) {
                        Games.launchGame(panel.detailsGame)
                        rootScope.close()
                    }
                    return
                }
                if (contextMenu.visible) {
                    if (action === "b") contextMenu.visible = false
                    return
                }
                if (action === "lb") { panel.tabIndex = Math.max(0, panel.tabIndex - 1); return }
                if (action === "rb") { panel.tabIndex = Math.min(5, panel.tabIndex + 1); return }
                if (panel.romsActive) {
                    if (action === "b") {
                        if (romBrowser.currentSystem) romBrowser.back()
                        else rootScope.close()
                    } else {
                        romBrowser.gamepad(action)
                    }
                    return
                }
                var v = viewLoader.item
                if (!v) return
                if (action === "up") v.navUp()
                else if (action === "down") v.navDown()
                else if (action === "left") v.navLeft()
                else if (action === "right") v.navRight()
                else if (action === "a" || action === "start") {
                    if (v.currentIndex < 0) v.ensureSelected()
                    else v.activate()
                } else if (action === "b") rootScope.close()
                else if (action === "y") {
                    var g = v.selectedGame()
                    if (g) panel.openDetails(g)
                } else if (action === "x") {
                    var g2 = v.selectedGame()
                    if (g2) Games.toggleFavorite(g2.appId)
                }
            }

            function doContextAction(action) {
                var g = panel.ctxGame
                if (!g) return
                if (action === "details") panel.openDetails(g)
                else if (action === "fav") Games.toggleFavorite(g.appId)
                else if (action === "launch") { Games.launchGame(g); rootScope.close() }
                else if (action === "store") Games.openStorePage(g)
                else if (action === "hide") Games.toggleHidden(g.appId)
                else if (action === "uninstall") {
                    if (g.platform === "rom") { panel.confirmGame = g; confirmDialog.visible = true }
                    else Games.uninstall(g)
                }
                contextMenu.visible = false
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    rootScope.close()
            }

            // ---- hero background ----
            property var heroGame: {
                var idx = viewLoader.item ? viewLoader.item.currentIndex : -1
                if (idx >= 0 && idx < panel.filteredGames.length) return panel.filteredGames[idx]
                return panel.filteredGames.length > 0 ? panel.filteredGames[0] : null
            }
            property string heroSource: {
                if (!panel.heroGame || !panel.heroGame.hero || panel.heroGame.hero.length === 0) return ""
                return panel.heroGame.hero.startsWith("http") ? panel.heroGame.hero : "file://" + panel.heroGame.hero
            }

            Image {
                id: heroImage
                anchors.fill: parent
                source: panel.heroSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(Appearance.m3colors.m3background, 0.35)
                opacity: heroImage.opacity
            }

            MouseArea {
                anchors.fill: parent
                onClicked: rootScope.close()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 24
                anchors.leftMargin: 48
                anchors.rightMargin: 48
                anchors.bottomMargin: 32
                spacing: 0

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        rootScope.close()
                }

                // ---- top bar ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    StyledText {
                        text: "Games"
                        font {
                            family: Appearance.font.family.title
                            pixelSize: Appearance.font.pixelSize.title
                            variableAxes: Appearance.font.variableAxes.title
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // ---- view mode segmented buttons ----
                    Rectangle {
                        Layout.preferredHeight: 40
                        implicitWidth: segmentRow.implicitWidth
                        radius: Appearance.rounding.full
                        color: Appearance.m3colors.m3surfaceContainerHigh

                        RowLayout {
                            id: segmentRow
                            anchors.fill: parent
                            spacing: 0

                            Repeater {
                                model: [
                                    { icon: "grid_view", tooltip: "Grid" },
                                    { icon: "view_carousel", tooltip: "Carousel" },
                                    { icon: "list", tooltip: "List" },
                                ]

                                Rectangle {
                                    required property int index
                                    required property var modelData

                                    Layout.preferredWidth: 48
                                    Layout.fillHeight: true
                                    radius: Appearance.rounding.full
                                    color: panel.viewMode === index
                                        ? Appearance.m3colors.m3secondaryContainer
                                        : "transparent"

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        iconSize: 20
                                        fill: panel.viewMode === index ? 1 : 0
                                        color: panel.viewMode === index
                                            ? Appearance.m3colors.m3onSecondaryContainer
                                            : Appearance.m3colors.m3onSurfaceVariant
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: panel.viewMode = index
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.preferredWidth: 8 }

                    Rectangle {
                        Layout.preferredWidth: 320
                        Layout.preferredHeight: 40
                        radius: Appearance.rounding.full
                        color: Appearance.m3colors.m3surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 8

                            MaterialSymbol {
                                text: "search"
                                iconSize: 18
                                color: Appearance.m3colors.m3onSurfaceVariant
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: Text.AlignVCenter
                                color: Appearance.m3colors.m3onSurface
                                font.pixelSize: Appearance.font.pixelSize.normal
                                selectionColor: Appearance.m3colors.m3primary
                                selectedTextColor: Appearance.m3colors.m3onPrimary
                                clip: true

                                onTextChanged: panel.searchText = text

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Search games"
                                    color: Appearance.m3colors.m3outline
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    visible: searchInput.text.length === 0
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Escape)
                                        rootScope.close()
                                    else if (event.key === Qt.Key_Down) {
                                        if (viewLoader.item)
                                            viewLoader.item.selectFirst()
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                    }

                    RippleButton {
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: 20
                        colBackground: panel.sortMode !== 0 ? Appearance.m3colors.m3secondaryContainer : "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: panel.sortMode = (panel.sortMode + 1) % 3

                        StyledToolTip {
                            text: ["Sort: Name", "Sort: Recently played", "Sort: Playtime"][panel.sortMode]
                        }

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: ["sort_by_alpha", "history", "schedule"][panel.sortMode]
                            iconSize: 22
                            color: panel.sortMode !== 0
                                ? Appearance.m3colors.m3onSecondaryContainer
                                : Appearance.m3colors.m3onSurface
                        }
                    }

                    RippleButton {
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: 20
                        colBackground: panel.installedOnly ? Appearance.m3colors.m3secondaryContainer : "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: panel.installedOnly = !panel.installedOnly

                        StyledToolTip { text: panel.installedOnly ? "Showing installed only" : "Show installed only" }

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "download_done"
                            iconSize: 22
                            color: panel.installedOnly
                                ? Appearance.m3colors.m3onSecondaryContainer
                                : Appearance.m3colors.m3onSurface
                        }
                    }

                    RippleButton {
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: 20
                        colBackground: panel.showHidden ? Appearance.m3colors.m3secondaryContainer : "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: panel.showHidden = !panel.showHidden

                        StyledToolTip { text: panel.showHidden ? "Showing hidden games" : "Show hidden games" }

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: panel.showHidden ? "visibility" : "visibility_off"
                            iconSize: 22
                            color: panel.showHidden
                                ? Appearance.m3colors.m3onSecondaryContainer
                                : Appearance.m3colors.m3onSurface
                        }
                    }

                    RippleButton {
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: 20
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: panel.surpriseMe()

                        StyledToolTip { text: "Surprise me — launch a random game" }

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "casino"
                            iconSize: 22
                            color: Appearance.m3colors.m3onSurface
                        }
                    }

                    RippleButton {
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: 20
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        enabled: !Games.scanning
                        onClicked: Games.scan()

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 22
                            color: Games.scanning
                                ? Appearance.m3colors.m3onSurfaceVariant
                                : Appearance.m3colors.m3onSurface

                            RotationAnimator on rotation {
                                running: Games.scanning
                                from: 0; to: 360
                                duration: 1000
                                loops: Animation.Infinite
                            }
                        }
                    }

                    RippleButton {
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: 20
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: rootScope.close()

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 22
                        }
                    }
                }

                Item { Layout.preferredHeight: 20 }

                // ---- filter tabs + count ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ["All", "Steam", "Heroic", "AppImages", "Native", "ROMs"]

                        Rectangle {
                            id: chip
                            required property int index
                            required property string modelData

                            property bool isActive: panel.tabIndex === index

                            Layout.preferredHeight: 32
                            implicitWidth: chipRow.implicitWidth + 24
                            radius: Appearance.rounding.small
                            color: chip.isActive ? Appearance.m3colors.m3secondaryContainer : "transparent"
                            border.width: chip.isActive ? 0 : 1
                            border.color: Appearance.m3colors.m3outlineVariant

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: chip.isActive
                                    text: "check"
                                    iconSize: 16
                                    color: Appearance.m3colors.m3onSecondaryContainer
                                }

                                StyledText {
                                    text: chip.modelData
                                    color: chip.isActive ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurfaceVariant
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: chip.isActive ? Font.DemiBold : Font.Normal
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.tabIndex = chip.index
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: panel.filteredGames.length + " games"
                        color: Appearance.m3colors.m3onSurfaceVariant
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }

                Item { Layout.preferredHeight: 16 }

                // ---- continue playing shelf ----
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: panel.tabIndex === 0 && panel.searchText.length === 0
                        && !panel.romsActive && panel.recentGames.length > 0

                    StyledText {
                        text: "Continue playing"
                        color: Appearance.m3colors.m3onSurface
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 268
                        orientation: ListView.Horizontal
                        spacing: 14
                        clip: true
                        model: panel.recentGames
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: GameCard {
                            required property var modelData
                            cardWidth: 150
                            gameData: modelData
                            onClicked: {
                                Games.launchGame(modelData)
                                rootScope.close()
                            }
                            onContextRequested: (gx, gy) => panel.openContextMenu(modelData, gx, gy)
                        }
                    }

                    Item { Layout.preferredHeight: 8 }
                }

                // ---- game view (switched by viewMode) ----
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Loader {
                        id: viewLoader
                        anchors.fill: parent
                        visible: !panel.romsActive
                        sourceComponent: {
                            switch (panel.viewMode) {
                                case 0: return gridComp
                                case 1: return carouselComp
                                case 2: return listComp
                                default: return gridComp
                            }
                        }

                        onLoaded: {
                            item.model = panel.filteredGames
                            item.launchRequested.connect((gameData) => {
                                Games.launchGame(gameData)
                                rootScope.close()
                            })
                            item.contextRequested.connect((gameData, gx, gy) => {
                                panel.openContextMenu(gameData, gx, gy)
                            })
                        }

                        Connections {
                            target: panel
                            function onFilteredGamesChanged() {
                                if (viewLoader.item)
                                    viewLoader.item.model = panel.filteredGames
                            }
                        }
                    }

                    RomBrowser {
                        id: romBrowser
                        anchors.fill: parent
                        visible: panel.romsActive
                        searchText: panel.searchText
                        onLaunchRequested: (gameData) => {
                            Games.launchGame(gameData)
                            rootScope.close()
                        }
                        onContextRequested: (gameData, gx, gy) => panel.openContextMenu(gameData, gx, gy)
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: !panel.romsActive && panel.filteredGames.length === 0

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: Games.scanning ? "hourglass_empty" : "sports_esports"
                            iconSize: 56
                            color: Appearance.m3colors.m3onSurfaceVariant

                            RotationAnimator on rotation {
                                running: Games.scanning
                                from: 0; to: 360
                                duration: 1500
                                loops: Animation.Infinite
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Games.scanning
                                ? "Scanning for games…"
                                : (panel.searchText.length > 0 ? "No games match your search" : "No games found")
                            color: Appearance.m3colors.m3onSurfaceVariant
                            font.pixelSize: Appearance.font.pixelSize.large
                        }
                    }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Appearance.m3colors.m3outlineVariant
                opacity: 0.3
            }

            // ---- context menu ----
            MouseArea {
                anchors.fill: parent
                visible: contextMenu.visible
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: contextMenu.visible = false
            }

            Rectangle {
                id: contextMenu
                visible: false
                width: 230
                height: menuCol.implicitHeight + 12
                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainer
                border.width: 1
                border.color: Appearance.m3colors.m3outlineVariant

                property var actions: {
                    var g = panel.ctxGame
                    if (!g) return []
                    var a = []
                    a.push({ icon: "info", label: "Details", action: "details" })
                    a.push({ icon: Games.isFavorite(g.appId) ? "star" : "star_outline",
                             label: Games.isFavorite(g.appId) ? "Remove favorite" : "Add favorite", action: "fav" })
                    a.push({ icon: g.installed ? "play_arrow" : "download",
                             label: g.installed ? "Launch" : "Install", action: "launch" })
                    if (g.storeUrl && g.storeUrl.length > 0)
                        a.push({ icon: "open_in_new", label: "Store page", action: "store" })
                    a.push({ icon: Games.isHidden(g.appId) ? "visibility" : "visibility_off",
                             label: Games.isHidden(g.appId) ? "Unhide" : "Hide", action: "hide" })
                    if (Games.canUninstall(g))
                        a.push({ icon: "delete", label: g.platform === "rom" ? "Delete ROM" : "Uninstall", action: "uninstall" })
                    return a
                }

                ColumnLayout {
                    id: menuCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    spacing: 0

                    Repeater {
                        model: contextMenu.actions

                        Rectangle {
                            id: menuRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: Appearance.rounding.small
                            color: rowMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                MaterialSymbol {
                                    text: menuRow.modelData.icon
                                    iconSize: 20
                                    color: Appearance.m3colors.m3onSurface
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: menuRow.modelData.label
                                    color: Appearance.m3colors.m3onSurface
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.doContextAction(menuRow.modelData.action)
                            }
                        }
                    }
                }
            }

            GameDetails {
                id: gameDetails
                anchors.fill: parent
                game: panel.detailsGame
                onRequestClose: gameDetails.shown = false
                onLaunchRequested: (g) => {
                    Games.launchGame(g)
                    rootScope.close()
                }
            }

            // ---- ROM delete confirmation ----
            Item {
                id: confirmDialog
                anchors.fill: parent
                visible: false

                Rectangle {
                    anchors.fill: parent
                    color: ColorUtils.transparentize(Appearance.m3colors.m3scrim, 0.4)
                    MouseArea { anchors.fill: parent; onClicked: confirmDialog.visible = false }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 400
                    implicitHeight: confirmCol.implicitHeight + 48
                    radius: Appearance.rounding.large
                    color: Appearance.m3colors.m3surfaceContainerHigh

                    MouseArea { anchors.fill: parent }

                    ColumnLayout {
                        id: confirmCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 24
                        spacing: 14

                        MaterialSymbol {
                            text: "delete"
                            iconSize: 32
                            color: Appearance.m3colors.m3error
                        }

                        StyledText {
                            text: "Delete this ROM?"
                            color: Appearance.m3colors.m3onSurface
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: (panel.confirmGame ? panel.confirmGame.name : "") + " will be permanently deleted from disk. This cannot be undone."
                            color: Appearance.m3colors.m3onSurfaceVariant
                            font.pixelSize: Appearance.font.pixelSize.small
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Item { Layout.fillWidth: true }

                            RippleButton {
                                implicitWidth: 100
                                implicitHeight: 40
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                onClicked: confirmDialog.visible = false
                                contentItem: StyledText {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: Appearance.m3colors.m3primary
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                }
                            }

                            RippleButton {
                                implicitWidth: 100
                                implicitHeight: 40
                                buttonRadius: Appearance.rounding.full
                                colBackground: Appearance.m3colors.m3error
                                colBackgroundHover: Appearance.m3colors.m3error
                                onClicked: {
                                    if (panel.confirmGame) Games.uninstall(panel.confirmGame)
                                    confirmDialog.visible = false
                                }
                                contentItem: StyledText {
                                    anchors.centerIn: parent
                                    text: "Delete"
                                    color: Appearance.m3colors.m3onError
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component { id: gridComp; GameLauncherGrid {} }
    Component { id: carouselComp; GameLauncherCarousel {} }
    Component { id: listComp; GameListView {} }

    IpcHandler {
        target: "gameLauncher"
        function toggle(): void {
            GlobalStates.gameLauncherOpen = !GlobalStates.gameLauncherOpen
        }
        function close(): void {
            GlobalStates.gameLauncherOpen = false
        }
        function open(): void {
            GlobalStates.gameLauncherOpen = true
        }
    }

    GlobalShortcut {
        name: "gameLauncherToggle"
        description: "Toggles game launcher"
        onPressed: GlobalStates.gameLauncherOpen = !GlobalStates.gameLauncherOpen
    }
}
