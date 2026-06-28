import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
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

  readonly property string textColorKey: widgetSettings.textColor !== undefined ? widgetSettings.textColor : widgetMetadata.textColor
  readonly property color textColor: Color.resolveColorKey(textColorKey)

  implicitWidth: pill.width
  implicitHeight: pill.height

  function formatDate() {
    var d = new Date();
    var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
    return days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate();
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": I18n.tr("actions.widget-settings"), "action": "widget-settings", "icon": "settings" },
    ]
    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "widget-settings")
        BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
    }
  }

  BarPill {
    id: pill
    screen: root.screen
    text: root.formatDate()
    tooltipText: root.formatDate()
    oppositeDirection: BarService.getPillDirection(root)
    customTextColor: root.textColor
    onRightClicked: { PanelService.showContextMenu(contextMenu, pill, screen); }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: pill.text = root.formatDate()
  }
}
