# Kitty Typing Particles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Typing a printable character or hitting backspace in a focused kitty window bursts a small handful of particles from that exact grid cell, rendered by a new noctalia-shell layer-shell overlay, colored from the active scheme.

**Architecture:** A kitty watcher (`particles_watcher.py`) uses kitty's real `on_focus_change`/`on_close` hooks to run a ~50Hz `add_timer` poll loop only while a kitty window is focused; each tick calls `window.as_text(add_cursor=True)` and a pure detection module (`particles_detect.py`) diffs consecutive snapshots to recognize single-char-typed / backspace patterns. Detected events stream as `row,col,cols,lines,kind` lines over a persistent Unix socket to a new Quickshell singleton (`ParticlesService`), which resolves the absolute screen pixel using `Quickshell.Hyprland`'s live `activeToplevel` geometry and hands it to the correct per-monitor overlay surface (`ParticlesOverlay`) to spawn the actual burst.

**Tech Stack:** Python 3 (stdlib only) for the kitty watcher; QML (Quickshell) for the renderer — `Quickshell.Io` (`SocketServer`/`Socket`/`SplitParser`), `Quickshell.Wayland` (`WlrLayershell`), `Quickshell.Hyprland` (`Hyprland.activeToplevel`).

## Global Constraints

- Poll interval: 0.02s (~50Hz), gated to only run while a kitty window is focused.
- Trigger scope: printable-character-typed and backspace only — no other keys.
- Particle physics: explode outward at a random angle, no gravity, shrink + fade to nothing.
- Colors: `Color.mPrimary` / `Color.mSecondary` from `qs.Commons` — scheme-adaptive, not hardcoded.
- Char burst: 8 particles, size 4-7px, distance 24-56px, duration 300-500ms, color randomly `mPrimary` or `mSecondary` per particle.
- Backspace burst: 4 particles, size 3-5px, distance 16-36px, duration 250-400ms, color `mSecondary` only.
- Socket: `$XDG_RUNTIME_DIR/particles.sock`, line protocol `row,col,cols,lines,kind\n` (grid-relative, not pixels).
- No new external dependencies — Python stdlib only; QML modules already present in this Quickshell install only.
- Renderer failures must never block/slow typing; watcher failures must never crash kitty.

---

## File Structure

| File | Responsibility |
|------|-----------------|
| `dots/.config/kitty/particles_detect.py` | New — pure snapshot-diff logic (no kitty dependency), unit tested |
| `dots/.config/kitty/particles_watcher.py` | New — kitty watcher glue: focus-gated polling, socket I/O |
| `dots/.config/kitty/kitty.conf` | Modified — register the watcher |
| `dots/.config/quickshell/noctalia-shell/Modules/Particles/Particle.qml` | New — single particle visual + self-contained burst animation |
| `dots/.config/quickshell/noctalia-shell/Services/Particles/ParticlesService.qml` | New — singleton: `SocketServer`, `IpcHandler`, event parsing, Hyprland-based pixel resolution, overlay routing |
| `dots/.config/quickshell/noctalia-shell/Modules/Particles/ParticlesOverlay.qml` | New — per-screen layer-shell surface, registers with the service, spawns particles |
| `dots/.config/quickshell/noctalia-shell/shell.qml` | Modified — import + instantiate the new module |

---

### Task 1: Detection logic (`particles_detect.py`)

**Files:**
- Create: `dots/.config/kitty/particles_detect.py`
- Test: `dots/.config/kitty/test_particles_detect.py`

**Interfaces:**
- Produces: `Snapshot` (NamedTuple: `row: int, col: int, lines: list[str]`), `parse_snapshot(as_text_output: str) -> Snapshot | None`, `char_at(lines: list[str], row: int, col: int) -> str`, `detect_event(prev: Snapshot | None, curr: Snapshot) -> tuple[int, int, str] | None` (kind is `"char"` or `"backspace"`). Task 2 imports all four names from this module.

- [ ] **Step 1: Write the failing tests**

