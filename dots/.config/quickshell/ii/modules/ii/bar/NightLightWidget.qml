import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
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
    text: Hyprsunset.temperatureActive ? "nightlight" : "nightlight_off"
    color: Hyprsunset.temperatureActive ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Hyprsunset.toggleTemperature()
  }
}
