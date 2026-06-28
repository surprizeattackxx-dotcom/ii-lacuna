import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.System
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

  readonly property int displayMode: widgetSettings.displayMode !== undefined ? widgetSettings.displayMode : widgetMetadata.displayMode
  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor
  readonly property string textColorKey: widgetSettings.textColor !== undefined ? widgetSettings.textColor : widgetMetadata.textColor
  readonly property bool autoHide: widgetSettings.autoHide !== undefined ? widgetSettings.autoHide : widgetMetadata.autoHide

  readonly property color iconColor: Color.resolveColorKey(iconColorKey)
  readonly property color textColor: Color.resolveColorKey(textColorKey)

  function formatSpeed(bytesPerSecond) {
    var bits = bytesPerSecond * 8;
    var suffix = "bps";
    if (bits < 1000) return bits.toFixed(0) + " " + suffix;
    else if (bits < 1000000) return (bits / 1000).toFixed(1) + " K" + suffix;
    else if (bits < 1000000000) return (bits / 1000000).toFixed(1) + " M" + suffix;
    else return (bits / 1000000000).toFixed(1) + " G" + suffix;
  }

  readonly property bool hasActivity: SystemStatService.rxSpeed > 125 || SystemStatService.txSpeed > 125

  implicitWidth: pill.width
  implicitHeight: pill.height

  visible: autoHide ? hasActivity : true

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

  BarPill {
    id: pill
    screen: root.screen
    icon: "network"
    text: {
      if (displayMode === 0) return formatSpeed(SystemStatService.rxSpeed + SystemStatService.txSpeed);
      if (displayMode === 1) return "↓ " + formatSpeed(SystemStatService.rxSpeed);
      if (displayMode === 2) return "↑ " + formatSpeed(SystemStatService.txSpeed);
      return "";
    }
    tooltipText: I18n.tr("tooltips.network-speed", {
      down: formatSpeed(SystemStatService.rxSpeed),
      up: formatSpeed(SystemStatService.txSpeed)
    })
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: root.iconColor
    customTextColor: root.textColor
    onRightClicked: {
      PanelService.showContextMenu(contextMenu, pill, screen);
    }
  }
}
