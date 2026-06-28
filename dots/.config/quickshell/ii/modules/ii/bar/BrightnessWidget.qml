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

  readonly property var monitor: Brightness.monitors.length > 0 ? Brightness.monitors[0] : null

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 2

    MaterialSymbol {
      iconSize: 18
      text: root.monitor && root.monitor.ready && root.monitor.brightness > 0.5 ? "brightness_high"
         : root.monitor && root.monitor.ready && root.monitor.brightness > 0 ? "brightness_low"
         : "brightness_off"
      color: Appearance.m3colors.m3onSurface
    }

    StyledText {
      text: root.monitor && root.monitor.ready ? Math.round(root.monitor.brightness * 100) + "%" : "--"
      font.pixelSize: Appearance.font.pixelSize.small
      color: Appearance.m3colors.m3onSurfaceVariant
      visible: !root.vertical
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onWheel: wheel => {
      if (!root.monitor || !root.monitor.ready) return
      if (wheel.angleDelta.y > 0) root.monitor.setBrightness(root.monitor.brightness + 0.05)
      else root.monitor.setBrightness(root.monitor.brightness - 0.05)
    }
  }
}
