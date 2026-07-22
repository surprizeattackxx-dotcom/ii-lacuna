import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

RowLayout {
  id: root

  property string label: ""
  property string description: ""
  property string icon: ""
  property bool checked: false
  property bool hovering: false
  property int baseSize: Math.round(Style.baseWidgetSize * 0.8 * Style.uiScaleRatio)
  property var defaultValue: undefined
  property string settingsPath: ""

  signal toggled(bool checked)
  signal entered
  signal exited

  Layout.fillWidth: true
  spacing: Style.marginM

  readonly property bool isValueChanged: (defaultValue !== undefined) && (checked !== defaultValue)
  readonly property string indicatorTooltip: defaultValue !== undefined ? I18n.tr("panels.indicator.default-value", {
                                                                                    "value": typeof defaultValue === "boolean" ? (defaultValue ? "true" : "false") : String(defaultValue)
                                                                                  }) : ""

  NLabel {
    Layout.fillWidth: true
    label: root.label
    description: root.description
    icon: root.icon
    iconColor: root.checked ? Color.mPrimary : Color.mOnSurface
    visible: root.label !== "" || root.description !== ""
    showIndicator: root.isValueChanged
    indicatorTooltip: root.indicatorTooltip
  }

  Rectangle {
    id: switcher

    opacity: enabled ? 1.0 : 0.6
    Layout.alignment: Qt.AlignVCenter
    Layout.margins: Style.borderS
    implicitWidth: Math.round(root.baseSize * .85) * 2
    implicitHeight: Math.round(root.baseSize * .5) * 2
    radius: Math.min(Style.iRadiusL, height / 2)
    color: root.checked ? Color.mPrimary : Color.mSurface
    border.color: Color.mOutline
    border.width: Style.borderS

    Behavior on color {
      ColorAnimation {
        duration: Style.animationFast
      }
    }

    Behavior on border.color {
      ColorAnimation {
        duration: Style.animationFast
      }
    }

    // M3 state layer: translucent tint over the track on hover
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: Qt.alpha(root.checked ? Color.mOnPrimary : Color.mOnSurface, root.enabled && root.hovering ? Style.stateLayerHover : 0)

      Behavior on color {
        ColorAnimation {
          duration: Style.animationFast
          easing.type: Easing.BezierSpline
          easing.bezierCurve: Style.easingStandard
        }
      }
    }

    Rectangle {
      // M3 switches grow the thumb on the ON state (~0.75 of track height) vs. a smaller OFF
      // dot (~0.5) - this was previously a fixed size in both states, sliding but never resizing.
      implicitWidth: (root.checked ? Math.round(root.baseSize * 0.4) : Math.round(root.baseSize * 0.25)) * 2
      implicitHeight: implicitWidth
      radius: Math.min(Style.iRadiusL, height / 2)
      color: root.checked ? Color.mOnPrimary : Color.mPrimary
      border.color: Color.mSurface
      border.width: Style.borderM
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 0
      x: root.checked ? switcher.width - width - 3 : 3

      Behavior on x {
        NumberAnimation {
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }

      Behavior on implicitWidth {
        NumberAnimation {
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }
    }

    MouseArea {
      enabled: root.enabled
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: {
        if (!enabled)
          return;
        hovering = true;
        root.entered();
      }
      onExited: {
        if (!enabled)
          return;
        hovering = false;
        root.exited();
      }
      onClicked: {
        if (!enabled)
          return;
        root.toggled(!root.checked);
      }
    }
  }
}
