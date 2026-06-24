import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: page
    readonly property int index: 0
    property bool register: parent.register ?? false
    forceWidth: true
    interactive: false

    // ── Carousel / favourites state ──────────────────────────────────────────
    property bool allowHeavyLoad: false
    property ListModel favouritesCarouselModel: ListModel {}
    property int currentIndex: -1

    function refreshFavouritesCarousel() {
        favouritesCarouselModel.clear()

        let favs = [...Persistent.states.wallpaper.favourites]
        const currentWallpaper = Config.options.background.wallpaperPath
        const currentIndex = favs.indexOf(currentWallpaper)

        if (favs.length === 0) return
        if (currentIndex !== -1) {
            const elementsBefore = favs.slice(0, currentIndex)
            const elementsFromCurrent = favs.slice(currentIndex)
            favs = elementsFromCurrent.concat(elementsBefore)
        } else if (currentWallpaper !== "") {
            favs.unshift(currentWallpaper)
        }

        for (let i = 0; i < favs.length; i++) {
            const path = favs[i]
            const fileName = path.split('/').pop()
            const name = (path === currentWallpaper && currentIndex === -1) ? "current-wallpaper" : fileName
            favouritesCarouselModel.append({ filePath: path, fileName: name })
        }
    }

    Component.onCompleted: Qt.callLater(() => {
        page.allowHeavyLoad = true
        page.refreshFavouritesCarousel()
    })

    Connections {
        target: Persistent.states.wallpaper
        function onFavouritesChanged() {
            page.refreshFavouritesCarousel()
        }
    }

    // ── Random wallpaper processes ────────────────────────────────────────────
    Process {
        id: fetchwallProc
        stdout: SplitParser {}
        stderr: SplitParser {}
        onExited: (code, status) => {
            monitorPreviewsContainer.refreshCount++
        }
    }

    Process {
        id: osuWallProc
        stdout: SplitParser {}
        stderr: SplitParser {}
        onExited: (code, status) => {
            monitorPreviewsContainer.refreshCount++
        }
    }

    // ── WPE picker state ──────────────────────────────────────────────────────
    property bool wpePickerOpen: false
    property string wpeSelectedMonitor: ""
    property string wpeApplyingPath: ""
    property var wpeWallpapers: []

    property string wpeExpandedPath: ""
    property string wpeExpandedTitle: ""
    property var wpeExpandedProps: []
    property var wpeExpandedValues: ({})

    Process {
        id: wpeEnumProc
        command: ["python3", "-c",
            "import os,json\n" +
            "base='/mnt/wwn-0x50014ee65ea3c55b-part1/SteamLibrary/steamapps/workshop/content/431960'\n" +
            "rows=[]\n" +
            "try:\n" +
            "  for name in os.listdir(base):\n" +
            "    d=os.path.join(base,name)\n" +
            "    pj=os.path.join(d,'project.json')\n" +
            "    if not os.path.isfile(pj): continue\n" +
            "    try: t=json.load(open(pj)).get('title',name)\n" +
            "    except: t=name\n" +
            "    rows.append((t,name,d))\n" +
            "except Exception as e: print('ERR:'+str(e))\n" +
            "rows.sort()\n" +
            "for t,name,d in rows: print(name+'|'+d+'|'+t)\n"
        ]
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("ERR:")) {
                    return
                }
                const idx = data.indexOf("|")
                const idx2 = data.indexOf("|", idx + 1)
                if (idx < 0 || idx2 < 0) return
                const id = data.slice(0, idx)
                const path = data.slice(idx + 1, idx2)
                const title = data.slice(idx2 + 1)
                page.wpeWallpapers = [...page.wpeWallpapers, { id: id, path: path, title: title }]
            }
        }
        stderr: SplitParser {}
    }

    Process {
        id: wpeApplyProc
        stdout: SplitParser {}
        stderr: SplitParser {}
        onExited: (code, status) => {
            page.wpeApplyingPath = ""
            monitorPreviewsContainer.refreshCount++
        }
    }

    Process {
        id: wpePropsProc
        stdout: SplitParser {
            onRead: data => {
                // format: key|type|label|defaultValue|min|max|options(pipe-separated)
                const parts = data.split("|")
                if (parts.length < 4) return
                const key = parts[0], type = parts[1], label = parts[2], defVal = parts[3]
                const min = parseFloat(parts[4]) || 0
                const max = parseFloat(parts[5]) || 1
                const options = (parts[6] || "").length > 0 ? parts[6].split(";;") : []
                if (!(key in page.wpeExpandedValues)) {
                    const m = Object.assign({}, page.wpeExpandedValues)
                    m[key] = defVal
                    page.wpeExpandedValues = m
                }
                page.wpeExpandedProps = [...page.wpeExpandedProps, {
                    key: key, type: type, label: label,
                    defaultValue: defVal, min: min, max: max, options: options
                }]
            }
        }
        stderr: SplitParser {}
    }

    // ── Light/dark toggle button ──────────────────────────────────────────────
    component SmallLightDarkPreferenceButton: RippleButton {
        id: smallLightDarkPreferenceButton
        required property bool dark
        property color colText: enabled ? toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2 : Appearance.colors.colOnLayer3
        padding: 5
        Layout.fillWidth: true
        toggled: Appearance.m3colors.darkmode === dark
        colBackground: Appearance.colors.colLayer2
        onClicked: {
            Quickshell.execDetached([Directories.darkModeToggleScriptPath, dark ? "dark" : "light"]);
            MaterialThemeLoader.reloadAfterExternalColorChange();
        }
        StyledToolTip {
            extraVisibleCondition: !smallLightDarkPreferenceButton.enabled
            text: Translation.tr("Custom color scheme has been selected")
        }
        contentItem: Item {
            anchors.centerIn: parent
            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    iconSize: 30
                    text: dark ? "dark_mode" : "light_mode"
                    fill: toggled ? 1 : 0
                    color: smallLightDarkPreferenceButton.colText
                }
                StyledText {
                    visible: !carouselWrapper.expanded
                    Layout.alignment: Qt.AlignHCenter
                    text: dark ? Translation.tr("Dark") : Translation.tr("Light")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: smallLightDarkPreferenceButton.colText
                }
            }
        }
    }

    // ── Wallpaper & Colors ────────────────────────────────────────────────────
    ContentSection {
        icon: "format_paint"
        title: Translation.tr("Wallpaper & Colors")
        tooltip: Translation.tr("Favourite your wallpapers from wallpaper selector for them to be visible in the carousel")
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true

            Item {
                id: carouselWrapper
                implicitWidth: 360
                implicitHeight: 220

                readonly property bool expanded: implicitWidth > 400

                PropertyAnimation {
                    id: expandAnimation
                    target: carouselWrapper
                    property: "implicitWidth"
                    to: 450
                    duration: 450
                    easing.type: Easing.OutCubic
                }
                PropertyAnimation {
                    id: shrinkAnimation
                    target: carouselWrapper
                    property: "implicitWidth"
                    to: 360
                    duration: 450
                    easing.type: Easing.OutCubic
                }

                Carousel {
                    id: favouritesCarousel
                    implicitWidth: parent.implicitWidth
                    implicitHeight: parent.implicitHeight
                    
                    showBadges: true
                    showOpenningAnimation: true

                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0

                    model: page.favouritesCarouselModel
                    visible: page.favouritesCarouselModel.count > 0
                    onItemClicked: (index, modelData) => {
                        shrinkAnimation.running = true
                        favouritesCarousel.currentIndex = 0
                        favouritesCarousel.snapToIndex(0)
                        Wallpapers.select(modelData.filePath)
                    }

                    onPressedAny: () => {
                        expandAnimation.running = true
                    }

                    delegate: Item {
                        id: carouselItem
                        required property var modelData
                        required property int index

                        ThumbnailImage {
                            anchors.fill: parent
                            sourcePath: carouselItem.modelData.filePath
                            fillMode: Image.PreserveAspectCrop
                            generateThumbnail: true

                            // fix for resolution
                            thumbnailSizeName: Images.thumbnailSizeNameForDimensions(512, 512)
                            sourceSize: (512,512)
                        }
                    }
                }

                Timer {
                    // The text below is visible even if the favouritesCarousel is not empty, so we add a little delay before making it visible
                    interval: 200
                    running: true
                    onTriggered: {
                        emptyFavouritesColumn.canBeVisible = true
                    }
                }

                ColumnLayout {
                    id: emptyFavouritesColumn
                    property bool canBeVisible: false
                    opacity: page.favouritesCarouselModel.count === 0 && canBeVisible ? 1 : 0
                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                        verticalCenterOffset: -10
                    }
                    MaterialSymbol {
                        iconSize: 30
                        text: "star"
                        fill: 1
                        color: Appearance.colors.colOnLayer3
                        Layout.alignment: Qt.AlignHCenter
                    }
                    StyledText {
                        text: Translation.tr("No favourites yet\nAdd some from wallpaper selector")
                        font.pixelSize: Appearance.font.pixelSize.body
                        color: Appearance.colors.colOnLayer3
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    uniformCellSizes: true

                    SmallLightDarkPreferenceButton {
                        Layout.preferredHeight: 60
                        dark: false
                        enabled: Config.options.appearance.palette.type.startsWith("scheme")
                    }
                    SmallLightDarkPreferenceButton {
                        Layout.preferredHeight: 60
                        dark: true
                        enabled: Config.options.appearance.palette.type.startsWith("scheme")
                    }
                }

                Item {
                    id: colorGridItem
                    z: 1
                    Layout.fillWidth: true
                    implicitHeight: 180
                    readonly property bool mediaModeEnabled: Persistent.states.background.mediaMode.enabled

                    Loader {
                        z: 1
                        anchors.top: parent.top
                        anchors.topMargin: 60
                        anchors.horizontalCenter: parent.horizontalCenter
                        active: colorGridItem.mediaModeEnabled
                        sourceComponent: StyledText {
                            text: Translation.tr("Media mode enabled")
                            font.pixelSize: Appearance.font.pixelSize.large
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: colorGridItem.mediaModeEnabled
                        sourceComponent: Rectangle {
                            anchors.fill: parent
                            opacity: 0.5
                            color: Appearance.colors.colSecondaryContainer
                            radius: Appearance.rounding.small
                        }
                    }

                    StyledFlickable {
                        id: flickable
                        anchors.fill: parent
                        contentHeight: contentLayout.implicitHeight
                        contentWidth: width
                        clip: true
                        enabled: !colorGridItem.mediaModeEnabled

                        ColumnLayout {
                            id: contentLayout
                            width: flickable.width

                            Repeater {
                                model: [
                                    { customTheme: false, builtInTheme: false },
                                    { customTheme: false, builtInTheme: true },
                                    { customTheme: true, builtInTheme: false }
                                ]

                                delegate: ColorPreviewGrid {
                                    customTheme: modelData.customTheme
                                    builtInTheme: modelData.builtInTheme
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Monitor wallpaper previews ────────────────────────────────────────
        Item {
            id: monitorPreviewsContainer
            Layout.fillWidth: true
            implicitHeight: 180

            readonly property string monitorStateDir: Wallpapers.monitorStateDir
            property int refreshCount: 0
            property var monitorNames: []

            Process {
                id: monitorQueryProc
                command: ["bash","-c","hyprctl monitors -j | jq -r 'sort_by(.x) | .[].name'"]
                stdout: SplitParser {
                    onRead: data => {
                        var lines = data.split("\n")
                        for (var i = 0; i < lines.length; i++) {
                            var name = lines[i].trim()
                            if (name.length > 0 &&
                                monitorPreviewsContainer.monitorNames.indexOf(name) === -1) {
                                monitorPreviewsContainer.monitorNames =
                                [...monitorPreviewsContainer.monitorNames, name]
                            }
                        }
                    }
                }
                Component.onCompleted: running = true
            }

            property var displayMonitors:
            monitorNames.length > 0 ? monitorNames : [""]

            Row {
                anchors.fill: parent
                spacing: 8

                Repeater {
                    id: tileRepeater
                    model: monitorPreviewsContainer.displayMonitors

                    delegate: Item {
                        id: monitorTile
                        required property string modelData
                        required property int index

                        readonly property bool isFallback: modelData === ""

                        readonly property string stateFile:
                        isFallback ? ""
                        : monitorPreviewsContainer.monitorStateDir
                        + "/" + modelData + ".json"

                        property string wallpaperPath: ""

                        Process {
                            id: stateReader
                            command: ["bash", "-c", "cat '" + monitorTile.stateFile + "'"]
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    try {
                                        var d = JSON.parse(text)
                                        var p = d.previewPath || d.thumbnailPath || d.path || ""
                                        if (p.length > 0) {
                                            if (!p.startsWith("file://")) p = "file://" + p
                                            monitorTile.wallpaperPath = ""
                                            monitorTile.wallpaperPath = p
                                        }
                                    } catch(e) {}
                                }
                            }
                            Component.onCompleted: {
                                if (monitorTile.stateFile.length > 0) running = true
                            }
                        }
                        FileView {
                            id: stateWatcher
                            path: monitorTile.stateFile
                            watchChanges: true
                            onTextChanged: {
                                try {
                                    var d = JSON.parse(text)
                                    var p = d.previewPath || d.thumbnailPath || d.path || ""
                                    if (p.length > 0) {
                                        if (!p.startsWith("file://")) p = "file://" + p
                                        monitorTile.wallpaperPath = ""
                                        monitorTile.wallpaperPath = p
                                    }
                                } catch(e) {}
                            }
                        }
                        Connections {
                            target: Wallpapers
                            function onChanged() {
                                tileRefreshTimer.restart()
                            }
                        }
                        Connections {
                            target: monitorPreviewsContainer
                            function onRefreshCountChanged() {
                                stateReader.running = false
                                stateReader.running = true
                            }
                        }
                        Timer {
                            id: tileRefreshTimer
                            interval: 2500
                            repeat: false
                            onTriggered: {
                                stateReader.running = false
                                stateReader.running = true
                            }
                        }

                        width:
                        (monitorPreviewsContainer.width
                        - 8 * Math.max(monitorPreviewsContainer.displayMonitors.length - 1,0))
                        / Math.max(monitorPreviewsContainer.displayMonitors.length,1)

                        height: monitorPreviewsContainer.implicitHeight

                        Image {
                            anchors.fill: parent
                            sourceSize.width: parent.width
                            sourceSize.height: parent.height
                            fillMode: Image.PreserveAspectCrop
                            source: monitorTile.wallpaperPath
                            asynchronous: true
                            cache: false

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: monitorTile.width
                                    height: monitorTile.height
                                    radius: Appearance.rounding.normal
                                }
                            }

                            RippleButton {
                                anchors.fill: parent
                                colBackground: "transparent"
                                colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnPrimary, 0.85)
                                colRipple: ColorUtils.transparentize(Appearance.colors.colOnPrimary, 0.5)
                                onClicked: {
                                    if (monitorTile.isFallback) {
                                        Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode)
                                    } else {
                                        switchProc.monitor = monitorTile.modelData
                                        switchProc.running = true
                                    }
                                }
                            }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "hourglass_top"
                            color: Appearance.colors.colPrimary
                            iconSize: 32
                            z: -1
                        }

                        Process {
                            id: switchProc
                            property string monitor: ""
                            command: [
                                Directories.wallpaperSwitchScriptPath,
                                "--monitor", monitor
                            ]
                            onExited: (code, status) => {
                                stateReader.running = false
                                stateReader.running = true
                            }
                        }

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                margins: 8
                            }
                            implicitWidth: Math.min(monBadge.implicitWidth + 16, parent.width - 16)
                            implicitHeight: monBadge.implicitHeight + 6
                            color: Appearance.colors.colPrimary
                            radius: Appearance.rounding.full
                            visible: !monitorTile.isFallback
                            StyledText {
                                id: monBadge
                                anchors.centerIn: parent
                                text: monitorTile.modelData
                                color: Appearance.colors.colOnPrimary
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        Rectangle {
                            anchors {
                                bottom: parent.bottom
                                horizontalCenter: parent.horizontalCenter
                                margins: 8
                            }
                            implicitWidth: Math.min(fileBadge.implicitWidth + 16, parent.width - 16)
                            implicitHeight: fileBadge.implicitHeight + 6
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3)
                            radius: Appearance.rounding.full
                            visible: monitorTile.wallpaperPath.length > 0
                            StyledText {
                                id: fileBadge
                                anchors.centerIn: parent
                                property string fn: monitorTile.wallpaperPath.replace("file://", "").split("/").pop()
                                text: fn.length > 22 ? fn.slice(0, 19) + "..." : fn
                                color: Appearance.colors.colOnPrimary
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }
                    }
                }
            }
        }

        // ── Random wallpaper buttons ──────────────────────────────────────────
        ConfigRow {
            uniform: true
            Layout.fillWidth: true

            RippleButtonWithIcon {
                enabled: !fetchwallProc.running
                visible: true
                Layout.fillWidth: true
                buttonRadius: Appearance.rounding.small
                materialIcon: "ifl"
                mainText: fetchwallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: Konachan")
                onClicked: {
                    fetchwallProc.exec(["bash", FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/random/random_konachan_wall.sh`)])
                }
                StyledToolTip {
                    text: Translation.tr("Random wallpaper per monitor from Konachan\nEach monitor gets a unique image")
                }
            }
            RippleButtonWithIcon {
                enabled: !osuWallProc.running
                visible: true
                Layout.fillWidth: true
                buttonRadius: Appearance.rounding.small
                materialIcon: "ifl"
                mainText: osuWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: osu! seasonal")
                onClicked: {
                    osuWallProc.exec(["bash", FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/random/random_osu_wall.sh`)])
                }
                StyledToolTip {
                    text: Translation.tr("Random osu! seasonal background\nImage is saved to ~/Pictures/Wallpapers")
                }
            }
        }

        // ── Wallpaper Engine picker ───────────────────────────────────────────
        RippleButtonWithIcon {
            Layout.fillWidth: true
            buttonRadius: Appearance.rounding.small
            materialIcon: "animated_images"
            mainText: Translation.tr("Wallpaper Engine")
            onClicked: {
                page.wpePickerOpen = !page.wpePickerOpen
                if (page.wpePickerOpen && page.wpeWallpapers.length === 0 && !wpeEnumProc.running) {
                    wpeEnumProc.running = true
                }
            }
        }

        Revealer {
            id: wpeRevealer
            reveal: page.wpePickerOpen
            vertical: true
            Layout.fillWidth: true

            ColumnLayout {
                width: wpeRevealer.width
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: Translation.tr("Monitor:")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }

                    Repeater {
                        model: monitorPreviewsContainer.monitorNames
                        delegate: RippleButton {
                            required property string modelData
                            required property int index

                            Component.onCompleted: {
                                if (index === 0 && page.wpeSelectedMonitor === "")
                                    page.wpeSelectedMonitor = modelData
                            }

                            toggled: page.wpeSelectedMonitor === modelData
                            colBackground: Appearance.colors.colLayer2
                            colBackgroundToggled: Appearance.colors.colPrimary
                            buttonRadius: Appearance.rounding.full
                            padding: 0
                            implicitWidth: _monLabel.implicitWidth + 20
                            implicitHeight: 28
                            onClicked: page.wpeSelectedMonitor = modelData

                            contentItem: StyledText {
                                id: _monLabel
                                anchors.centerIn: parent
                                text: modelData
                                color: parent.toggled
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }
                    }

                    RippleButton {
                        toggled: page.wpeSelectedMonitor === "__all__"
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundToggled: Appearance.colors.colPrimary
                        buttonRadius: Appearance.rounding.full
                        padding: 0
                        implicitWidth: _allLabel.implicitWidth + 20
                        implicitHeight: 28
                        onClicked: page.wpeSelectedMonitor = "__all__"
                        contentItem: StyledText {
                            id: _allLabel
                            anchors.centerIn: parent
                            text: Translation.tr("All")
                            color: parent.toggled
                                ? Appearance.colors.colOnPrimary
                                : Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: wpeEnumProc.running || (!wpeEnumProc.running && page.wpeWallpapers.length === 0)
                    horizontalAlignment: Text.AlignHCenter
                    text: wpeEnumProc.running
                        ? Translation.tr("Loading wallpapers...")
                        : Translation.tr("No Wallpaper Engine wallpapers found.\nIs the Steam library mounted?")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1
                    wrapMode: Text.WordWrap
                }

                Flow {
                    id: wpeGrid
                    Layout.fillWidth: true
                    spacing: 8
                    visible: page.wpeWallpapers.length > 0

                    Repeater {
                        model: page.wpeWallpapers

                        delegate: Item {
                            required property var modelData
                            width: 118
                            height: 104

                            Rectangle {
                                anchors.fill: parent
                                color: Appearance.colors.colLayer2
                                radius: Appearance.rounding.small
                            }

                            Image {
                                id: _wpeThumb
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 76
                                fillMode: Image.PreserveAspectCrop
                                source: "file://" + modelData.path + "/preview.gif"
                                asynchronous: true
                                cache: true
                                sourceSize.width: width
                                sourceSize.height: height
                                clip: true
                            }

                            StyledText {
                                anchors.top: _wpeThumb.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.topMargin: 3
                                leftPadding: 4
                                rightPadding: 4
                                text: modelData.title
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                color: Appearance.colors.colOnLayer2
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.65)
                                visible: page.wpeApplyingPath === modelData.path

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "hourglass_top"
                                    color: Appearance.colors.colOnPrimary
                                    iconSize: 22
                                }
                            }

                            RippleButton {
                                anchors.fill: parent
                                colBackground: "transparent"
                                colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
                                colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.5)
                                buttonRadius: Appearance.rounding.small
                                enabled: !wpeApplyProc.running && page.wpeSelectedMonitor.length > 0

                                onClicked: {
                                    page.wpeApplyingPath = modelData.path
                                    {
                                        const _fw = FileUtils.trimFileProtocol(Directories.scriptPath) + "/colors/fetchwall.sh"
                                        if (page.wpeSelectedMonitor === "__all__") {
                                            const _mons = monitorPreviewsContainer.monitorNames
                                            const _cmds = _mons.map(m => `bash '${_fw}' --monitor '${m}' '${modelData.path}'`).join(" && ")
                                            wpeApplyProc.exec(["bash", "-c", _cmds])
                                        } else {
                                            wpeApplyProc.exec(["bash", _fw, "--monitor", page.wpeSelectedMonitor, modelData.path])
                                        }
                                    }
                                    if (page.wpeExpandedPath !== modelData.path) {
                                        page.wpeExpandedPath = modelData.path
                                        page.wpeExpandedTitle = modelData.title
                                        page.wpeExpandedProps = []
                                        page.wpeExpandedValues = ({})
                                        wpePropsProc.exec(["python3", "-c",
                                            "import json,sys,re\n" +
                                            "try:\n" +
                                            "  pj=json.load(open(sys.argv[1]+'/project.json'))\n" +
                                            "  props=pj.get('general',{}).get('properties',{})\n" +
                                            "  for key,v in props.items():\n" +
                                            "    if not isinstance(v,dict): continue\n" +
                                            "    t=v.get('type','')\n" +
                                            "    if t not in ('color','slider','combo','checkbox','textinput'): continue\n" +
                                            "    raw_label=v.get('text',key)\n" +
                                            "    for pfx in ('ui_browse_properties_','ui_browse_','ui_'):\n" +
                                            "      if raw_label.startswith(pfx): raw_label=raw_label[len(pfx):]; break\n" +
                                            "    label=re.sub(r'([A-Z])',r' \\1',raw_label.replace('_',' ')).strip().title()\n" +
                                            "    val=str(v.get('value',''))\n" +
                                            "    mn=str(v.get('min',0))\n" +
                                            "    mx=str(v.get('max',1))\n" +
                                            "    opts=v.get('options',[])\n" +
                                            "    if opts and isinstance(opts[0],dict): opts=[str(o.get('label',o.get('value',''))) for o in opts]\n" +
                                            "    else: opts=[str(o) for o in opts]\n" +
                                            "    print(key+'|'+t+'|'+label+'|'+val+'|'+mn+'|'+mx+'|'+';;'.join(opts))\n" +
                                            "except Exception as e: import sys; print('ERR:'+str(e),file=sys.stderr)\n",
                                            modelData.path
                                        ])
                                    }
                                }
                            }
                        }
                    }
                }

                Revealer {
                    id: wpePropsRevealer
                    reveal: page.wpeExpandedPath.length > 0 && page.wpeExpandedProps.length > 0
                    vertical: true
                    Layout.fillWidth: true

                    ColumnLayout {
                        width: wpePropsRevealer.width
                        spacing: 6

                        Item { implicitHeight: 2 }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Settings: ") + page.wpeExpandedTitle
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }

                        Repeater {
                            model: page.wpeExpandedProps

                            delegate: RowLayout {
                                id: wpePropsRepeaterDelegate
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                    Layout.preferredWidth: 120
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: modelData.type === "color"
                                    Layout.preferredWidth: visible ? 28 : 0
                                    Layout.preferredHeight: visible ? 28 : 0
                                    radius: Appearance.rounding.small
                                    color: {
                                        const v = page.wpeExpandedValues[modelData.key] || modelData.defaultValue
                                        return (v && v.length > 0) ? v : "#888888"
                                    }
                                    border.color: Appearance.colors.colOnLayer2
                                    border.width: 1
                                }
                                MaterialTextField {
                                    visible: modelData.type === "color"
                                    Layout.preferredWidth: 90
                                    text: page.wpeExpandedValues[modelData.key] !== undefined
                                        ? page.wpeExpandedValues[modelData.key]
                                        : modelData.defaultValue
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    onEditingFinished: {
                                        const m = Object.assign({}, page.wpeExpandedValues)
                                        m[modelData.key] = text
                                        page.wpeExpandedValues = m
                                    }
                                }

                                StyledSlider {
                                    visible: modelData.type === "slider"
                                    Layout.fillWidth: true
                                    from: modelData.min
                                    to: modelData.max
                                    value: parseFloat(page.wpeExpandedValues[modelData.key] !== undefined
                                        ? page.wpeExpandedValues[modelData.key]
                                        : modelData.defaultValue) || modelData.min
                                    onMoved: {
                                        const m = Object.assign({}, page.wpeExpandedValues)
                                        m[modelData.key] = value.toFixed(3)
                                        page.wpeExpandedValues = m
                                    }
                                }
                                StyledText {
                                    visible: modelData.type === "slider"
                                    text: page.wpeExpandedValues[modelData.key] !== undefined
                                        ? parseFloat(page.wpeExpandedValues[modelData.key]).toFixed(2)
                                        : modelData.defaultValue
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                    Layout.preferredWidth: 36
                                    horizontalAlignment: Text.AlignRight
                                }

                                Flow {
                                    visible: modelData.type === "combo"
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Repeater {
                                        model: modelData.options
                                        delegate: RippleButton {
                                            required property string modelData
                                            required property int index
                                            padding: 4
                                            toggled: page.wpeExpandedValues[wpePropsRepeaterDelegate.modelData.key] === modelData
                                            colBackground: toggled ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                                            buttonRadius: Appearance.rounding.small
                                            onClicked: {
                                                const m = Object.assign({}, page.wpeExpandedValues)
                                                m[wpePropsRepeaterDelegate.modelData.key] = modelData
                                                page.wpeExpandedValues = m
                                            }
                                            StyledText {
                                                text: parent.modelData
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: parent.toggled
                                                    ? Appearance.colors.colOnPrimary
                                                    : Appearance.colors.colOnLayer2
                                            }
                                        }
                                    }
                                }

                                CheckBox {
                                    visible: modelData.type === "checkbox"
                                    checked: {
                                        const v = page.wpeExpandedValues[modelData.key]
                                        return v !== undefined ? (v === "true" || v === "1") : (modelData.defaultValue === "true" || modelData.defaultValue === "1")
                                    }
                                    onToggled: {
                                        const m = Object.assign({}, page.wpeExpandedValues)
                                        m[modelData.key] = checked ? "1" : "0"
                                        page.wpeExpandedValues = m
                                    }
                                }

                                MaterialTextField {
                                    visible: modelData.type === "textinput"
                                    Layout.fillWidth: true
                                    text: page.wpeExpandedValues[modelData.key] !== undefined
                                        ? page.wpeExpandedValues[modelData.key]
                                        : modelData.defaultValue
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    onEditingFinished: {
                                        const m = Object.assign({}, page.wpeExpandedValues)
                                        m[modelData.key] = text
                                        page.wpeExpandedValues = m
                                    }
                                }

                                Item { Layout.fillWidth: true; visible: modelData.type !== "slider" && modelData.type !== "combo" && modelData.type !== "textinput" && modelData.type !== "checkbox" }
                            }
                        }

                        RippleButtonWithIcon {
                            id: wpeReapplyBtn
                            Layout.fillWidth: true
                            buttonRadius: Appearance.rounding.small
                            materialIcon: "check"
                            mainText: Translation.tr("Apply with these settings")
                            enabled: !wpeApplyProc.running && page.wpeSelectedMonitor.length > 0
                            onClicked: {
                                const fetchwall = FileUtils.trimFileProtocol(Directories.scriptPath) + "/colors/fetchwall.sh"
                                const vals = page.wpeExpandedValues
                                page.wpeApplyingPath = page.wpeExpandedPath
                                if (page.wpeSelectedMonitor === "__all__") {
                                    const mons = monitorPreviewsContainer.monitorNames
                                    const propStr = Object.keys(vals).map(k => `--wpe-property '${k}' '${vals[k]}'`).join(" ")
                                    const cmds = mons.map(m => `bash '${fetchwall}' --monitor '${m}' ${propStr} '${page.wpeExpandedPath}'`).join(" && ")
                                    wpeApplyProc.exec(["bash", "-c", cmds])
                                } else {
                                    const args = ["bash", fetchwall, "--monitor", page.wpeSelectedMonitor]
                                    for (const key of Object.keys(vals)) {
                                        args.push("--wpe-property", key, vals[key])
                                    }
                                    args.push(page.wpeExpandedPath)
                                    wpeApplyProc.exec(args)
                                }
                            }
                        }

                        Item { implicitHeight: 4 }
                    }
                }

                Item { implicitHeight: 4 }
            }
        }

        ConfigSwitch {
            buttonIcon: "ev_shadow"
            text: Translation.tr("Transparency")
            checked: Config.options.appearance.transparency.enable
            onCheckedChanged: {
                Config.options.appearance.transparency.enable = checked;
            }
        }
    }

    // ── Bar & screen ──────────────────────────────────────────────────────────
    ContentSection {
        icon: "screenshot_monitor"
        title: Translation.tr("Bar & screen")
        Layout.topMargin: -25

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Bar position")
                Layout.fillWidth: true
                ConfigSelectionArray {
                    currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                    onSelected: newValue => {
                        Config.options.bar.bottom = (newValue & 1) !== 0;
                        Config.options.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Top"),
                            icon: "arrow_upward",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Left"),
                            icon: "arrow_back",
                            value: 2
                        },
                        {
                            displayName: Translation.tr("Bottom"),
                            icon: "arrow_downward",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Right"),
                            icon: "arrow_forward",
                            value: 3
                        }
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Bar style")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: Config.options.bar.cornerStyle
                    onSelected: newValue => {
                        Config.options.bar.cornerStyle = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Hug"),
                            icon: "line_curve",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Float"),
                            icon: "page_header",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Rect"),
                            icon: "toolbar",
                            value: 2
                        }
                    ]
                }
            }
        }

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Screen round corner")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.appearance.fakeScreenRounding
                    onSelected: newValue => {
                        Config.options.appearance.fakeScreenRounding = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("No"),
                            icon: "close",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Yes"),
                            icon: "check",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Not fullscreen"),
                            icon: "fullscreen_exit",
                            value: 2
                        },
                        {
                            displayName: Translation.tr("Wrapped"),
                            icon: "capture",
                            value: 3
                        }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Rounding style")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: Config.options.appearance.sharpMode
                    onSelected: newValue => {
                        Config.options.appearance.sharpMode = newValue;
                        HyprlandSettings.setRounding(newValue ? 0 : Config.options.appearance.defaultBorderRadius);
                    }
                    options: [
                        {
                            displayName: Translation.tr("Default"),
                            icon: "rounded_corner",
                            value: false
                        },
                        {
                            displayName: Translation.tr("Sharp"),
                            icon: "square",
                            value: true
                        }
                    ]
                }
            }
        }

        ConfigSpinBox {
            visible: Config.options.appearance.fakeScreenRounding === 3
            icon: "line_weight"
            text: Translation.tr("Wrapped frame thickness")
            value: Config.options.appearance.wrappedFrameThickness
            from: 5
            to: 25
            stepSize: 1
            onValueChanged: {
                Config.options.appearance.wrappedFrameThickness = value;
            }
        }

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Bar background style")
                tooltip: Translation.tr("Adaptive style makes the bar background transparent when there are no active windows")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.bar.barBackgroundStyle
                    onSelected: newValue => {
                        Config.options.bar.barBackgroundStyle = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Visible"),
                            icon: "visibility",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Adaptive"),
                            icon: "masked_transitions",
                            value: 2
                        },
                        {
                            displayName: Translation.tr("Transparent"),
                            icon: "opacity",
                            value: 0
                        }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Hyprland layout")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: {
                        if (Persistent.states.hyprland.layout !== "scrolling") return "default"
                        else return "scrolling"
                    }
                    onSelected: newValue => {
                        if (newValue === "scrolling") {
                            HyprlandSettings.setLayout("scrolling")
                        } else {
                            const defaultLayout = Config.options.hyprland.defaultHyprlandLayout
                            HyprlandSettings.setLayout(defaultLayout)
                        }
                    }
                    options: [
                        {
                            displayName: Translation.tr("Default"),
                            icon: "mobile_layout",
                            value: "default"
                        },
                        {
                            displayName: Translation.tr("Scrolling"),
                            icon: "view_carousel",
                            value: "scrolling"
                        }
                    ]
                }
            }
        }
    }

    // ── Notice ────────────────────────────────────────────────────────────────
    NoticeBox {
        Layout.fillWidth: true
        Layout.topMargin: -20
        text: Translation.tr('Not all options are available in this app. You should also check the config file by hitting the "Config file" button on the topleft corner or opening ~/.config/illogical-impulse/config.json manually.')

        RippleButtonWithIcon {
            id: copyPathButton
            property bool justCopied: false
            buttonRadius: Appearance.rounding.small
            materialIcon: justCopied ? "check" : "content_copy"
            mainText: justCopied ? Translation.tr("Path copied") : Translation.tr("Copy path")
            onClicked: {
                copyPathButton.justCopied = true
                Quickshell.clipboardText = FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                revertTextTimer.restart();
            }
            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
            colBackgroundHover: Appearance.colors.colPrimaryContainerHover
            colRipple: Appearance.colors.colPrimaryContainerActive

            Timer {
                id: revertTextTimer
                interval: 1500
                onTriggered: {
                    copyPathButton.justCopied = false
                }
            }
        }
    }
}
