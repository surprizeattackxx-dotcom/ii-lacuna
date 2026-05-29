import qs.modules.common
import qs.modules.common.widgets
import "./cards"
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    property bool compact: false

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        StyledPopupHeaderRow {
            Layout.fillWidth: true
            icon: "devices"
            label: "LocalSend"
        }

        Rectangle {
            Layout.fillWidth: true; height: 1
            color: Qt.rgba(Appearance.colors.colPrimary.r,
                           Appearance.colors.colPrimary.g,
                           Appearance.colors.colPrimary.b, 0.15)
        }

        LocalSendPill {}

        Loader {
            active: LocalSend.currentTransfer !== null
            visible: active
            Layout.fillWidth: true
            sourceComponent: LocalSendTransferCard {}
        }

        Loader {
            active: LocalSend.droppedFiles.length > 0 || LocalSend.discoveredDevices.length > 0
            visible: active
            Layout.fillWidth: true
            sourceComponent: LocalSendSendCard {}
        }

        StyledText {
            visible: !LocalSend.serverRunning && LocalSend.droppedFiles.length === 0
            text: "Start the server to receive files or drop files to send"
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
    }
}
