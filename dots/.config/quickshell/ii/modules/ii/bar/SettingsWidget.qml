import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

Item {
  id: root
  property bool vertical: false

  implicitWidth: materialIcon.implicitWidth + 8
  implicitHeight: Appearance.sizes.barHeight

  MaterialSymbol {
    id: materialIcon
    anchors.centerIn: parent
    iconSize: 18
    text: "settings"
    color: Appearance.m3colors.m3onSurfaceVariant
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["/usr/bin/qs", "-p", Directories.settingsPortalPath])
  }
}
