pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Widgets

// ROM browser (ported from illogical-impulse): system picker → per-system grid.
Item {
    id: root

    property string searchText: ""
    property var systems: []
    property var currentSystem: null
    property var roms: []
    property bool loadingSystems: false
    property bool loadingRoms: false
    property bool systemsScanned: false

    readonly property string scanScript: Quickshell.shellPath("Scripts/games/scan_roms.py")

    signal launchRequested(var gameData)
    signal selected(var gameData)

    function ensureScanned() {
        if (root.systemsScanned) return
        root.systemsScanned = true
        root.loadingSystems = true
        systemsProc.running = true
    }
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

    readonly property var filteredRoms: {
        if (!root.searchText || root.searchText.length === 0) return root.roms
        var s = root.searchText.toLowerCase()
        return root.roms.filter(r => ("" + r.name).toLowerCase().indexOf(s) !== -1)
    }
    readonly property var romGames: root.filteredRoms.map(r => ({
        name: r.name, art: r.art, artGen: r.artGen, platform: "rom",
        installed: true, playMinutes: 0, lastPlayed: 0,
        appId: r.path, storeUrl: "", launch: r.launch, size: 0
    }))

    Component.onCompleted: ensureScanned()

    Process {
        id: systemsProc
        command: ["python3", root.scanScript]
        stdout: StdioCollector {
            id: systemsOut
            onStreamFinished: {
                try { root.systems = JSON.parse(systemsOut.text) } catch (e) { root.systems = [] }
                root.loadingSystems = false
            }
        }
    }
    Process {
        id: romsProc
        stdout: StdioCollector {
            id: romsOut
            onStreamFinished: {
                try { root.roms = JSON.parse(romsOut.text) } catch (e) { root.roms = [] }
                root.loadingRoms = false
            }
        }
    }

    // ─── System picker ───
    NScrollView {
        anchors.fill: parent
        visible: root.currentSystem === null
        GridView {
            id: systemGrid
            anchors.fill: parent
            cellWidth: Math.round(260 * Style.uiScaleRatio)
            cellHeight: Math.round(110 * Style.uiScaleRatio)
            model: root.systems
            clip: true
            reuseItems: true
            delegate: Item {
                id: sysDelegate
                required property var modelData
                width: systemGrid.cellWidth
                height: systemGrid.cellHeight
                NBox {
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    color: sysMouse.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                    radius: Style.radiusL
                    Behavior on color { ColorAnimation { duration: 120 } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Style.marginXXS
                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: sysDelegate.modelData.name
                            pointSize: Style.fontSizeL
                            font.weight: Style.fontWeightBold
                            color: sysMouse.containsMouse ? Color.mOnPrimary : Color.mOnSurface
                        }
                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: sysDelegate.modelData.count + " games"
                            pointSize: Style.fontSizeS
                            color: sysMouse.containsMouse ? Color.mOnPrimary : Color.mOnSurfaceVariant
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
    }
    NBusyIndicator {
        anchors.centerIn: parent
        running: root.loadingSystems && root.currentSystem === null
        visible: running
        size: 40
    }

    // ─── Per-system ROM grid ───
    ColumnLayout {
        anchors.fill: parent
        visible: root.currentSystem !== null
        spacing: Style.marginS

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            NIconButton { icon: "arrow-left"; tooltipText: "Back to systems"; onClicked: root.back() }
            NText {
                text: root.currentSystem ? root.currentSystem.name : ""
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
            }
            NText {
                text: root.filteredRoms.length + " ROMs"
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }
            Item { Layout.fillWidth: true }
            NBusyIndicator { running: root.loadingRoms; visible: running; size: 22 }
        }

        NScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            GridView {
                id: romGrid
                anchors.fill: parent
                cellWidth: Math.round(196 * Style.uiScaleRatio)
                cellHeight: Math.round(300 * Style.uiScaleRatio)
                model: root.romGames
                clip: true
                cacheBuffer: cellHeight * 2
                reuseItems: true
                delegate: Item {
                    required property var modelData
                    width: romGrid.cellWidth
                    height: romGrid.cellHeight
                    GameCard {
                        anchors.centerIn: parent
                        cardWidth: Math.round(180 * Style.uiScaleRatio)
                        gameData: parent.modelData
                        onClicked: Games.launchGame(parent.modelData)
                        onContextRequested: root.selected(parent.modelData)
                    }
                }
            }
        }
    }
}
