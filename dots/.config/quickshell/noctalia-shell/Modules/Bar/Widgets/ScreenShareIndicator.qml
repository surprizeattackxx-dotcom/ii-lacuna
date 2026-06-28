import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  implicitWidth: pill.width
  implicitHeight: pill.height

  property bool activelySharing: false

  Process {
    id: checkProc
    running: true
    command: ["bash", "-c", "pgrep -x pipewire >/dev/null 2>&1 && echo active || echo idle"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.activelySharing = text.trim() === "active";
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: { checkProc.running = true; }
  }

  visible: activelySharing

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
    icon: "cast"
    text: I18n.tr("widgets.screen-share")
    tooltipText: I18n.tr("tooltips.screen-share-active")
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: Color.mTertiary
    customTextColor: Color.mTertiary
    onRightClicked: { PanelService.showContextMenu(contextMenu, pill, screen); }
  }
}
