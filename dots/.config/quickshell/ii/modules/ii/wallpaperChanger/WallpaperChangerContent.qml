import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.ii.bar

Item {
    id: root

    implicitHeight: 560
    implicitWidth: 1100

    readonly property string wpeWorkshopDir: "/mnt/wwn-0x50014ee65ea3c55b-part1/SteamLibrary/steamapps/workshop/content/431960"

    property string originalWallpaper: ""
    property int selectedIndex: 0
    property var combinedModel: []

    // Thumb dimensions — base size before scale transform
    readonly property int thumbW: 140
    readonly property int thumbH: 230
    // Logical width allocated per delegate in the ListView
    readonly property int delegateW: 200

    MatugenColors { id: _theme }

    FolderListModel {
        id: wpeFolder
        folder: Qt.resolvedUrl("file://" + root.wpeWorkshopDir)
        showFiles: false; showDirs: true; showDotAndDotDot: false
        onCountChanged: root.rebuildCombinedModel()
    }

    Component.onCompleted: {
        originalWallpaper = Config.options.background?.wallpaperPath ?? ""
        Wallpapers.generateThumbnail("large")
        rebuildCombinedModel()
        root.forceActiveFocus()
    }

    function rebuildCombinedModel() {
        const list = []
        for (let p of Wallpapers.wallpapers)
            list.push({ path: p, isWpe: false })
        for (let i = 0; i < wpeFolder.count; i++) {
            const dirPath = wpeFolder.get(i, "filePath")
            if (dirPath)
                list.push({ path: dirPath, isWpe: true })
        }
        combinedModel = list
        const idx = list.findIndex(e => e.path === root.originalWallpaper)
        if (idx >= 0) {
            Qt.callLater(() => { view.currentIndex = idx })
        }
    }

    // Returns a human-readable name for the center item.
    // For regular wallpapers: the filename without extension.
    // For WPE: the workshop folder basename (numeric ID).
    function wallpaperName(entry) {
        if (!entry) return ""
        const base = entry.path.split("/").pop() || entry.path
        // Strip extension for non-WPE
        if (!entry.isWpe) return base.replace(/\.[^/.]+$/, "")
        return base
    }

    function doPreview() {
        const entry = root.combinedModel[root.selectedIndex]
        if (entry) Wallpapers.apply(entry.path, Wallpapers.preferredDarkMode, Hyprland.focusedMonitor?.name ?? "", false)
    }

    function confirmSelected() {
        const entry = root.combinedModel[root.selectedIndex]
        if (entry) Wallpapers.apply(entry.path, Wallpapers.preferredDarkMode, Hyprland.focusedMonitor?.name ?? "", true)
        GlobalStates.wallpaperChangerOpen = false
    }

    function revertAndClose() {
        if (root.originalWallpaper !== "")
            Wallpapers.apply(root.originalWallpaper, Wallpapers.preferredDarkMode, Hyprland.focusedMonitor?.name ?? "", false)
        GlobalStates.wallpaperChangerOpen = false
    }

    function navigatePrev() {
        if (view.currentIndex > 0) {
            view.currentIndex--
            root.doPreview()
        }
    }

    function navigateNext() {
        if (view.currentIndex < root.combinedModel.length - 1) {
            view.currentIndex++
            root.doPreview()
        }
    }

    Keys.onLeftPressed: root.navigatePrev()
    Keys.onRightPressed: root.navigateNext()
    Keys.onReturnPressed: root.confirmSelected()
    Keys.onEnterPressed: root.confirmSelected()
    Keys.onEscapePressed: root.revertAndClose()

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0) root.navigateNext()
            else root.navigatePrev()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ── Carousel row ──────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.thumbH * 1.4 + 20

            Rectangle {
                id: prevBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36; radius: 18
                color: prevArea.containsMouse ? _theme.surface1 : _theme.surface0
                border.color: _theme.overlay1; border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                StyledText {
                    anchors.centerIn: parent
                    text: "‹"; font.pixelSize: 20; color: _theme.text
                }
                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.navigatePrev()
                }
            }

            ListView {
                id: view
                anchors {
                    left: prevBtn.right; leftMargin: 8
                    right: nextBtn.left; rightMargin: 8
                    top: parent.top; bottom: parent.bottom
                }
                model: root.combinedModel
                orientation: ListView.Horizontal
                snapMode: ListView.SnapToItem
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width - root.delegateW) / 2
                preferredHighlightEnd: (width - root.delegateW) / 2 + root.delegateW
                clip: false
                interactive: false  // wheel handled by WheelHandler above

                onCurrentIndexChanged: root.selectedIndex = currentIndex

                delegate: Item {
                    id: del
                    width: root.delegateW
                    height: view.height

                    readonly property real dist: Math.abs(index - view.currentIndex)
                    readonly property real itemScale: dist < 0.5 ? 1.35 : dist < 1.5 ? 0.90 : 0.65
                    readonly property real itemOpacity: dist < 0.5 ? 1.0 : dist < 1.5 ? 0.7 : 0.35

                    WallpaperThumb {
                        anchors.centerIn: parent
                        width: root.thumbW
                        height: root.thumbH
                        scale: del.itemScale
                        opacity: del.itemOpacity
                        thumbPath: modelData.path
                        thumbIndex: index
                        selected: index === view.currentIndex
                        isWpe: modelData.isWpe
                        directThumbPath: modelData.isWpe ? modelData.path + "/preview.gif" : ""

                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                        onClicked: {
                            view.currentIndex = index
                            root.doPreview()
                        }
                        onDoubleClicked: root.confirmSelected()
                    }
                }
            }

            Rectangle {
                id: nextBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36; radius: 18
                color: nextArea.containsMouse ? _theme.surface1 : _theme.surface0
                border.color: _theme.overlay1; border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                StyledText {
                    anchors.centerIn: parent
                    text: "›"; font.pixelSize: 20; color: _theme.text
                }
                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.navigateNext()
                }
            }
        }

        // ── Wallpaper name ────────────────────────────────────────────
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.maximumWidth: parent.width - 32
            text: root.wallpaperName(root.combinedModel[root.selectedIndex])
            font.pixelSize: Appearance.font.pixelSize.normal
            color: _theme.blue
            font.weight: Font.Medium
            elide: Text.ElideMiddle
        }

        // ── Action row ────────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Rectangle {
                width: cancelLabel.implicitWidth + 32; height: 34; radius: 8
                color: cancelArea.containsMouse ? _theme.surface1 : "transparent"
                border.color: _theme.overlay1; border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                StyledText {
                    id: cancelLabel
                    anchors.centerIn: parent
                    text: "Cancel  Esc"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: _theme.subtext0
                }
                MouseArea {
                    id: cancelArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.revertAndClose()
                }
            }

            Rectangle {
                width: applyLabel.implicitWidth + 32; height: 34; radius: 8
                color: applyArea.containsMouse ? Qt.lighter(_theme.blue, 1.15) : _theme.blue
                Behavior on color { ColorAnimation { duration: 100 } }
                StyledText {
                    id: applyLabel
                    anchors.centerIn: parent
                    text: "Apply  ↵"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: _theme.base; font.weight: Font.Bold
                }
                MouseArea {
                    id: applyArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.confirmSelected()
                }
            }
        }

        // ── Keyboard hints ────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            Repeater {
                model: [
                    { key: "← →", desc: "navigate" },
                    { key: "scroll", desc: "navigate" },
                    { key: "↵", desc: "apply" },
                    { key: "Esc", desc: "cancel" }
                ]
                Row {
                    spacing: 5
                    Rectangle {
                        width: kbdText.implicitWidth + 8
                        height: kbdText.implicitHeight + 4
                        radius: 3
                        color: _theme.surface1
                        border.color: _theme.overlay0; border.width: 1
                        StyledText {
                            id: kbdText
                            anchors.centerIn: parent
                            text: modelData.key
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: _theme.subtext1
                        }
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.desc
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: _theme.overlay1
                    }
                }
            }
        }
    }
}