```python
# dots/.config/kitty/test_particles_detect.py
import unittest

from particles_detect import Snapshot, char_at, detect_event, parse_snapshot


def make_as_text_output(lines, row, col):
    text = "\n".join(lines) + "\n"
    text += f"\x1b[?25h\x1b[{row + 1};{col + 1}H"
    return text


class ParseSnapshotTests(unittest.TestCase):
    def test_parses_cursor_position_and_lines(self):
        output = make_as_text_output(["hello", "world"], row=1, col=3)
        snap = parse_snapshot(output)
        self.assertEqual(snap.row, 1)
        self.assertEqual(snap.col, 3)
        self.assertEqual(snap.lines, ["hello", "world"])

    def test_returns_none_without_a_cursor_sequence(self):
        self.assertIsNone(parse_snapshot("hello\nworld\n"))


class CharAtTests(unittest.TestCase):
    def test_in_bounds(self):
        self.assertEqual(char_at(["hello"], 0, 1), "e")

    def test_out_of_bounds_row_returns_space(self):
        self.assertEqual(char_at(["hello"], 5, 0), " ")

    def test_out_of_bounds_col_returns_space(self):
        self.assertEqual(char_at(["hi"], 0, 10), " ")


class DetectEventTests(unittest.TestCase):
    def test_no_event_on_first_snapshot(self):
        curr = Snapshot(row=0, col=1, lines=["h"])
        self.assertIsNone(detect_event(None, curr))

    def test_typing_a_character(self):
        prev = Snapshot(row=0, col=0, lines=[""])
        curr = Snapshot(row=0, col=1, lines=["h"])
        self.assertEqual(detect_event(prev, curr), (0, 0, "char"))

    def test_backspace(self):
        prev = Snapshot(row=0, col=1, lines=["h"])
        curr = Snapshot(row=0, col=0, lines=[""])
        self.assertEqual(detect_event(prev, curr), (0, 0, "backspace"))

    def test_arrow_key_over_existing_text_is_ignored(self):
        prev = Snapshot(row=0, col=0, lines=["hi"])
        curr = Snapshot(row=0, col=1, lines=["hi"])
        self.assertIsNone(detect_event(prev, curr))

    def test_row_change_is_ignored(self):
        prev = Snapshot(row=0, col=5, lines=["hello", ""])
        curr = Snapshot(row=1, col=0, lines=["hello", ""])
        self.assertIsNone(detect_event(prev, curr))

    def test_multi_cell_jump_is_ignored(self):
        prev = Snapshot(row=0, col=0, lines=["hello"])
        curr = Snapshot(row=0, col=5, lines=["hello"])
        self.assertIsNone(detect_event(prev, curr))

    def test_overwriting_a_character_fires_a_char_event(self):
        prev = Snapshot(row=0, col=0, lines=["x"])
        curr = Snapshot(row=0, col=1, lines=["y"])
        self.assertEqual(detect_event(prev, curr), (0, 0, "char"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd dots/.config/kitty && python3 -m unittest test_particles_detect -v`
Expected: FAIL/ERROR — `ModuleNotFoundError: No module named 'particles_detect'`

- [ ] **Step 3: Write the implementation**

```python
# dots/.config/kitty/particles_detect.py
"""Pure logic for detecting single-character-typed / backspace events from
consecutive kitty screen snapshots. No kitty dependency — testable standalone
with `python3 -m unittest`. See docs/superpowers/specs/2026-07-26-kitty-typing-particles-design.md.
"""
from __future__ import annotations

import re
from typing import NamedTuple, Optional

_CURSOR_RE = re.compile(r"\x1b\[(\d+);(\d+)H")
_CURSOR_INTRO = "\x1b[?25"


class Snapshot(NamedTuple):
    row: int
    col: int
    lines: list[str]


def parse_snapshot(as_text_output: str) -> Optional[Snapshot]:
    """Parse the string returned by kitty's window.as_text(add_cursor=True)."""
    match = _CURSOR_RE.search(as_text_output)
    if match is None:
        return None
    row = int(match.group(1)) - 1
    col = int(match.group(2)) - 1
    plain = as_text_output[: match.start()]
    intro = plain.rfind(_CURSOR_INTRO)
    if intro != -1:
        plain = plain[:intro]
    lines = plain.split("\n")
    return Snapshot(row=row, col=col, lines=lines)


def char_at(lines: list[str], row: int, col: int) -> str:
    if row < 0 or row >= len(lines):
        return " "
    line = lines[row]
    if col < 0 or col >= len(line):
        return " "
    return line[col]


def detect_event(prev: Optional[Snapshot], curr: Snapshot) -> Optional[tuple[int, int, str]]:
    """Returns (row, col, kind) where kind is 'char' or 'backspace', or None."""
    if prev is None or curr.row != prev.row:
        return None
    if curr.col == prev.col + 1:
        old_char = char_at(prev.lines, prev.row, prev.col)
        new_char = char_at(curr.lines, curr.row, prev.col)
        if new_char != " " and new_char != old_char:
            return (prev.row, prev.col, "char")
        return None
    if curr.col == prev.col - 1:
        old_char = char_at(prev.lines, prev.row, curr.col)
        new_char = char_at(curr.lines, curr.row, curr.col)
        if old_char != " " and new_char == " ":
            return (curr.row, curr.col, "backspace")
        return None
    return None
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd dots/.config/kitty && python3 -m unittest test_particles_detect -v`
Expected: PASS — all 10 tests green

