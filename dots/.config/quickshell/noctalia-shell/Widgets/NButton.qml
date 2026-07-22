import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI

Item {
  id: root

  // Public properties
  property string text: ""
  property string icon: ""
  property var tooltipText
  property color backgroundColor: Color.mPrimary
  property color textColor: Color.mOnPrimary
  property color hoverColor: Color.mHover
  property color textHoverColor: Color.mOnHover
  property real fontSize: Style.fontSizeM
  property int fontWeight: Style.fontWeightSemiBold
  property real iconSize: Style.fontSizeL
  property bool outlined: false
  property int horizontalAlignment: Qt.AlignHCenter
  // M3 filled/outlined buttons are a true stadium/pill shape by default — matches the same
  // Math.min(cap, dimension/2) idiom NToggle/NIconButton/NRadioButton already use, so this was
  // the one interactive widget still using a fixed rounded-rect instead.
  property real buttonRadius: Math.min(Style.iRadiusL, bg.height / 2)

  // Signals
  signal clicked
  signal rightClicked
  signal middleClicked
  signal entered
  signal exited

  // Internal properties
  property bool hovered: false
  readonly property color contentColor: {
    if (!root.enabled) {
      return Color.mOnSurfaceVariant;
    }
    if (root.outlined) {
      return root.backgroundColor;
    }
    return root.textColor;
  }

  // Dimensions - include margin so border renders cleanly at fractional scales
  implicitWidth: bg.implicitWidth + 2 * Style.borderS
  implicitHeight: bg.implicitHeight + 2 * Style.borderS

  opacity: enabled ? 1.0 : 0.6

  Rectangle {
    id: bg
    anchors.fill: parent
    anchors.margins: Style.borderS

    implicitWidth: contentRow.implicitWidth + (root.fontSize * 2)
    implicitHeight: contentRow.implicitHeight + (root.fontSize)

    radius: root.buttonRadius
    color: {
      if (!root.enabled)
        return root.outlined ? "transparent" : Qt.lighter(Color.mSurfaceVariant, 1.2);
      return root.outlined ? "transparent" : root.backgroundColor;
    }

    border.width: root.outlined ? Style.borderS : 0
    border.color: {
      if (!root.enabled)
        return Color.mOutline;
      return root.outlined ? root.backgroundColor : "transparent";
    }

    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }
    }

    Behavior on border.color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }
    }

    // M3 state layer: translucent tint of hoverColor over the resting background
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: Qt.alpha(root.hoverColor, root.enabled && root.hovered ? Style.stateLayerHover : 0)

      Behavior on color {
        enabled: !Color.isTransitioning
        ColorAnimation {
          duration: Style.animationFast
          easing.type: Easing.BezierSpline
          easing.bezierCurve: Style.easingStandard
        }
      }
    }

    // M3 ripple
    NRipple {
      id: ripple
      anchors.fill: parent
      rippleColor: root.hoverColor
    }

    // Content
    RowLayout {
      id: contentRow
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: root.horizontalAlignment === Qt.AlignLeft ? parent.left : undefined
      anchors.horizontalCenter: root.horizontalAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
      anchors.leftMargin: root.horizontalAlignment === Qt.AlignLeft ? Style.marginL : 0
      spacing: Style.marginXS

      // Icon (optional)
      NIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: root.icon !== ""
        icon: root.icon
        pointSize: root.iconSize
        color: root.contentColor

        Behavior on color {
          enabled: !Color.isTransitioning
          ColorAnimation {
            duration: Style.animationFast
            easing.type: Easing.OutCubic
          }
        }
      }

      // Text
      NText {
        Layout.alignment: Qt.AlignVCenter
        visible: root.text !== ""
        text: root.text
        pointSize: root.fontSize
        font.weight: root.fontWeight
        color: root.contentColor

        Behavior on color {
          enabled: !Color.isTransitioning
          ColorAnimation {
            duration: Style.animationFast
            easing.type: Easing.OutCubic
          }
        }
      }
    }

    // Mouse interaction
    MouseArea {
      id: mouseArea
      anchors.fill: parent
      enabled: root.enabled
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

      onEntered: {
        root.hovered = root.enabled ? true : false;
        root.entered();
        if (root.hovered && root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.show(root, root.tooltipText);
        }
      }
      onExited: {
        root.hovered = false;
        root.exited();
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
      }
      onPressed: mouse => {
                   ripple.trigger(mouse.x, mouse.y);
                   if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
                     TooltipService.hide();
                   }
                   if (mouse.button === Qt.LeftButton) {
                     root.clicked();
                   } else if (mouse.button == Qt.RightButton) {
                     root.rightClicked();
                   } else if (mouse.button == Qt.MiddleButton) {
                     root.middleClicked();
                   }
                 }

      onCanceled: {
        root.hovered = false;
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
      }
    }
  }
}
