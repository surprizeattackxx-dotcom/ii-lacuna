import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

Item {
  id: root

  property color tint: Appearance.colors.colLayer0
  property color borderColor: Appearance.colors.colLayer0Border
  property var screen: null

  readonly property string barType: Config.options.bar.barType
  readonly property bool showOutline: Config.options.bar.showOutline
  readonly property real backgroundOpacity: Config.options.bar.backgroundOpacity
  readonly property int frameRadius: Config.options.bar.frameRadius
  readonly property bool outerCorners: Config.options.bar.outerCorners

  readonly property real effectiveRadius: {
    if (!outerCorners) return 0
    return frameRadius
  }

  Loader {
    active: barType === "floating" && Config.options.bar.floatStyleShadow
    anchors.fill: barBg
    sourceComponent: StyledRectangularShadow {
      target: barBg
    }
  }

  Rectangle {
    id: barBg
    anchors.fill: parent
    color: "transparent"
    radius: effectiveRadius

    GlassPanel {
      anchors.fill: parent
      screen: root.screen
      cornerRadius: parent.radius
      screenX: parent.x
      screenY: parent.y
      tint: root.tint
      opacity: root.backgroundOpacity
    }

    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: "transparent"
      border.width: showOutline ? 1 : 0
      border.color: root.borderColor
    }
  }
}
