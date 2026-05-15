
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Text {
            text: "MONITOR SETTINGS"
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.larger
            font.weight: Font.Bold
        }

        MonitorPopup {
            id: monitorPopup
            Layout.fillWidth: true
            Layout.preferredWidth: 900
            Layout.preferredHeight: 650
            Layout.minimumWidth: 700
        }
    }
}
