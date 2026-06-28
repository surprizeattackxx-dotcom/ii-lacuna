import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
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
    text: "contrast"
    color: Appearance.m3colors.darkmode ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      Quickshell.execDetached([Directories.darkModeToggleScriptPath])
      MaterialThemeLoader.reloadAfterExternalColorChange()
    }
  }
}
