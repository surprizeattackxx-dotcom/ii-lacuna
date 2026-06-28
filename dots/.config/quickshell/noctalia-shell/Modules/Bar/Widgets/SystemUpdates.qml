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

  readonly property bool hideWhenZero: widgetSettings.hideWhenZero !== undefined ? widgetSettings.hideWhenZero : widgetMetadata.hideWhenZero

  implicitWidth: pill.width
  implicitHeight: pill.height

  property int updateCount: 0
  property bool checking: false
  property string lastChecked: "--"

  function checkUpdates() {
    if (checking) return;
    checking = true;
    updateProc.running = true;
  }

  Process {
    id: updateProc
    command: ["bash", "-c", "checkupdates 2>/dev/null | wc -l"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.updateCount = parseInt(text.trim()) || 0;
        root.checking = false;
        root.lastChecked = new Date().toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
      }
    }
    onRunningChanged: {
      if (!running) {
        root.checking = false;
      }
    }
  }

  Process {
    id: runUpdateProc
    command: ["/usr/bin/kitty", "-e", "sh", "-c", "sudo pacman -Syu"]
    running: false
    onRunningChanged: {
      if (!running) {
        Qt.callLater(function() {
          root.checkUpdates();
        });
      }
    }
  }

  Timer {
    interval: 3600000
    running: true
    repeat: true
    onTriggered: root.checkUpdates()
  }

  Component.onCompleted: root.checkUpdates()

  visible: hideWhenZero ? updateCount > 0 : true

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
    icon: checking ? "autorenew" : (updateCount > 0 ? "update" : "check")
    text: checking ? "..." : (updateCount > 0 ? String(updateCount) : "")
    tooltipText: checking ? I18n.tr("tooltips.checking-updates") : (updateCount > 0 ? I18n.tr("tooltips.updates-available", { count: updateCount }) : I18n.tr("tooltips.system-up-to-date"))
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: updateCount >= 10 ? Color.mError : (updateCount > 0 ? Color.mTertiary : Color.resolveColorKey("none"))
    customTextColor: updateCount >= 10 ? Color.mError : (updateCount > 0 ? Color.mTertiary : Color.resolveColorKey("none"))
    onClicked: {
      if (updateCount > 0) {
        runUpdateProc.running = false;
        Qt.callLater(function() { runUpdateProc.running = true; });
      }
    }
    onRightClicked: {
      root.checkUpdates();
      PanelService.showContextMenu(contextMenu, pill, screen);
    }
  }
}
