import qs.modules.common
import QtQuick

Item {
  property bool vertical: false
  property int spacerSize: 8

  implicitWidth: vertical ? Appearance.sizes.barHeight : spacerSize
  implicitHeight: vertical ? spacerSize : Appearance.sizes.barHeight
  width: implicitWidth
  height: implicitHeight
}
