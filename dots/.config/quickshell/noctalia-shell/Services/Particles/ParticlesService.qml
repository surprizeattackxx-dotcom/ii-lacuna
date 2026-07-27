pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
  id: root

  property var overlays: ({})
  property bool anyActive: false

  function registerOverlay(screenName, overlay) {
    overlays[screenName] = overlay;
  }

  function unregisterOverlay(screenName) {
    delete overlays[screenName];
  }

  // Debounced "any particle burst active recently" flag. Set synchronously
  // and unconditionally at the top of handleLine (before routing) so it's
  // true in time for the very same event that triggers it — see
  // ParticlesOverlay.qml, whose PanelWindow.visible is bound to this.
  Timer {
    id: activeResetTimer
    interval: 5000
    onTriggered: root.anyActive = false
  }

  function handleLine(line) {
    root.anyActive = true;
    activeResetTimer.restart();

    const parts = line.split(",");
    if (parts.length !== 3) return;
    const px0 = parseFloat(parts[0]);
    const py0 = parseFloat(parts[1]);
    const kind = parts[2];
    if (!Number.isFinite(px0) || !Number.isFinite(py0)) return;
    if (kind !== "char" && kind !== "backspace") return;

    const toplevel = Hyprland.activeToplevel;
    if (!toplevel || !toplevel.lastIpcObject) return;
    const info = toplevel.lastIpcObject;
    if (!info.at) return;

    const px = info.at[0] + px0;
    const py = info.at[1] + py0;

    for (const screenName in overlays) {
      const overlay = overlays[screenName];
      if (overlay.containsPoint(px, py)) {
        overlay.spawnBurst(px - overlay.screenX, py - overlay.screenY, kind);
        break;
      }
    }
  }

  SocketServer {
    id: server
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/particles.sock"
    active: true
    handler: Component {
      Socket {
        parser: SplitParser {
          splitMarker: "\n"
          onRead: line => root.handleLine(line)
        }
      }
    }
  }

  IpcHandler {
    target: "particles"
    function enable() {
      server.active = true;
    }
    function disable() {
      server.active = false;
    }
  }
}
