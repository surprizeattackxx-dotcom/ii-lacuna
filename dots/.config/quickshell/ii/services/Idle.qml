pragma Singleton
import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
  id: root

  property alias inhibit: idleInhibitor.enabled
  inhibit: false

  readonly property string _sessionId: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""

  Timer {
    id: restoreTimer
    interval: 0
    repeat: false
    onTriggered: {
      if (!Persistent.ready) return
      const storedId = Persistent.states.idle.sessionId || ""
      if (storedId === root._sessionId)
        root.inhibit = Persistent.states.idle.inhibit ?? false
      else
        root.inhibit = false
    }
  }

  Connections {
    target: Persistent
    function onReadyChanged() { restoreTimer.restart() }
  }

  function toggleInhibit(active = null) {
    root.inhibit = active !== null ? active : !root.inhibit
    Persistent.states.idle.inhibit = root.inhibit
    Persistent.states.idle.sessionId = root._sessionId
  }

  readonly property bool mediaInhibit: Config.options.lock.idle.respectMedia && MprisController.anyPlaying
  readonly property bool fullscreenInhibit: Config.options.lock.idle.respectFullscreen && HyprlandData.windowList.some(w => w.fullscreen > 0)
  readonly property bool activityInhibit: root.mediaInhibit || root.fullscreenInhibit

  property bool _screenLocked: false
  readonly property bool _idleDisabled: !Config.options.lock.idle.enable || root.activityInhibit

  // ---- Three-stage idle ----

  property string fadePending: ""
  property var queuedStages: []

  Timer {
    id: graceTimer
    interval: (Config.options.lock.idle.fadeDuration || 5) * 1000
    repeat: false
    onTriggered: _executeAction(root.fadePending)
  }

  Timer {
    id: queueTimer
    interval: 500
    repeat: false
    onTriggered: _runNextQueued()
  }

  function _onIdle(stage) {
    if (!_stageEnabled(stage)) return
    if (fadePending !== "") {
      if (!queuedStages.includes(stage)) queuedStages.push(stage)
      return
    }
    fadePending = stage
    graceTimer.restart()
  }

  function _cancelFade() {
    fadePending = ""
    graceTimer.stop()
    queuedStages = []
  }

  function _executeAction(stage) {
    fadePending = ""
    if (stage === "screenOff") {
      Quickshell.execDetached(["hyprctl", "dispatch", "dpms", "off"])
    } else if (stage === "lock") {
      if (root._screenLocked) return
      root._screenLocked = true
      if (Config.options.lock.useHyprlock)
        Quickshell.execDetached(["bash", "-c", "pidof hyprlock || hyprlock"])
      else
        GlobalStates.screenLocked = true
    } else if (stage === "suspend") {
      Quickshell.execDetached(["systemctl", "suspend"])
    }
    queueTimer.restart()
  }

  function _runNextQueued() {
    while (queuedStages.length > 0) {
      const stage = queuedStages.shift()
      if (_stageEnabled(stage)) { _onIdle(stage); return }
    }
  }

  function _stageEnabled(stage) {
    if (root._idleDisabled) return false
    if (stage === "screenOff") return (Config.options.lock.idle.screenOffTimeout || 0) > 0
    if (stage === "lock") return (Config.options.lock.idle.lockTimeout || 0) > 0 && !root._screenLocked
    if (stage === "suspend") return (Config.options.lock.idle.suspendTimeout || 0) > 0
    return false
  }

  IdleMonitor {
    enabled: !root._idleDisabled && (Config.options.lock.idle.screenOffTimeout || 0) > 0
    respectInhibitors: true
    timeout: Config.options.lock.idle.screenOffTimeout || 600
    onIsIdleChanged: {
      if (isIdle) root._onIdle("screenOff")
      else if (root.fadePending === "screenOff") root._cancelFade()
    }
  }

  IdleMonitor {
    enabled: !root._idleDisabled && (Config.options.lock.idle.lockTimeout || 0) > 0 && !root._screenLocked
    respectInhibitors: true
    timeout: Config.options.lock.idle.lockTimeout
    onIsIdleChanged: {
      if (isIdle) root._onIdle("lock")
      else if (root.fadePending === "lock") root._cancelFade()
    }
  }
  
  IdleMonitor {
    enabled: !root._idleDisabled && (Config.options.lock.idle.suspendTimeout || 0) > 0
    respectInhibitors: true
    timeout: Config.options.lock.idle.suspendTimeout || 1800
    onIsIdleChanged: {
      if (isIdle) root._onIdle("suspend")
      else if (root.fadePending === "suspend") root._cancelFade()
    }
  }

  Connections {
    target: GlobalStates
    function onScreenLockedChanged() {
      if (!GlobalStates.screenLocked) root._screenLocked = false
    }
  }

  IdleInhibitor {
    id: idleInhibitor
    window: PanelWindow {
      implicitWidth: 0; implicitHeight: 0
      color: "transparent"
      anchors { right: true; bottom: true }
      mask: Region { item: null }
    }
  }
}
