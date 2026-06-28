import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Hardware
import qs.Services.Power
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen

  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  readonly property color iconColor: Color.resolveColorKey(iconColorKey)

  readonly property bool showScreenshot: widgetSettings.showScreenshot !== undefined ? widgetSettings.showScreenshot : widgetMetadata.showScreenshot
  readonly property bool showScreenRecord: widgetSettings.showScreenRecord !== undefined ? widgetSettings.showScreenRecord : widgetMetadata.showScreenRecord
  readonly property bool showColorPicker: widgetSettings.showColorPicker !== undefined ? widgetSettings.showColorPicker : widgetMetadata.showColorPicker
  readonly property bool showMicToggle: widgetSettings.showMicToggle !== undefined ? widgetSettings.showMicToggle : widgetMetadata.showMicToggle
  readonly property bool showPowerProfile: widgetSettings.showPowerProfile !== undefined ? widgetSettings.showPowerProfile : widgetMetadata.showPowerProfile

  implicitWidth: flow.implicitWidth + Style.marginM
  implicitHeight: flow.implicitHeight + Style.marginS

  Flow {
    id: flow
    anchors.centerIn: parent
    spacing: Style.marginXS

    NIconButton {
      icon: "screenshot"
      baseSize: Style.baseWidgetSize * 0.7
      applyUiScale: false
      customRadius: Style.radiusS
      colorBg: Style.capsuleColor
      colorFg: root.iconColor
      tooltipText: I18n.tr("tooltips.screenshot")
      onClicked: Quickshell.execDetached(["sh", "-c", "hyprshot -m region"])
      visible: root.showScreenshot
    }

    NIconButton {
      icon: "record"
      baseSize: Style.baseWidgetSize * 0.7
      applyUiScale: false
      customRadius: Style.radiusS
      colorBg: Style.capsuleColor
      colorFg: root.iconColor
      tooltipText: I18n.tr("tooltips.screen-record")
      onClicked: Quickshell.execDetached(["sh", "-c", "wf-recorder -f ~/Videos/$(date +%Y%m%d-%H%M%S).mp4 &"])
      visible: root.showScreenRecord
    }

    NIconButton {
      icon: "color-picker"
      baseSize: Style.baseWidgetSize * 0.7
      applyUiScale: false
      customRadius: Style.radiusS
      colorBg: Style.capsuleColor
      colorFg: root.iconColor
      tooltipText: I18n.tr("tooltips.color-picker")
      onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
      visible: root.showColorPicker
    }

    NIconButton {
      icon: AudioService.inputMuted ? "microphone-off" : "microphone"
      baseSize: Style.baseWidgetSize * 0.7
      applyUiScale: false
      customRadius: Style.radiusS
      colorBg: AudioService.inputMuted ? Color.mError : Style.capsuleColor
      colorFg: AudioService.inputMuted ? Color.mOnError : root.iconColor
      tooltipText: I18n.tr("tooltips.toggle-mic")
      onClicked: AudioService.setInputMuted(!AudioService.inputMuted)
      visible: root.showMicToggle
    }

    NIconButton {
      icon: {
        switch (PowerProfileService.currentProfile) {
          case "power-saver": return "battery-eco";
          case "performance": return "rocket";
          default: return "balance";
        }
      }
      baseSize: Style.baseWidgetSize * 0.7
      applyUiScale: false
      customRadius: Style.radiusS
      colorBg: Style.capsuleColor
      colorFg: root.iconColor
      tooltipText: I18n.tr("tooltips.cycle-power-profile")
      onClicked: PowerProfileService.cycleProfile()
      visible: root.showPowerProfile
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]
    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "widget-settings") {
        BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
      }
    }
  }
}
