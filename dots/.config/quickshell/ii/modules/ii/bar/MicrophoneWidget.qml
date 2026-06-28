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
      text: Audio.source?.audio?.muted ? "mic_off" : "mic"
      color: Audio.source?.audio?.muted ? Appearance.m3colors.m3error : Appearance.m3colors.m3onSurface
    }

    StyledText {
      text: Audio.source?.audio?.muted ? "--" : (Audio.source?.audio ? Math.round(Audio.source.audio.volume * 100) + "%" : "")
      font.pixelSize: Appearance.font.pixelSize.small
      color: Appearance.m3colors.m3onSurfaceVariant
      visible: !root.vertical
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Audio.toggleMicMute()
  }
}
