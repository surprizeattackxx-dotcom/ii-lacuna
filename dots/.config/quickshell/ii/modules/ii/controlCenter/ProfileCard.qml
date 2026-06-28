import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell

Rectangle {
    id: root
    implicitHeight: 64
    radius: Appearance.rounding.medium
    color: Appearance.m3colors.m3surfaceContainer

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: Appearance.colors.colPrimaryContainer

            MaterialSymbol {
                anchors.centerIn: parent
                text: "person"
                iconSize: 22
                color: Appearance.colors.colOnPrimaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            StyledText {
                text: SystemInfo.username || "user"
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.m3colors.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                text: SystemInfo.distroName || "Linux"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.m3colors.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        RowLayout {
            spacing: 4

            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "lock"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                }
                onClicked: Quickshell.execDetached("loginctl lock-session")
            }

            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "logout"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                }
                onClicked: Quickshell.execDetached("loginctl terminate-user $USER")
            }

            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "settings"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                }
                onClicked: Quickshell.execDetached(["qs", "-p", Directories.config + "/quickshell/noctalia-shell/settings-portal.qml"])
            }
        }
    }
}
