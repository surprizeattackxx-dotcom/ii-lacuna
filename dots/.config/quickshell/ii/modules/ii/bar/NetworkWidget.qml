import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
  id: root
  property bool vertical: false

  implicitWidth: row.implicitWidth + 8
  implicitHeight: Appearance.sizes.barHeight

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 2

    MaterialSymbol {
      iconSize: 18
      text: Network.materialSymbol
      color: Network.wifiStatus === "connected" || Network.ethernet ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
    }

    StyledText {
      text: Network.wifiStatus === "connecting" ? "..." : Network.networkName
      font.pixelSize: Appearance.font.pixelSize.small
      color: Appearance.m3colors.m3onSurfaceVariant
      visible: !root.vertical && Network.networkName.length > 0
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Network.toggleWifi()
  }
}