- [ ] **Step 5: Commit**

```bash
cd ~/Projects/ii-lacuna
git add dots/.config/kitty/particles_detect.py dots/.config/kitty/test_particles_detect.py
git commit -m "Add pure detection logic for kitty typing particles"
```

---

### Task 2: Kitty watcher glue (`particles_watcher.py`)

**Files:**
- Create: `dots/.config/kitty/particles_watcher.py`

**Interfaces:**
- Consumes: `Snapshot`, `parse_snapshot`, `char_at`, `detect_event` from `particles_detect` (Task 1), `add_timer`/`remove_timer` from `kitty.fast_data_types` (kitty built-in, confirmed present in `/usr/lib/kitty/kitty/fast_data_types.so`).
- Produces: module-level `on_focus_change(boss, window, data)` and `on_close(boss, window, data)` — the exact hook names kitty's watcher loader (`kitty/launch.py:load_watch_modules`) looks up by name on the loaded module.

No automated test here — this file only runs meaningfully inside kitty's process (it imports `kitty.fast_data_types`, unavailable outside kitty). Validated manually in Task 8.

- [ ] **Step 1: Write the watcher**

```python
# dots/.config/kitty/particles_watcher.py
"""Kitty watcher — streams a particle-burst event to the Quickshell renderer
for each detected single-character-typed or backspace event, while a kitty
window is focused. See docs/superpowers/specs/2026-07-26-kitty-typing-particles-design.md.

Registered via `watcher particles_watcher.py` in kitty.conf. Kitty loads this
file with runpy and looks up on_focus_change/on_close by name — see
kitty/launch.py:load_watch_modules in the kitty source for the loading contract.
"""
import os
import socket
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from particles_detect import detect_event, parse_snapshot  # noqa: E402

from kitty.fast_data_types import add_timer, remove_timer  # type: ignore  # noqa: E402

POLL_INTERVAL = 0.02  # seconds, ~50Hz
SOCKET_PATH = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "particles.sock")

_timers: dict[int, int] = {}  # window.id -> timer_id
_sock: "socket.socket | None" = None


def _get_socket() -> "socket.socket | None":
    global _sock
    if _sock is not None:
        return _sock
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        s.setblocking(False)
        _sock = s
    except OSError:
        _sock = None
    return _sock


def _send(row: int, col: int, cols: int, lines: int, kind: str) -> None:
    global _sock
    sock = _get_socket()
    if sock is None:
        return
    try:
        sock.sendall(f"{row},{col},{cols},{lines},{kind}\n".encode())
    except OSError:
        _sock = None


def _make_poller(window):
    state = {"snapshot": None}

    def _poll(timer_id):
        text = window.as_text(add_cursor=True)
        snap = parse_snapshot(text)
        if snap is None:
            return
        event = detect_event(state["snapshot"], snap)
        state["snapshot"] = snap
        if event is not None:
            row, col, kind = event
            _send(row, col, window.screen.columns, window.screen.lines, kind)

    return _poll


def on_focus_change(boss, window, data):
    if data.get("focused"):
        if window.id in _timers:
            return
        timer_id = add_timer(_make_poller(window), POLL_INTERVAL, True)
        _timers[window.id] = timer_id
    else:
        timer_id = _timers.pop(window.id, None)
        if timer_id is not None:
            remove_timer(timer_id)


def on_close(boss, window, data):
    timer_id = _timers.pop(window.id, None)
    if timer_id is not None:
        remove_timer(timer_id)
```

- [ ] **Step 2: Syntax-check the file outside kitty**

