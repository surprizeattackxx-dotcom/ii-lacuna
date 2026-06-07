pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    signal closeRequested()

    color: Appearance.m3colors.m3surface
    radius: Appearance.rounding.normal + 8
    border.width: 1
    border.color: Appearance.m3colors.m3outlineVariant
    clip: true

    property string searchQuery: ""
    property string selectedCategory: "All"
    property int selectedIndex: 0

    readonly property var categoryMap: ({
        "AudioVideo": "Media", "Audio": "Media", "Video": "Media",
        "Development": "Development",
        "Education": "Education",
        "Game": "Games",
        "Graphics": "Graphics",
        "Network": "Internet",
        "Office": "Office",
        "Science": "Science",
        "Settings": "Settings",
        "System": "System",
        "Utility": "Utilities",
    })

    readonly property var categoryIcons: ({
        "All": "apps",
        "Media": "play_circle",
        "Development": "code",
        "Education": "school",
        "Games": "sports_esports",
        "Graphics": "palette",
        "Internet": "language",
        "Office": "business_center",
        "Science": "science",
        "Settings": "settings",
        "System": "computer",
        "Utilities": "build",
        "Other": "more_horiz",
    })

    readonly property list<DesktopEntry> allApps: {
        const seen = new Set()
        return DesktopEntries.applications.values.filter(app => {
            if (seen.has(app.id)) return false
            seen.add(app.id)
            return app.name && app.name.length > 0
        }).sort((a, b) => a.name.localeCompare(b.name))
    }

    readonly property list<string> availableCategories: {
        const cats = new Set()
        for (const app of root.allApps) {
            for (const rawCat of app.categories) {
                const mapped = root.categoryMap[rawCat]
                if (mapped) cats.add(mapped)
            }
        }
        return ["All", ...Array.from(cats).sort()]
    }

    function appMatchesCategory(app) {
        if (root.selectedCategory === "All") return true
        return app.categories.some(c => root.categoryMap[c] === root.selectedCategory)
    }

    readonly property var filteredApps: {
        const q = root.searchQuery.toLowerCase().trim()
        return root.allApps.filter(app => {
            if (!root.appMatchesCategory(app)) return false
            if (q === "") return true
            return app.name.toLowerCase().includes(q) ||
                (app.genericName && app.genericName.toLowerCase().includes(q)) ||
                app.categories.some(c => c.toLowerCase().includes(q))
        })
    }

    onFilteredAppsChanged: root.selectedIndex = 0
    onSelectedCategoryChanged: root.selectedIndex = 0

    function launchSelected() {
        const app = root.filteredApps[root.selectedIndex]
        if (app) {
            app.execute()
            root.closeRequested()
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.launchSelected()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredApps.length - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            searchInput.forceActiveFocus()
        } else if (event.text.length > 0 && !event.modifiers) {
            searchInput.text += event.text
            searchInput.forceActiveFocus()
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // Search bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "search"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.m3colors.m3onSurfaceVariant
            }

            ToolbarTextField {
                id: searchInput
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.normal
                placeholderText: root.selectedCategory === "All"
                    ? "Search all apps..."
                    : `Search in ${root.selectedCategory}...`
                focus: true

                Component.onCompleted: forceActiveFocus()
                onTextChanged: root.searchQuery = text

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (text.length > 0) {
                            text = ""
                        } else {
                            root.closeRequested()
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.launchSelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        appList.forceActiveFocus()
                        event.accepted = true
                    }
                }
            }

            StyledText {
                visible: root.searchQuery.length > 0 || root.selectedCategory !== "All"
                text: root.filteredApps.length + " apps"
                color: Appearance.m3colors.m3onSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }

        // Category chips
        Flickable {
            id: chipFlickable
            Layout.fillWidth: true
            implicitHeight: chipRow.implicitHeight
            contentWidth: chipRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            clip: true
            interactive: contentWidth > width

            RowLayout {
                id: chipRow
                spacing: 6

                Repeater {
                    model: ScriptModel { values: root.availableCategories }

                    delegate: RippleButton {
                        id: chipBtn
                        required property string modelData
                        required property int index

                        readonly property bool isSelected: root.selectedCategory === chipBtn.modelData

                        buttonRadius: Appearance.rounding.full
                        implicitHeight: 28
                        implicitWidth: chipInner.implicitWidth + 20
                        colBackground: isSelected ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHigh
                        colBackgroundHover: isSelected ? Appearance.colors.colPrimaryHover : Appearance.colors.colSurfaceContainerHighest
                        colRipple: isSelected ? Appearance.m3colors.m3onPrimary : Appearance.colors.colPrimaryContainerActive

                        onClicked: root.selectedCategory = chipBtn.modelData

                        RowLayout {
                            id: chipInner
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                text: root.categoryIcons[chipBtn.modelData] ?? "folder"
                                iconSize: Appearance.font.pixelSize.small
                                color: chipBtn.isSelected ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3onSurfaceVariant
                            }

                            StyledText {
                                text: chipBtn.modelData
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: chipBtn.isSelected ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        // App list
        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            focus: true
            model: ScriptModel { values: root.filteredApps }
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            Keys.forwardTo: [root]

            ScrollBar.vertical: StyledScrollBar {}

            delegate: Item {
                id: appDelegate
                required property var modelData
                required property int index
                width: appList.width
                height: 52

                readonly property bool isSelected: root.selectedIndex === appDelegate.index
                readonly property string subtitle: {
                    const g = appDelegate.modelData.genericName
                    if (g && g.length > 0 && g !== appDelegate.modelData.name) return g
                    for (const c of appDelegate.modelData.categories) {
                        const mapped = root.categoryMap[c]
                        if (mapped) return mapped
                    }
                    return ""
                }

                RippleButton {
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 8
                    buttonRadius: Appearance.rounding.normal
                    colBackground: appDelegate.isSelected
                        ? Appearance.colors.colPrimaryContainer
                        : (hovered ? Appearance.colors.colSurfaceContainerHigh : "transparent")
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHigh
                    colRipple: Appearance.colors.colPrimaryContainerActive

                    onClicked: {
                        root.selectedIndex = appDelegate.index
                        root.launchSelected()
                    }
                    onHoveredChanged: if (hovered) root.selectedIndex = appDelegate.index

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        IconImage {
                            source: Quickshell.iconPath(appDelegate.modelData.icon, "application-x-executable")
                            implicitSize: 32
                            smooth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: appDelegate.modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: appDelegate.isSelected
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.m3colors.m3onSurface
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: appDelegate.subtitle.length > 0
                                text: appDelegate.subtitle
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: appDelegate.isSelected
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.m3colors.m3onSurfaceVariant
                                opacity: 0.75
                            }
                        }
                    }
                }
            }
        }
    }
}
