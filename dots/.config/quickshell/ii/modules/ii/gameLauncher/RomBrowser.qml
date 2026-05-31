import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string searchText: ""
    signal launchRequested(var gameData)
    signal contextRequested(var gameData, real globalX, real globalY)

    property var systems: []
    property var currentSystem: null
    property var roms: []
    property bool loadingSystems: true
    property bool loadingRoms: false
    property bool systemsScanned: false

    readonly property string scanScript: Directories.scriptPath + "/games/scan_roms.py"

    function ensureScanned() {
        if (root.systemsScanned) return
        root.systemsScanned = true
        systemsProc.running = true
    }
    onVisibleChanged: if (visible) ensureScanned()
    Component.onCompleted: if (visible) ensureScanned()

    readonly property var filteredRoms: {
        if (!root.searchText || root.searchText.length === 0) return root.roms
        var s = root.searchText.toLowerCase()
        return root.roms.filter(r => r.name.toLowerCase().indexOf(s) !== -1)
    }

    readonly property var romGames: root.filteredRoms.map(r => ({
        name: r.name, art: r.art, artGen: r.artGen, platform: "rom",
        installed: true, playMinutes: 0, lastPlayed: 0,
        appId: r.path, storeUrl: "", launch: r.launch
    }))

    function openSystem(sys) {
        root.currentSystem = sys
        root.roms = []
        root.loadingRoms = true
        romsProc.command = ["python3", root.scanScript, "--roms"].concat(sys.dirs)
        romsProc.running = true
    }
    function back() {
        root.currentSystem = null
        root.roms = []
    }
    function selectFirst() {}
    function focusSearch() {}

    function gamepad(action) {
        if (root.currentSystem === null) {
            systemGrid.navActive = true
            if (action === "up") systemGrid.moveCurrentIndexUp()
            else if (action === "down") systemGrid.moveCurrentIndexDown()
            else if (action === "left") systemGrid.moveCurrentIndexLeft()
            else if (action === "right") systemGrid.moveCurrentIndexRight()
            else if (action === "a" || action === "start") {
                if (systemGrid.currentIndex < 0) systemGrid.currentIndex = 0
                else if (systemGrid.currentIndex < root.systems.length)
                    root.openSystem(root.systems[systemGrid.currentIndex])
            }
        } else {
            if (action === "up") romGrid.navUp()
            else if (action === "down") romGrid.navDown()
            else if (action === "left") romGrid.navLeft()
            else if (action === "right") romGrid.navRight()
            else if (action === "a" || action === "start") {
                if (romGrid.currentIndex < 0) romGrid.ensureSelected()
                else romGrid.activate()
            }
        }
    }

    Process {
        id: systemsProc
        command: ["python3", root.scanScript]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.systems = JSON.parse(text) } catch (e) { root.systems = [] }
                root.loadingSystems = false
            }
        }
    }

    Process {
        id: romsProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.roms = JSON.parse(text) } catch (e) { root.roms = [] }
                root.loadingRoms = false
            }
        }
    }

    // ---- system picker ----
    GridView {
        id: systemGrid
        anchors.fill: parent
        visible: root.currentSystem === null
        clip: true
        cellWidth: 240
        cellHeight: 130
        model: root.systems
        keyNavigationWraps: false
        property bool navActive: false

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
            id: sysDelegate
            required property var modelData
            required property int index
            width: systemGrid.cellWidth
            height: systemGrid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 8
                radius: Appearance.rounding.large
                color: (sysMouse.containsMouse || (systemGrid.navActive && systemGrid.currentIndex === sysDelegate.index))
                    ? Appearance.m3colors.m3secondaryContainer
                    : Appearance.m3colors.m3surfaceContainerHigh

                Behavior on color { ColorAnimation { duration: 120 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 48

                        Image {
                            id: logoImg
                            anchors.fill: parent
                            source: sysDelegate.modelData.logo ? "file://" + sysDelegate.modelData.logo : ""
                            fillMode: Image.PreserveAspectFit
                            sourceSize.height: 96
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "videogame_asset"
                            iconSize: 34
                            color: Appearance.m3colors.m3onSurface
                            visible: !logoImg.visible
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !logoImg.visible
                        text: sysDelegate.modelData.name
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.m3colors.m3onSurface
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: sysDelegate.modelData.count + " games"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }
                }

                MouseArea {
                    id: sysMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openSystem(sysDelegate.modelData)
                }
            }
        }
    }

    // ---- per-system rom grid ----
    ColumnLayout {
        anchors.fill: parent
        visible: root.currentSystem !== null
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RippleButton {
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: 18
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.back()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: 22
                }
            }

            StyledText {
                text: root.currentSystem ? root.currentSystem.name : ""
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                color: Appearance.m3colors.m3onSurface
            }

            StyledText {
                Layout.fillWidth: true
                text: root.filteredRoms.length + " games"
                color: Appearance.m3colors.m3onSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

        GameLauncherGrid {
            id: romGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.romGames
            onLaunchRequested: (gameData) => root.launchRequested(gameData)
            onContextRequested: (gameData, gx, gy) => root.contextRequested(gameData, gx, gy)
        }
    }

    // ---- loading / empty ----
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12
        visible: (root.currentSystem === null && (root.loadingSystems || root.systems.length === 0))
            || (root.currentSystem !== null && root.loadingRoms)

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: (root.loadingSystems || root.loadingRoms) ? "hourglass_empty" : "sd_card"
            iconSize: 56
            color: Appearance.m3colors.m3onSurfaceVariant
            RotationAnimator on rotation {
                running: root.loadingSystems || root.loadingRoms
                from: 0; to: 360; duration: 1500; loops: Animation.Infinite
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: (root.loadingSystems || root.loadingRoms)
                ? "Loading ROMs…"
                : "No ROMs found — check your ROM directory config"
            color: Appearance.m3colors.m3onSurfaceVariant
            font.pixelSize: Appearance.font.pixelSize.large
        }
    }
}
