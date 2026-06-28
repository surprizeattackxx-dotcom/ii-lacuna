import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Services.System

PanelWindow {
  id: root

  signal closed

  property int screenshotAction: ScreenshotService.Action.Copy

  visible: false
  color: "transparent"
  WlrLayershell.namespace: "noctalia-region-selector"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  exclusionMode: ExclusionMode.Ignore
  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }

  readonly property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(screen)
  readonly property real monitorScale: hyprMonitor ? hyprMonitor.scale : 1
  readonly property string screenshotPath: ScreenshotService.tempDir + "/screen-" + (screen?.name ?? "unknown") + ".png"

  Process {
    id: screenshotProc
    onExited: function (exitCode) {
      root.preparationDone = true;
    }
    Component.onCompleted: {
      command = ["grim", "-o", root.screen.name ?? "", root.screenshotPath];
      start();
    }
  }

  property bool preparationDone: false
  onPreparationDoneChanged: {
    if (preparationDone) {
      root.visible = true;
    }
  }

  function doClose() {
    root.closed();
  }

  ScreencopyView {
    id: screencopyView
    anchors.fill: parent
    live: false
    captureSource: root.screen

    focus: root.visible
    Keys.onPressed: function (event) {
      if (event.key === Qt.Key_Escape) {
        root.doClose();
      }
    }

    MouseArea {
      id: dragArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.CrossCursor

      property real regionTopLeftX: 0
      property real regionTopLeftY: 0
      property real regionWidth: 0
      property real regionHeight: 0
      property real startX: 0
      property real startY: 0

      onPressed: function (mouse) {
        startX = mouse.x;
        startY = mouse.y;
        regionTopLeftX = mouse.x;
        regionTopLeftY = mouse.y;
        regionWidth = 0;
        regionHeight = 0;
      }

      onPositionChanged: function (mouse) {
        if (pressed) {
          regionWidth = Math.abs(mouse.x - startX);
          regionHeight = Math.abs(mouse.y - startY);
          regionTopLeftX = Math.min(startX, mouse.x);
          regionTopLeftY = Math.min(startY, mouse.y);
        }
      }

      onReleased: function (mouse) {
        if (regionWidth === 0 || regionHeight === 0)
          return;

        var saveDir = Settings.data.regionSelector?.screenshotSavePath ?? "";
        var cmd = ScreenshotService.getCommand(
          regionTopLeftX * root.monitorScale,
          regionTopLeftY * root.monitorScale,
          regionWidth * root.monitorScale,
          regionHeight * root.monitorScale,
          root.screenshotPath,
          root.screenshotAction,
          saveDir
        );

        if (cmd.length > 0) {
          snipProc.command = cmd;
          snipProc.startDetached();
        }

        root.doClose();
      }

      Rectangle {
        x: dragArea.regionTopLeftX
        y: dragArea.regionTopLeftY
        width: dragArea.regionWidth
        height: dragArea.regionHeight
        color: "transparent"
        border.width: 2
        border.color: Color.mPrimary
        visible: dragArea.regionWidth > 0 && dragArea.regionHeight > 0
      }
    }
  }

  Process {
    id: snipProc
  }
}
