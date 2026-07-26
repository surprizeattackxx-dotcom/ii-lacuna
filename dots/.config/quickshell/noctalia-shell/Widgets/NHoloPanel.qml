import QtQuick
import QtQuick.Shapes
import qs.Commons

// Angular cut-corner glass panel with a glowing border.
// NDropShadow is a sibling in this same Widgets/ directory, so no import is
// needed to use it below (matches the existing convention in this folder —
// e.g. NCheckbox.qml, NImageRounded.qml reference sibling widgets the same way).
// Replaces plain rounded-rect backgrounds where the holographic look is wanted.
Item {
  id: root

  property real cutSize: Math.min(width, height) * 0.28
  property color fillColor: Color.mSurface
  property real fillOpacity: 1.0
  property color glowColor: Color.mPrimary
  property bool showBorder: true

  function pulse() {
    // Hooked up by shader tasks later; no-op until then.
  }

  NDropShadow {
    anchors.fill: parent
    source: panelShape
    shadowColor: root.glowColor
    shadowBlur: 0.6
    shadowOpacity: 0.8
  }

  Shape {
    id: panelShape
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, root.fillOpacity)
      strokeColor: root.showBorder ? root.glowColor : "transparent"
      strokeWidth: root.showBorder ? Style.borderS : 0
      startX: 0
      startY: 0
      PathLine {
        x: panelShape.width - root.cutSize
        y: 0
      }
      PathLine {
        x: panelShape.width
        y: root.cutSize
      }
      PathLine {
        x: panelShape.width
        y: panelShape.height
      }
      PathLine {
        x: root.cutSize
        y: panelShape.height
      }
      PathLine {
        x: 0
        y: panelShape.height - root.cutSize
      }
      PathLine {
        x: 0
        y: 0
      }
    }
  }
}
