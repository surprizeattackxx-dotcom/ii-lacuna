import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import "."

ColumnLayout {
    id: root

    property string searchText: ""
    property string activeTag: "all"
    property var filteredPlugins: []
    property var allTags: []

    function refresh() {
        ExtensionManager.fetchAvailablePlugins()
    }

    function filter() {
        if (!Config.options.extensions.enable) {
            root.filteredPlugins = []
            return
        }

        let list = ExtensionManager.availablePlugins

        let installedIds = {}
        for (let id in ExtensionManager.installedExtensions) {
            installedIds[id] = true
        }

        // Filter by tag
        if (root.activeTag !== "all") {
            if (root.activeTag === "official") {
                list = list.filter(p => p.source && p.source.url === ExtensionManager.defaultSourceUrl)
            } else if (root.activeTag === "downloaded") {
                list = list.filter(p => installedIds[p.id])
            } else if (root.activeTag === "notDownloaded") {
                list = list.filter(p => !installedIds[p.id])
            } else if (root.activeTag === "updatable") {
                list = list.filter(p => {
                    let state = ExtensionManager.updateStates[p.id] || {}
                    return state.updateAvailable
                })
            } else {
                list = list.filter(p => p.tags && p.tags.includes(root.activeTag))
            }
        }

        // Filter by search text
        if (root.searchText.trim()) {
            let q = root.searchText.toLowerCase().trim()
            list = list.filter(p =>
                p.name?.toLowerCase().includes(q) ||
                p.description?.toLowerCase().includes(q) ||
                p.author?.toLowerCase().includes(q) ||
                p.sourceName?.toLowerCase().includes(q)
            )
        }

        root.filteredPlugins = list
    }

    function buildTags() {
        let tags = ["all", "official", "downloaded", "notDownloaded", "updatable"]
        let dynamicTags = {}
        for (let i = 0; i < ExtensionManager.availablePlugins.length; i++) {
            let p = ExtensionManager.availablePlugins[i]
            if (p.tags) {
                for (let t = 0; t < p.tags.length; t++) {
                    dynamicTags[p.tags[t]] = true
                }
            }
        }
        root.allTags = tags.concat(Object.keys(dynamicTags))
    }

    Component.onCompleted: {
        if (ExtensionManager.availablePlugins.length === 0) {
            ExtensionManager.fetchAvailablePlugins()
        }
        root.buildTags()
        root.filter()
    }

    Connections {
        target: ExtensionManager
        function onAvailablePluginsUpdated() {
            root.buildTags()
            root.filter()
        }
        function onExtensionInstalled(extId) { root.filter() }
        function onExtensionRemoved(extId) { root.filter() }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        // Search and refresh bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RippleButton {
                implicitHeight: 36
                implicitWidth: 36
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: ExtensionManager._registryFetching ? "hourglass_bottom" : "refresh"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }
                onClicked: root.refresh()
            }

            // Search input using existing TextField pattern from ExtensionCard
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer2
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: "search"
                        iconSize: 18
                        color: Appearance.colors.colSubtext
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        implicitHeight: 36
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                        placeholderText: Translation.tr("Search extensions...")
                        background: null

                        onTextChanged: {
                            root.searchText = text
                            Qt.callLater(function() { root.filter() })
                        }
                    }
                }
            }

            RippleButton {
                implicitHeight: 36
                implicitWidth: 36
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "info"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }
                onClicked: Qt.openUrlExternally("https://github.com/vaguesyntax/ii-vynx/blob/main/.github/EXTENSIONS.md")
            }
        }

        // Tag filter pills
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: root.allTags.length > 0

            Repeater {
                model: root.allTags
                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    property string tag: modelData

                    implicitHeight: 26
                    implicitWidth: tagLabel.implicitWidth + 16
                    radius: Appearance.rounding.full
                    color: root.activeTag === tag ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                    StyledText {
                        id: tagLabel
                        anchors.centerIn: parent
                        text: root.tagDisplayName(tag)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: root.activeTag === tag ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeTag = tag
                            root.filter()
                        }
                    }
                }
            }
        }

        // Plugin count
        StyledText {
            text: root.filteredPlugins.length + " " + Translation.tr("extensions found")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
        }

        // Available Plugin List
        Repeater {
            model: root.filteredPlugins
            delegate: AvailablePluginCard {
                Layout.fillWidth: true
            }
        }

        // Loading state
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 40
            visible: ExtensionManager._registryFetching && root.filteredPlugins.length === 0
            text: Translation.tr("Fetching available extensions...")
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.normal
        }

        // Empty state
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 40
            visible: !ExtensionManager._registryFetching && root.filteredPlugins.length === 0
            text: root.searchText.trim()
                ? Translation.tr("No extensions match your search")
                : Translation.tr("No extensions available. Try adding a plugin source in the Sources tab.")
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.normal
        }
    }

    function tagDisplayName(tag) {
        let names = {
            "all": Translation.tr("All"),
            "official": Translation.tr("Official"),
            "downloaded": Translation.tr("Installed"),
            "notDownloaded": Translation.tr("Not installed"),
            "updatable": Translation.tr("Updates available")
        }
        return names[tag] || tag
    }
}
