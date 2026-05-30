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

            // ---- filtered model as JS array ----
            property var filteredGames: []

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
                    result.push(item)
                }
                result.sort((a, b) => {
                    var fa = Games.isFavorite(a.appId), fb = Games.isFavorite(b.appId)
                    if (fa !== fb) return fa ? -1 : 1
                    if (a.installed !== b.installed) return a.installed ? -1 : 1
                    return a.name.localeCompare(b.name)
                })
                panel.filteredGames = result
            }

            function scheduleRebuild() { rebuildTimer.restart() }

            Timer {
                id: rebuildTimer
                interval: 32
                onTriggered: panel.rebuildFilter()
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
            }

            onTabIndexChanged: panel.rebuildFilter()
            onSearchTextChanged: panel.rebuildFilter()
            Component.onCompleted: panel.rebuildFilter()

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    rootScope.close()
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
                        model: ["All", "Steam", "Heroic", "AppImages", "Native"]

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

                // ---- game view (switched by viewMode) ----
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Loader {
                        id: viewLoader
                        anchors.fill: parent
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
                        }

                        Connections {
                            target: panel
                            function onFilteredGamesChanged() {
                                if (viewLoader.item)
                                    viewLoader.item.model = panel.filteredGames
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: panel.filteredGames.length === 0

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
