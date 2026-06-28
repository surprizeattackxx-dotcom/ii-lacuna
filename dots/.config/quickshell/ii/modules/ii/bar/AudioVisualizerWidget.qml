import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
  id: root
  property bool vertical: false

  implicitWidth: vertical ? Appearance.sizes.barHeight : 48
  implicitHeight: vertical ? 48 : Appearance.sizes.barHeight

  property real volume: Audio.sink?.audio?.volume ?? 0
  property real animPhase: 0

  readonly property int barCount: 6

  Row {
    anchors.centerIn: parent
    spacing: 2
    Repeater {
      model: root.barCount
      Rectangle {
        readonly property real normIdx: index / root.barCount
        readonly property real wiggle: Math.sin(root.animPhase + index * 1.2)
        readonly property real barHeight: Math.max(2, root.volume * 20 * (0.3 + 0.7 * (1 - Math.abs(normIdx - 0.5) * 2)) + wiggle * 3)
        width: root.vertical ? 2 : 3
        height: root.vertical ? 3 : barHeight
        radius: 1
        color: Appearance.m3colors.m3primary
        opacity: 0.7
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
      }
    }
  }

  Timer {
    interval: 80
    running: true
    repeat: true
    onTriggered: root.animPhase += 0.3
  }
}
