import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.ii.settings
import QtQuick.Controls as QQC2

ContentPage {
    id: page
    readonly property int index: 6
    property bool register: parent.register ?? false
    forceWidth: true

    property int activeTab: 0
    readonly property var tabs: [
        { id: "installed", label: Translation.tr("Installed"), icon: "download" },
        { id: "available", label: Translation.tr("Available"), icon: "explore" },
        { id: "sources", label: Translation.tr("Sources"), icon: "source" }
    ]

    function installFromUrl() {
        let input = customUrlField.textFieldText.trim()
        if (!input) return

        if (input.match(/^(https?:\/\/|git@|git:\/\/)/)) {
            let url = input
            let parts = url.replace(/\.git$/, "").split("/")
            let repoName = parts[parts.length - 1]
            if (!repoName) return
            ExtensionManager.installExtension(url, repoName, "main", url, true)
        } else {
            ExtensionManager.installLocalExtension(input)
        }

        page.showCustomUrlInput = false
        customUrlField.textFieldText = ""
    }

    property bool showCustomUrlInput: false

    ContentSection {
        icon: "extension"
        title: Translation.tr("Extensions")

        // Tab bar
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 6

            Repeater {
                model: page.tabs
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    implicitHeight: 32
                    implicitWidth: tabLabel.implicitWidth + 32
                    radius: Appearance.rounding.full
                    color: page.activeTab === index ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: 16
                            color: page.activeTab === index ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                        StyledText {
                            id: tabLabel
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: page.activeTab === index ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.activeTab = index
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Custom URL install button
            RippleButton {
                implicitHeight: 32
                padding: 12
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                contentItem: RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "link"
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: Translation.tr("Install from URL")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
                onClicked: page.showCustomUrlInput = !page.showCustomUrlInput
            }
        }

        // Custom URL input
        Rectangle {
            Layout.fillWidth: true
            visible: page.showCustomUrlInput
            implicitHeight: 44
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer3

                    QQC2.TextField {
                        id: customUrlField
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                        placeholderText: Translation.tr("GitHub URL or local path")
                        background: null
                        onAccepted: page.installFromUrl()
                    }
                }

                RippleButton {
                    implicitHeight: 36
                    implicitWidth: 36
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "download"
                        iconSize: 20
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    onClicked: page.installFromUrl()
                }
            }
        }

        // Global enable/disable toggle
        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("Extension system is in early beta stage. Please be cautious when installing extensions from untrusted sources.")
            ConfigSwitch {
                checked: Config.options.extensions.enable
                onClicked: Config.options.extensions.enable = !Config.options.extensions.enable
                StyledToolTip { text: Translation.tr("Enable/Disable extensions globally") }
            }
        }

        // Error message
        StyledText {
            Layout.fillWidth: true
            visible: ExtensionManager.error.length > 0
            text: ExtensionManager.error
            color: Appearance.colors.colError
            wrapMode: Text.Wrap
        }

        // Tab content
        StackLayout {
            Layout.fillWidth: true
            currentIndex: page.activeTab

            PluginInstalledTab {}

            PluginAvailableTab {}

            PluginSourcesTab {}
        }
    }
}
