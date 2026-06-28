import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
  id: root
  property bool vertical: false

  implicitWidth: codeText.implicitWidth + 8
  implicitHeight: Appearance.sizes.barHeight

  StyledText {
    id: codeText
    anchors.centerIn: parent
    text: HyprlandXkb.currentLayoutCode.length > 0
      ? HyprlandXkb.currentLayoutCode.substring(0, 2).toUpperCase()
      : ""
    font.pixelSize: Appearance.font.pixelSize.smaller
    font.bold: true
    color: HyprlandXkb.layoutCodes.length > 1
      ? Appearance.m3colors.m3primary
      : Appearance.m3colors.m3onSurfaceVariant
    visible: HyprlandXkb.layoutCodes.length > 0
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    visible: HyprlandXkb.layoutCodes.length > 1
    onClicked: {
      if (HyprlandXkb.layoutCodes.length > 1) {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "current", "next"])
      }
    }
  }
}
