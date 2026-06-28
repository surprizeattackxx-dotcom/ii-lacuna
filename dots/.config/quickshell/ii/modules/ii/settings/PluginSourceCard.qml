import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "."

Item {
    id: root
    required property var modelData
    required property int index

    readonly property var source: modelData
    readonly property bool isDefault: source.url === ExtensionManager.defaultSourceUrl && index === 0

    Layout.fillWidth: true
    implicitHeight: 80

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1

        RowLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 12

            MaterialShape {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                shapeString: ""
                color: source.enabled !== false ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "source"
                    iconSize: 28
                    color: source.enabled !== false ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    StyledText {
                        text: source.name
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }
                    ExtensionBadge {
                        label: Translation.tr("Default")
                        visible: isDefault
                    }
                    ExtensionBadge {
                        icon: source.enabled !== false ? "check_circle" : "cancel"
                        bgColor: source.enabled !== false ? Appearance.m3colors.m3successContainer : Appearance.colors.colLayer3
                        fgColor: source.enabled !== false ? Appearance.m3colors.m3success : Appearance.colors.colSubtext
                        tooltip: source.enabled !== false ? Translation.tr("Enabled") : Translation.tr("Disabled")
                    }
                }

                StyledText {
                    text: source.url
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideMiddle
                }
            }

            ColumnLayout {
                Layout.fillHeight: true
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                StyledSwitch {
                    checked: source.enabled !== false
                    onClicked: ExtensionManager.setPluginSourceEnabled(source.url, !checked)
                }

                RippleButton {
                    Layout.alignment: Qt.AlignRight
                    implicitHeight: 28
                    implicitWidth: 28
                    padding: 0
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colErrorContainer
                    visible: !isDefault
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "delete"
                        iconSize: 18
                        color: Appearance.colors.colError
                    }
                    onClicked: ExtensionManager.removePluginSource(source.url)
                }
            }
        }
    }
}
