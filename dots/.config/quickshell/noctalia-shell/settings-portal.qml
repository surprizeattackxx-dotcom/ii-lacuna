//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Modules.Panels.Settings.Tabs
import qs.Modules.Panels.Settings.Tabs.About
import qs.Modules.Panels.Settings.Tabs.Audio
import qs.Modules.Panels.Settings.Tabs.Bar
import qs.Modules.Panels.Settings.Tabs.ColorScheme
import qs.Modules.Panels.Settings.Tabs.Connections
import qs.Modules.Panels.Settings.Tabs.ControlCenter
import qs.Modules.Panels.Settings.Tabs.Display
import qs.Modules.Panels.Settings.Tabs.Dock
import qs.Modules.Panels.Settings.Tabs.Hooks
import qs.Modules.Panels.Settings.Tabs.Idle
import qs.Modules.Panels.Settings.Tabs.Launcher
import qs.Modules.Panels.Settings.Tabs.LockScreen
import qs.Modules.Panels.Settings.Tabs.Notifications
import qs.Modules.Panels.Settings.Tabs.Osd
import qs.Modules.Panels.Settings.Tabs.Plugins
import qs.Modules.Panels.Settings.Tabs.Region
import qs.Modules.Panels.Settings.Tabs.SessionMenu
import qs.Modules.Panels.Settings.Tabs.SystemMonitor
import qs.Modules.Panels.Settings.Tabs.UserInterface
import qs.Modules.Panels.Settings.Tabs.Wallpaper
import qs.Services.Compositor
import qs.Services.Power
import qs.Services.System
import qs.Services.UI
import qs.Widgets

FloatingWindow {
  id: root

  title: "Noctalia Settings"
  minimumSize: Qt.size(840, 910)
  implicitWidth: 840
  implicitHeight: 910
  color: "transparent"

  visible: true

  Component.onDestruction: Qt.quit()

  // Sync to ii is handled solely by ii's NoctaliaBridge (watches this shell's
  // settings.json). No bridge here, to avoid a double-write race on ii config.

  // noctalia-style open animation: content grows + fades from center.
  property real openProgress: 0
  Component.onCompleted: openProgress = 1
  Behavior on openProgress {
    enabled: !(Settings.data.general.animationDisabled ?? false)
    NumberAnimation {
      duration: 300
      easing.type: Easing.BezierSpline
      easing.bezierCurve: Style.easingEmphasized
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.alpha(Color.mSurface, Settings.data.ui.panelBackgroundOpacity)
    radius: 12

    opacity: root.openProgress
    transform: Scale {
      origin.x: root.width / 2
      origin.y: root.height / 2
      xScale: 0.92 + 0.08 * root.openProgress
      yScale: 0.92 + 0.08 * root.openProgress
    }

    SettingsContent {
      id: settingsContent
      anchors.fill: parent
      requestedTab: 0
      Component.onCompleted: initialize()
      onCloseRequested: Qt.quit()
    }
  }
}