Run: `python3 -c "import ast; ast.parse(open('dots/.config/kitty/particles_watcher.py').read())"`
Expected: no output, exit code 0 (this only validates syntax — the `kitty.fast_data_types` import can't resolve outside kitty's process, that's expected and fine)

- [ ] **Step 3: Commit**

```bash
cd ~/Projects/ii-lacuna
git add dots/.config/kitty/particles_watcher.py
git commit -m "Add kitty watcher for typing-particles sensor"
```

---

### Task 3: Register the watcher in kitty.conf

**Files:**
- Modify: `dots/.config/kitty/kitty.conf` (append after the `# Claude Code` map block, before the `# BEGIN_KITTY_THEME` marker — do not insert inside the theme block, kitty manages it)

**Interfaces:** None — config-only change.

- [ ] **Step 1: Add the watcher directive**

Insert after the existing:
```
# Claude Code
map ctrl+shift+k launch --cwd=current claude
```
and before:
```
# BEGIN_KITTY_THEME
```
the new block:
```

# Typing particles
watcher particles_watcher.py
```

- [ ] **Step 2: Verify kitty accepts the config without error**

Run: `kitty +kitten themes --reload-in=all >/dev/null 2>&1; kitty @ --to unix:/tmp/kitty ls >/dev/null && echo "kitty still responding"` — or simpler, just check the currently running kitty's config didn't already error on load by checking its stderr/journal if launched via systemd, since kitty only reloads watchers for *new* windows, not the currently running one.

Simplest real check: open a **new** kitty window (`kitty @ launch --type=os-window`) and confirm it opens normally with no error dialog/log entry. Then run `kitty @ --to unix:/tmp/kitty ls | python3 -c "import json,sys; json.load(sys.stdin)" && echo "config valid"` to confirm kitty's remote control is still healthy (a broken watcher load would show as a logged error, not a hard crash, so this is a smoke test, not a guarantee — full behavioral verification happens in Task 8).

- [ ] **Step 3: Commit**

```bash
cd ~/Projects/ii-lacuna
git add dots/.config/kitty/kitty.conf
git commit -m "Enable the typing-particles watcher in kitty.conf"
```

---

### Task 4: Particle visual (`Particle.qml`)

**Files:**
- Create: `dots/.config/quickshell/noctalia-shell/Modules/Particles/Particle.qml`

**Interfaces:**
- Produces: a `Particle` QML component with settable properties `angle` (real, radians), `distance` (real, px), `particleColor` (color), `particleSize` (int, px), `particleDuration` (int, ms). On creation it animates from its initial `x`/`y` outward by `distance` at `angle`, fades opacity to 0 and scales to 0.2 over `particleDuration`, then destroys itself — no external caller needs to clean it up. Task 6 (`ParticlesOverlay.qml`) instantiates this via `Qt.createComponent`/`createObject`, setting `x`/`y` to the spawn point and the properties above.

No automated test — this project has no QML test harness (confirmed: no `*test*`/`*spec*` files anywhere under `dots/.config/quickshell` beyond manual dev shell scripts). Validated visually in Task 8.

- [ ] **Step 1: Write the component**

```qml
// dots/.config/quickshell/noctalia-shell/Modules/Particles/Particle.qml
import QtQuick

Rectangle {
  id: root

  property real angle: 0
  property real distance: 40
  property color particleColor: "white"
  property int particleSize: 5
  property int particleDuration: 400

  width: particleSize
  height: particleSize
  radius: particleSize / 2
  color: particleColor

  Component.onCompleted: {
    xAnim.to = x + Math.cos(angle) * distance
    yAnim.to = y + Math.sin(angle) * distance
    xAnim.start()
    yAnim.start()
    fadeAnim.start()
    shrinkAnim.start()
    lifeTimer.start()
  }

  NumberAnimation {
    id: xAnim
    target: root
    property: "x"
    duration: root.particleDuration
    easing.type: Easing.OutQuad
  }

  NumberAnimation {
    id: yAnim
    target: root
    property: "y"
    duration: root.particleDuration
    easing.type: Easing.OutQuad
  }

  NumberAnimation {
    id: fadeAnim
    target: root
    property: "opacity"
    to: 0
    duration: root.particleDuration
    easing.type: Easing.InQuad
  }

  NumberAnimation {
    id: shrinkAnim
    target: root
    property: "scale"
    to: 0.2
    duration: root.particleDuration
    easing.type: Easing.InQuad
  }

  Timer {
    id: lifeTimer
    interval: root.particleDuration
    onTriggered: root.destroy()
  }
}
```

- [ ] **Step 2: Syntax sanity check**

Run: `qmllint dots/.config/quickshell/noctalia-shell/Modules/Particles/Particle.qml` if `qmllint` is available (`which qmllint`); if not installed, skip — this is a lint pass, not required tooling for the project (confirmed: no existing `.qml` lint step found elsewhere in this repo's scripts).

- [ ] **Step 3: Commit**

```bash
cd ~/Projects/ii-lacuna
git add dots/.config/quickshell/noctalia-shell/Modules/Particles/Particle.qml
git commit -m "Add particle burst visual component"
```

---

### Task 5: Particles service singleton (`ParticlesService.qml`)

**Files:**
- Create: `dots/.config/quickshell/noctalia-shell/Services/Particles/ParticlesService.qml`

**Interfaces:**
- Consumes: nothing from earlier tasks directly (no QML import cycle — Task 6 depends on this, not the reverse).
- Produces: singleton `ParticlesService` (via `pragma Singleton`, following the exact pattern of `Services/Control/IPCService.qml` — no `qmldir` needed, confirmed none exists for that directory either) exposing `function registerOverlay(screenName: string, overlay: var)`, `function unregisterOverlay(screenName: string)`. Task 6 calls both on `Component.onCompleted`/`Component.onDestruction`. The overlay objects registered must expose `containsPoint(px, py)` and `spawnBurst(localX, localY, kind)` — Task 6 provides both.

No automated test — depends on a live `Quickshell.Hyprland` connection and Wayland socket, not testable outside a running shell. Validated manually in Task 8, plus a standalone socket-write smoke test at the end of this task.

- [ ] **Step 1: Write the service**

```qml
// dots/.config/quickshell/noctalia-shell/Services/Particles/ParticlesService.qml
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
```

- [ ] **Step 2: Commit**

```bash
cd ~/Projects/ii-lacuna
git add dots/.config/quickshell/noctalia-shell/Services/Particles/ParticlesService.qml
git commit -m "Add ParticlesService singleton: socket IPC + Hyprland pixel resolution"
```

(A `SocketServer` bind failure from a stale socket file — e.g. a crashed previous run left `$XDG_RUNTIME_DIR/particles.sock` behind — is handled by Quickshell's `Reloadable`/`SocketServer` machinery itself reusing or replacing the path on (re)activation; if this proves not to be the case during Task 8's manual validation, add an explicit `Quickshell.execDetached(["rm", "-f", path])` before setting `active: true` as a follow-up — noted here rather than speculatively coded now, since it can't be verified without a live crash-and-restart test.)

---

### Task 6: Per-screen overlay + shell registration (`ParticlesOverlay.qml`)

**Files:**
- Create: `dots/.config/quickshell/noctalia-shell/Modules/Particles/ParticlesOverlay.qml`
- Modify: `dots/.config/quickshell/noctalia-shell/shell.qml` (add import + instantiation)

**Interfaces:**
- Consumes: `ParticlesService.registerOverlay`/`unregisterOverlay` (Task 5), `Particle.qml` (Task 4, same directory — no import needed, sibling `.qml` files in the same folder are directly usable as tag names in Quickshell/QML), `Color.mPrimary`/`Color.mSecondary` (`qs.Commons`, confirmed present in `Commons/Color.qml`).
- Produces: nothing consumed by later tasks — this is the final integration point.

- [ ] **Step 1: Write the overlay**

```qml
// dots/.config/quickshell/noctalia-shell/Modules/Particles/ParticlesOverlay.qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Particles

Variants {
  id: root
  model: Quickshell.screens

  delegate: PanelWindow {
    id: overlayWindow
    required property ShellScreen modelData
    screen: modelData

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "noctalia-particles"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Click-through — particles are display-only, no input needed
    mask: Region {}

    readonly property real screenX: modelData.x
    readonly property real screenY: modelData.y

    property var particleComponent: Qt.createComponent("Particle.qml")

    function containsPoint(px, py) {
      return px >= modelData.x && px < modelData.x + modelData.width && py >= modelData.y && py < modelData.y + modelData.height;
    }

    function spawnBurst(localX, localY, kind) {
      if (particleComponent.status !== Component.Ready) return;
      const isBackspace = kind === "backspace";
      const count = isBackspace ? 4 : 8;
      for (let i = 0; i < count; i++) {
        const angle = Math.random() * Math.PI * 2;
        const distance = isBackspace ? 16 + Math.random() * 20 : 24 + Math.random() * 32;
        const duration = isBackspace ? 250 + Math.random() * 150 : 300 + Math.random() * 200;
        const size = isBackspace ? 3 + Math.random() * 2 : 4 + Math.random() * 3;
        const particleColor = isBackspace ? Color.mSecondary : (Math.random() < 0.5 ? Color.mPrimary : Color.mSecondary);
        particleComponent.createObject(overlayWindow.contentItem, {
          "x": localX,
          "y": localY,
          "angle": angle,
          "distance": distance,
          "particleDuration": duration,
          "particleSize": size,
          "particleColor": particleColor
        });
      }
    }

    Component.onCompleted: ParticlesService.registerOverlay(modelData.name, overlayWindow)
    Component.onDestruction: ParticlesService.unregisterOverlay(modelData.name)
  }
}
```

- [ ] **Step 2: Register the module in shell.qml**

In `dots/.config/quickshell/noctalia-shell/shell.qml`, add to the import block (alongside the other `qs.Modules.*` imports, e.g. after line 26 `import qs.Modules.OSD`):

```qml
import qs.Modules.Particles
```

And add the instantiation near the other always-on overlay modules (after line 162's `FadeOverlay {}`):

```qml
      FadeOverlay {}
      ParticlesOverlay {}
```

- [ ] **Step 3: Smoke-test the socket path without kitty**

With `quickshell-noctalia.service` running (it auto-picks up new files under the live-symlinked config dir, but restart it to be sure the new modules load):

```bash
systemctl --user restart quickshell-noctalia.service
sleep 2
echo "5,10,80,24,char" | socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/particles.sock
```

Expected: no error from `socat`; a burst of 8 particles appears on whichever monitor the currently-focused window's geometry places row 5/col 10 of an 80x24 grid onto (this requires *some* window to be focused when the message arrives, since `Hyprland.activeToplevel` is what resolves the target — focus a kitty window, or any window, before running the command). If `socat` isn't installed, use `python3 -c "import socket,os; s=socket.socket(socket.AF_UNIX); s.connect(os.environ['XDG_RUNTIME_DIR']+'/particles.sock'); s.sendall(b'5,10,80,24,char\n')"` instead.

- [ ] **Step 4: Commit**

```bash
cd ~/Projects/ii-lacuna
git add dots/.config/quickshell/noctalia-shell/Modules/Particles/ParticlesOverlay.qml dots/.config/quickshell/noctalia-shell/shell.qml
git commit -m "Add per-screen particle overlay and register it in the shell"
```

---

### Task 7: End-to-end manual validation

**Files:** none (validation only — no code changes expected unless a bug surfaces, in which case fix it in the relevant task's file and re-run this checklist)

Restart both halves fresh so nothing stale is in play:

```bash
systemctl --user restart quickshell-noctalia.service
kitty @ close-window --match all 2>/dev/null  # or just close all kitty windows by hand
```

Then open a **new** kitty window (so it loads the freshly-registered watcher) and work through the spec's validation checklist:

- [ ] **Step 1:** Type normal text — confirm a burst fires per character in the active scheme's colors and fades within half a second
- [ ] **Step 2:** Hold backspace — confirm the smaller/fewer-particle backspace treatment fires per deletion
- [ ] **Step 3:** Type fast (hold a key, or paste a chunk of text) — confirm no input lag or dropped keystrokes in the terminal itself, and confirm pasted/completed multi-char insertions do *not* spam a burst per character (expected per the detection design in Task 1)
- [ ] **Step 4:** Move and resize the kitty window, then type again — confirm bursts still land on the correct cell
- [ ] **Step 5:** Open a second kitty window on a second monitor, type in each — confirm bursts render on the correct monitor
- [ ] **Step 6:** Run `systemctl --user restart quickshell-noctalia.service` while a kitty window is focused, then type immediately — confirm no error/hang in kitty, then confirm bursts resume once the service is back up
- [ ] **Step 7:** Switch to a non-Aether color scheme in the shell settings — confirm particles re-color to match instead of staying hardcoded cyan/violet
- [ ] **Step 8:** Only if any step above fails: fix the relevant file from Tasks 1-6, commit the fix, and re-run this checklist from the top

If all 7 steps pass, the feature is complete.
