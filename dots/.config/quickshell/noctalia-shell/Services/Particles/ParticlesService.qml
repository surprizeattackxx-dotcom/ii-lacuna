pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
  id: root

  property var overlays: ({})

  function registerOverlay(screenName, overlay) {
    overlays[screenName] = overlay;
  }

  function unregisterOverlay(screenName) {
    delete overlays[screenName];
  }

  function handleLine(line) {
    const parts = line.split(",");
    if (parts.length !== 5) return;
    const row = parseInt(parts[0], 10);
    const col = parseInt(parts[1], 10);
    const cols = parseInt(parts[2], 10);
    const lines = parseInt(parts[3], 10);
    const kind = parts[4];
    if (!Number.isFinite(row) || !Number.isFinite(col) || !Number.isFinite(cols) || !Number.isFinite(lines)) return;
    if (cols <= 0 || lines <= 0) return;
    if (kind !== "char" && kind !== "backspace") return;

    const toplevel = Hyprland.activeToplevel;
    if (!toplevel || !toplevel.lastIpcObject) return;
    const info = toplevel.lastIpcObject;
    if (!info.at || !info.size) return;

    const cellWidth = info.size[0] / cols;
    const cellHeight = info.size[1] / lines;
    const px = info.at[0] + (col + 0.5) * cellWidth;
    const py = info.at[1] + (row + 0.5) * cellHeight;

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
