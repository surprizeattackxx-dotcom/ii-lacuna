import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "."

Popup {
    id: root
    property string pluginId: ""

    width: Math.min(500, parent?.width * 0.9 ?? 500)
    height: Math.min(600, parent?.height * 0.9 ?? 600)
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent

    background: Rectangle {
        color: Appearance.m3colors.m3surfaceContainerHigh
        radius: Appearance.rounding.large
    }

    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: {
                    let ext = ExtensionManager.installedExtensions[root.pluginId]
                    return ext ? ext.name : Translation.tr("Plugin Settings")
                }
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer0
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                }
                onClicked: root.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colLayer2
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: contentColumn.implicitHeight

            ColumnLayout {
                id: contentColumn
                anchors { left: parent.left; right: parent.right }
                spacing: 8

                ExtensionConfigPanel {
                    Layout.fillWidth: true
                    extensionId: root.pluginId
                    schema: {
                        let ext = ExtensionManager.installedExtensions[root.pluginId]
                        return ext?.configSchema || {}
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: {
                        let ext = ExtensionManager.installedExtensions[root.pluginId]
                        return !ext || !ext.configSchema || Object.keys(ext.configSchema).length === 0
                    }
                    text: Translation.tr("This extension has no configurable settings.")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    horizontalAlignment: Text.AlignHCenter
                    Layout.topMargin: 20
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8

            RippleButton {
                implicitHeight: 32
                padding: 12
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                contentItem: StyledText {
                    text: Translation.tr("Close")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSecondaryContainer
                }
                onClicked: root.close()
            }
        }
    }
}
