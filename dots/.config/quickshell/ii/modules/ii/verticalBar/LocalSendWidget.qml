import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar as Bar

Item {
    id: root
    implicitHeight: lsColumn.implicitHeight + 10
    implicitWidth: Appearance.sizes.verticalBarWidth
    property bool hasPendingTransfer: LocalSend.currentTransfer !== null
    property bool hasDroppedFiles: LocalSend.droppedFiles.length > 0
    property bool isActive: hasPendingTransfer || hasDroppedFiles

    Connections {
        target: LocalSend
        function onCurrentTransferChanged() {
            rootItem.toggleHighlight(root.hasPendingTransfer || root.hasDroppedFiles)
        }
        function onDroppedFilesChanged() {
            rootItem.toggleHighlight(root.hasPendingTransfer || root.hasDroppedFiles)
        }
    }

    ColumnLayout {
        id: lsColumn
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "devices"
            iconSize: Appearance.font.pixelSize.large
            color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
            fill: root.isActive ? 1 : 0
        }

        StyledText {
            visible: root.isActive && root.hasDroppedFiles
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurface
            text: LocalSend.droppedFiles.length
        }

        Rectangle {
            visible: LocalSend.serverRunning
            Layout.alignment: Qt.AlignHCenter
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

        Bar.LocalSendWidgetPopup {
            compact: Config.options.bar.tooltips.compactPopups
            hoverTarget: mouseArea
        }
    }
}
