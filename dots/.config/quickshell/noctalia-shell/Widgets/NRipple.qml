import QtQuick
import qs.Commons

// M3 ripple: a circular tint that expands from the press point and fades out.
// Purely decorative - contains no MouseArea, so it never intercepts input.
// Rectangular clip only (no rounded mask) to avoid an extra per-instance
// MultiEffect layer; the ripple can peek very slightly past a rounded corner
// at max radius on small controls.
Item {
  id: root
  anchors.fill: parent
  clip: true

  property color rippleColor: Color.mOnSurface
  property real rippleOpacity: 0.16

  readonly property real _maxDiameter: 2 * Math.sqrt(root.width * root.width + root.height * root.height)

  property real _pressX: 0
  property real _pressY: 0

  function trigger(x, y) {
    rippleAnim.stop();
    root._pressX = x;
    root._pressY = y;
    circle.width = 0;
    circle.opacity = root.rippleOpacity;
    rippleAnim.start();
  }

  Rectangle {
    id: circle
    width: 0
    height: width
    radius: width / 2
    color: root.rippleColor
    x: root._pressX - width / 2
    y: root._pressY - width / 2
  }

  ParallelAnimation {
    id: rippleAnim
    NumberAnimation {
      target: circle
      property: "width"
      to: root._maxDiameter
      duration: Style.animationSlow
      easing.type: Easing.BezierSpline
      easing.bezierCurve: Style.easingStandard
    }
    NumberAnimation {
      target: circle
      property: "opacity"
      to: 0
      duration: Style.animationSlow
      easing.type: Easing.BezierSpline
      easing.bezierCurve: Style.easingStandard
    }
  }
}
