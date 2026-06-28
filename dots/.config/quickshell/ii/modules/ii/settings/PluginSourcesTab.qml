import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "."

ColumnLayout {
    id: root

    property bool showAddSourceInput: false

    Component.onCompleted: {
        // Ensure default source exists if no sources
        if (ExtensionManager.pluginSources.length === 0) {
            ExtensionManager.addPluginSource(ExtensionManager.defaultSourceName, ExtensionManager.defaultSourceUrl)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: Translation.tr("Plugin Sources")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer0
            }

            RippleButton {
                implicitHeight: 28
                padding: 10
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer3
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Register All Local Plugins")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer0
                }
                onClicked: ExtensionManager.registerAllLocal("/home/donnie/Projects/legacy-v4-plugins")
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                implicitHeight: 28
                padding: 10
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Add Source")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimaryContainer
                }
                onClicked: root.showAddSourceInput = !root.showAddSourceInput
            }
        }

        // Add source input
        Rectangle {
            Layout.fillWidth: true
            visible: root.showAddSourceInput
            implicitHeight: addSourceLayout.implicitHeight + 20
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer2

            ColumnLayout {
                id: addSourceLayout
                anchors { fill: parent; margins: 10 }
                spacing: 8

                StyledText {
                    text: Translation.tr("Add a plugin repository source")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer0
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer3
                        border.width: 1
                        border.color: Appearance.colors.colLayer4

                        TextField {
                            id: nameField
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer0
                            placeholderText: Translation.tr("Source name")
                            background: null
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 300
                        implicitHeight: 36
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer3
                        border.width: 1
                        border.color: Appearance.colors.colLayer4

                        TextField {
                            id: urlField
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer0
                            placeholderText: "https://github.com/user/repo"
                            background: null
                        }
                    }

                    RippleButton {
                        implicitHeight: 36
                        implicitWidth: 36
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colPrimaryContainer
                        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                        enabled: nameField.text.trim().length > 0 && urlField.text.trim().length > 0
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "add"
                            iconSize: 20
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        onClicked: {
                            if (ExtensionManager.addPluginSource(nameField.text.trim(), urlField.text.trim())) {
                                nameField.text = ""
                                urlField.text = ""
                                root.showAddSourceInput = false
                            }
                        }
                    }
                }
            }
        }

        // Source list
        Repeater {
            model: ExtensionManager.pluginSources
            delegate: PluginSourceCard {
                Layout.fillWidth: true
            }
        }

        // Empty state
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 40
            visible: ExtensionManager.pluginSources.length === 0
            text: Translation.tr("No plugin sources configured. Add one above.")
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.normal
        }
    }
}
