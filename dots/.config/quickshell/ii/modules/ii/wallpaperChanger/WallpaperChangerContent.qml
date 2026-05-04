import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root

    implicitHeight: 280
    implicitWidth: 1300

    // WPE workshop content dir — same path as in fetchwall.sh
    readonly property string wpeWorkshopDir: "/mnt/wwn-0x50014ee65ea3c55b-part1/SteamLibrary/steamapps/workshop/content/431960"

    property string originalWallpaper: ""
    property bool originalIsWpe: false
    property int selectedIndex: 0
    property int prevIndex: -1

    // Combined model: [{path, isWpe, previewPath}]
    property var combinedModel: []

    function isWpePath(p) {
        return p.indexOf("/431960/") >= 0 || p.indexOf("workshop/content") >= 0
    }

    function getWpePreviewPath(wpePath) {
        // Check standard preview filenames; default to preview.jpg
        // (QML can't do sync fs checks, just use jpg — it's the most common)
        return wpePath + "/preview.jpg"
    }

    // Slide-up from bottom on open
    property real slideY: root.implicitHeight
    transform: Translate { y: root.slideY }

    NumberAnimation on slideY {
        from: root.implicitHeight
        to: 0
        duration: 300
        easing.type: Easing.OutCubic
        running: true
    }

    Component.onCompleted: {
        originalWallpaper = Config.options.background?.wallpaperPath ?? ""
        originalIsWpe = root.isWpePath(originalWallpaper)
        Wallpapers.generateThumbnail("large")
        bgRect.forceActiveFocus()
        rebuildCombinedModel()
    }

    function rebuildCombinedModel() {
        const list = []
        for (let p of Wallpapers.wallpapers) {
            list.push({ path: p, isWpe: false, previewPath: p })
        }
        for (let i = 0; i < wpeFolder.count; i++) {
            const dirPath = wpeFolder.get(i, "filePath")
            if (!dirPath) continue
            list.push({ path: dirPath, isWpe: true, previewPath: dirPath + "/preview.jpg" })
        }
        combinedModel = list

        // Jump to current wallpaper
        const idx = list.findIndex(e => e.path === root.originalWallpaper)
        if (idx >= 0) {
            root.selectedIndex = idx
            Qt.callLater(() => wallpaperList.positionViewAtIndex(idx, ListView.Center))
        }
    }

    // WPE folder scanner
    FolderListModel {
        id: wpeFolder
        folder: Qt.resolvedUrl("file://" + root.wpeWorkshopDir)
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
        onCountChanged: root.rebuildCombinedModel()
    }

    // Connections to Wallpapers model changes
    Connections {
        target: Wallpapers
        function onWallpapersChanged() { root.rebuildCombinedModel() }
    }

    // Quick preview process — awww for images
    Process {
        id: previewProc
        property string focusedMonitor: Hyprland.focusedMonitor?.name ?? ""
    }

    // WPE preview process — writes state file + restarts wpe service
    Process {
        id: wpePreviewProc
        property string focusedMonitor: Hyprland.focusedMonitor?.name ?? ""
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Qt.rgba(
            Appearance.colors.colLayer0.r,
            Appearance.colors.colLayer0.g,
            Appearance.colors.colLayer0.b,
            0.93
        )
        radius: Appearance.rounding.medium
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                root.navigate(1)
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                root.navigate(-1)
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.confirmSelected()
            } else if (event.key === Qt.Key_Escape) {
                root.revertAndClose()
            }
            event.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "wallpaper"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    text: "Wallpaper"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                    font.weight: Font.Medium
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: "← → navigate   ↵ confirm   Esc cancel"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext0
                }
            }

            // Thumbnail strip
            ListView {
                id: wallpaperList
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: root.combinedModel
                currentIndex: root.selectedIndex
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

                delegate: WallpaperThumb {
                    required property var modelData
                    required property int index

                    thumbPath: modelData.path
                    directThumbPath: modelData.isWpe ? modelData.previewPath : ""
                    isWpe: modelData.isWpe
                    thumbIndex: index
                    selected: index === root.selectedIndex
                    revealing: index === root.selectedIndex && root.prevIndex !== root.selectedIndex

                    height: wallpaperList.height
                    width: Math.round(height * 16 / 9)

                    onClicked: {
                        root.selectedIndex = index
                        root.doPreview()
                        bgRect.forceActiveFocus()
                    }
                    onDoubleClicked: root.confirmSelected()
                }
            }
        }
    }

    function navigate(dir) {
        const count = root.combinedModel.length
        if (count === 0) return
        const newIdx = Math.max(0, Math.min(root.selectedIndex + dir, count - 1))
        if (newIdx === root.selectedIndex) return
        root.prevIndex = root.selectedIndex
        root.selectedIndex = newIdx
        wallpaperList.positionViewAtIndex(newIdx, ListView.Contain)
        root.doPreview()
    }

    function doPreview() {
        const entry = root.combinedModel[root.selectedIndex]
        if (!entry) return
        const mon = previewProc.focusedMonitor
        if (entry.isWpe) {
            doWpePreview(entry.path, mon)
        } else {
            previewProc.exec(["awww", "img", entry.path,
                "--outputs", mon,
                "--transition-type", "grow",
                "--transition-pos", "center",
                "--transition-duration", "0.5",
                "--transition-fps", "60",
                "--transition-step", "90"
            ])
        }
    }

    function doWpePreview(wpePath, monitor) {
        if (!monitor || monitor.length === 0) return
        const wpeId = wpePath.split("/").pop()
        const stateDir = FileUtils.trimFileProtocol(Directories.state) + "/user/generated/wallpaper/monitors"
        const stateFile = stateDir + "/" + monitor + ".json"
        // Preserve existing "path" thumbnail if present; fall back to preview image in WPE dir
        // Use jq to merge so we don't nuke the path field that the settings panel needs
        const previewFallback = [
            wpePath + "/preview.jpg",
            wpePath + "/preview.png",
            wpePath + "/preview.gif"
        ].map(p => `[ -f '${p}' ] && echo '${p}'`).join(" || ")
        const script = `
mkdir -p '${stateDir}'
EXISTING_PATH=$(jq -r '.path // empty' '${stateFile}' 2>/dev/null)
PREVIEW_PATH=$(${previewFallback} 2>/dev/null | head -1)
THUMB_PATH=\${EXISTING_PATH:-\$PREVIEW_PATH}
jq -n --arg m '${monitor}' --arg id '${wpeId}' --arg wp '${wpePath}' --arg tp "\$THUMB_PATH" \
  '{monitor:$m, wpe:true, wpe_id:$id, wpe_path:$wp} + (if $tp != "" then {path:$tp} else {} end)' \
  > '${stateFile}.tmp' && mv '${stateFile}.tmp' '${stateFile}'
systemctl --user restart 'wpe@${monitor}.service'`
        wpePreviewProc.exec(["bash", "-c", script])
    }

    function doWpeStop(monitor) {
        if (!monitor || monitor.length === 0) return
        wpePreviewProc.exec(["systemctl", "--user", "stop", "wpe@" + monitor + ".service"])
    }

    function confirmSelected() {
        const entry = root.combinedModel[root.selectedIndex]
        if (entry) Wallpapers.apply(entry.path, Appearance.m3colors.darkmode)
        GlobalStates.wallpaperChangerOpen = false
    }

    function revertAndClose() {
        const mon = previewProc.focusedMonitor
        if (root.originalWallpaper.length > 0) {
            if (root.originalIsWpe) {
                doWpePreview(root.originalWallpaper, mon)
            } else {
                // Stop any running WPE service first, then restore image
                previewProc.exec(["bash", "-c",
                    `systemctl --user stop 'wpe@${mon}.service' 2>/dev/null; awww img '${root.originalWallpaper}' --outputs '${mon}' --transition-type none`
                ])
            }
        }
        GlobalStates.wallpaperChangerOpen = false
    }
}
