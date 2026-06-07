import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: rowLayout.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight
    property color colText: dropArea.containsDrag ? Appearance.colors.colPrimary : rootItem.highlighted ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
    property bool hasPendingTransfer: LocalSend.currentTransfer !== null
    property bool hasDroppedFiles: LocalSend.droppedFiles.length > 0
    property bool isActive: hasPendingTransfer || hasDroppedFiles
    property bool latched: false

    Connections {
        target: LocalSend
        function onCurrentTransferChanged() {
            rootItem.toggleHighlight(root.hasPendingTransfer || root.hasDroppedFiles)
        }
        function onDroppedFilesChanged() {
            rootItem.toggleHighlight(root.hasPendingTransfer || root.hasDroppedFiles)
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 6

        MaterialSymbol {
            text: "devices"
            iconSize: Appearance.font.pixelSize.large
            color: root.isActive ? Appearance.colors.colPrimary : root.colText
            fill: root.isActive ? 1 : 0
        }

        StyledText {
            visible: root.isActive
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colText
            text: root.hasPendingTransfer ? "!" : LocalSend.droppedFiles.length
        }

        Rectangle {
            visible: LocalSend.serverRunning
            width: 6; height: 6; radius: 3
            color: Appearance.colors.colPrimary
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (drop) => {
            if (!drop.hasUrls) return
            for (let i = 0; i < drop.urls.length; i++)
                LocalSend.addDroppedFile(drop.urls[i])
            drop.accept(Qt.CopyAction)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        onClicked: {
            root.latched = !root.latched
            if (LocalSend.available && !LocalSend.serverRunning)
                LocalSend.startServer()
        }

        LocalSendWidgetPopup {
            compact: Config.options.bar.tooltips.compactPopups
            hoverTarget: mouseArea
            open: root.latched || mouseArea.containsMouse || popupHovered
        }
    }
}
