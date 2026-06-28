import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

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
      text: Audio.sink?.audio.muted ? "volume_off" : Audio.value > 0.5 ? "volume_up" : Audio.value > 0 ? "volume_down" : "volume_mute"
      color: Appearance.m3colors.m3onSurface
    }

    StyledText {
      text: Audio.sink?.audio.muted ? "--" : Math.round(Audio.value * 100) + "%"
      font.pixelSize: Appearance.font.pixelSize.small
      color: Appearance.m3colors.m3onSurfaceVariant
      visible: !root.vertical
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Audio.toggleMute()
    onWheel: wheel => {
      if (wheel.angleDelta.y > 0) Audio.incrementVolume()
      else Audio.decrementVolume()
    }
  }
}
