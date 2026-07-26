# Holographic Glass Shell Reskin — Foundation + Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new "Aether" holographic color scheme, a reusable `NHoloPanel` glass+glow widget, and two shader-driven motion effects (idle scanline sweep, state-change flicker pulse), wired into the Bar's three section containers only.

**Architecture:** Everything is additive — a new scheme JSON, one new shared widget, two new shader files. `NHoloPanel` replaces the plain `Rectangle` currently used by Bar.qml's `SectionIsland` component. The widget stays fully generic (no compositor/event coupling baked in) so later passes can reuse it on other modules; Bar.qml itself owns the decision to trigger the flicker on workspace switches.

**Tech Stack:** QML (Quickshell), QtQuick.Shapes, QtQuick.Effects (`MultiEffect` via existing `NDropShadow`), GLSL fragment shaders compiled to `.qsb` via `qsb` (Qt Shader Tools, already installed at `/usr/lib/qt6/bin/qsb`).

## Global Constraints

- Reuse the existing scheme JSON schema exactly (`mPrimary`/`mOnPrimary`/.../`mOnHover` + `terminal` block) — see `Assets/ColorScheme/Rosepine/Rosepine.json` as the reference.
- Shared widgets live in `Widgets/` and follow the existing `N`-prefix naming convention (e.g. `NHoloPanel.qml`).
- Any new motion effect must be gated behind `PowerProfileService.noctaliaPerformanceMode` (import `qs.Services.Power`), matching how `Style.qml` already gates `effectivePanelOpacity`/`animationFast`/etc.
- Do not touch, stage, or commit any of the pre-existing unrelated uncommitted changes already in the working tree (fish/foot/fuzzel/kitty/starship/hypr config edits, untracked systemd DND timer units) — `git add` only the specific files each task creates or modifies.
- Do not wire `NHoloPanel` into any module besides the Bar in this pass (Dock/OSD/Panels/etc. are explicitly deferred).
- No automated test suite exists for this shell (it's a QML dotfiles config, not an application with a test harness) — verification is: compile shaders with `qsb`, restart `quickshell-noctalia.service`, visually confirm in the running shell, and check `journalctl --user -u quickshell-noctalia.service` for QML errors (a `quickshell-error-watch.sh` process already tails this log continuously).

---

## Task 1: Add the Aether color scheme

**Files:**
- Create: `dots/.config/quickshell/noctalia-shell/Assets/ColorScheme/Aether/Aether.json`

**Interfaces:**
- Produces: a scheme selectable by name "Aether" in the existing scheme picker (consumed automatically by `ColorSchemeService`/`Color.qml` — no code changes needed to pick it up).

- [ ] **Step 1: Write the scheme JSON**

```json
{
  "dark": {
    "mPrimary": "#3ad6ff",
    "mOnPrimary": "#00131a",
    "mSecondary": "#7c4dff",
    "mOnSecondary": "#0e0326",
    "mTertiary": "#00e5c0",
    "mOnTertiary": "#00201a",
    "mError": "#ff4d6d",
    "mOnError": "#1a0006",
    "mSurface": "#050710",
    "mOnSurface": "#d6ecff",
    "mSurfaceVariant": "#0d1224",
    "mOnSurfaceVariant": "#8fa8c9",
    "mOutline": "#3ad6ff",
    "mShadow": "#000000",
    "mHover": "#16203a",
    "mOnHover": "#d6ecff",
    "terminal": {
      "normal": {
        "black": "#0d1224",
        "red": "#ff4d6d",
        "green": "#00e5c0",
        "yellow": "#ffd166",
        "blue": "#3ad6ff",
        "magenta": "#7c4dff",
        "cyan": "#3ad6ff",
        "white": "#d6ecff"
      },
      "bright": {
        "black": "#3a4668",
        "red": "#ff4d6d",
        "green": "#00e5c0",
        "yellow": "#ffd166",
        "blue": "#3ad6ff",
        "magenta": "#7c4dff",
        "cyan": "#3ad6ff",
        "white": "#ffffff"
      },
      "foreground": "#d6ecff",
      "background": "#050710",
      "selectionFg": "#050710",
      "selectionBg": "#3ad6ff",
      "cursorText": "#050710",
      "cursor": "#d6ecff"
    }
  },
  "light": {
    "mPrimary": "#0077a3",
    "mOnPrimary": "#ffffff",
    "mSecondary": "#5b2ecf",
    "mOnSecondary": "#ffffff",
    "mTertiary": "#00806b",
    "mOnTertiary": "#ffffff",
    "mError": "#c0293f",
    "mOnError": "#ffffff",
    "mSurface": "#f2f6fb",
    "mOnSurface": "#0d1a2c",
    "mSurfaceVariant": "#e2e9f5",
    "mOnSurfaceVariant": "#42546e",
    "mOutline": "#0077a3",
    "mShadow": "#000000",
    "mHover": "#d7e3f5",
    "mOnHover": "#0d1a2c",
    "terminal": {
      "normal": {
        "black": "#e2e9f5",
        "red": "#c0293f",
        "green": "#00806b",
        "yellow": "#a3720a",
        "blue": "#0077a3",
        "magenta": "#5b2ecf",
        "cyan": "#0077a3",
        "white": "#0d1a2c"
      },
      "bright": {
        "black": "#42546e",
        "red": "#c0293f",
        "green": "#00806b",
        "yellow": "#a3720a",
        "blue": "#0077a3",
        "magenta": "#5b2ecf",
        "cyan": "#0077a3",
        "white": "#000000"
      },
      "foreground": "#0d1a2c",
      "background": "#f2f6fb",
      "selectionFg": "#ffffff",
      "selectionBg": "#0077a3",
      "cursorText": "#ffffff",
      "cursor": "#0d1a2c"
    }
  }
}
```

- [ ] **Step 2: Verify the JSON parses and the scheme shows up**

Run: `python3 -c "import json; json.load(open('dots/.config/quickshell/noctalia-shell/Assets/ColorScheme/Aether/Aether.json'))" && echo OK` from the repo root.
Expected: `OK`, no exception.

Then restart the shell so `ColorSchemeService` rescans:
Run: `systemctl --user restart quickshell-noctalia.service`
Open the shell's settings panel, go to the color scheme picker, confirm "Aether" (or "Aether (default)" depending on how `getBasename` formats it) appears in the list and can be selected without errors in the log:
Run: `journalctl --user -u quickshell-noctalia.service -n 50 --no-pager | grep -i "aether\|error"`
Expected: no parse errors; selecting it changes the shell's accent colors to cyan/violet on a near-black surface.

- [ ] **Step 3: Commit**

```bash
cd ~/Projects/ii-lacuna
git add dots/.config/quickshell/noctalia-shell/Assets/ColorScheme/Aether/Aether.json
git commit -m "noctalia-shell: add Aether holographic color scheme"
```

---

## Task 2: Build `NHoloPanel` and wire it into the Bar

**Files:**
- Create: `dots/.config/quickshell/noctalia-shell/Widgets/NHoloPanel.qml`
- Modify: `dots/.config/quickshell/noctalia-shell/Modules/Bar/Bar.qml:678-699` (the `SectionIsland` component and its 3 instantiations)

**Interfaces:**
- Produces: `NHoloPanel` — an `Item` with properties `cutSize: real`, `fillColor: color` (default `Color.mSurface`), `fillOpacity: real` (default `1.0`), `glowColor: color` (default `Color.mPrimary`), `showBorder: bool` (default `true`), and a public no-arg function `pulse()` that later tasks will hook up to trigger the flicker shader. In this task `pulse()` exists but has no effect yet (flicker shader lands in Task 4).
- Consumes: `Color.mSurface`/`Color.mPrimary` (existing singleton), `Style.borderS` (existing token), `NDropShadow` (existing shared widget, unchanged).

- [ ] **Step 1: Create `NHoloPanel.qml`**

```qml
import QtQuick
import QtQuick.Shapes
import qs.Commons

// Angular cut-corner glass panel with a glowing border.
// NDropShadow is a sibling in this same Widgets/ directory, so no import is
// needed to use it below (matches the existing convention in this folder —
// e.g. NCheckbox.qml, NImageRounded.qml reference sibling widgets the same way).
// Replaces plain rounded-rect backgrounds where the holographic look is wanted.
Item {
  id: root

  property real cutSize: Math.min(width, height) * 0.28
  property color fillColor: Color.mSurface
  property real fillOpacity: 1.0
  property color glowColor: Color.mPrimary
  property bool showBorder: true

  function pulse() {
    // Hooked up by shader tasks later; no-op until then.
  }

  NDropShadow {
    anchors.fill: parent
    source: panelShape
    shadowColor: root.glowColor
    shadowBlur: 0.6
    shadowOpacity: 0.8
  }

  Shape {
    id: panelShape
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, root.fillOpacity)
      strokeColor: root.showBorder ? root.glowColor : "transparent"
      strokeWidth: root.showBorder ? Style.borderS : 0
      startX: 0
      startY: 0
      PathLine {
        x: panelShape.width - root.cutSize
        y: 0
      }
      PathLine {
        x: panelShape.width
        y: root.cutSize
      }
      PathLine {
        x: panelShape.width
        y: panelShape.height
      }
      PathLine {
        x: root.cutSize
        y: panelShape.height
      }
      PathLine {
        x: 0
        y: panelShape.height - root.cutSize
      }
      PathLine {
        x: 0
        y: 0
      }
    }
  }
}
```

- [ ] **Step 2: Swap `SectionIsland` in `Bar.qml` to use it**

In `Modules/Bar/Bar.qml`, replace lines 678-699 (the `component SectionIsland: Rectangle { ... }` definition and its 3 instantiations):

```qml
      component SectionIsland: Rectangle {
        z: -1
        radius: height / 2
        color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, Settings.data.bar.capsuleOpacity)
        border.width: Settings.data.bar.showOutline ? 1 : 0
        border.color: Color.mOutline
      }
      SectionIsland {
        anchors.fill: leftSection
        anchors.margins: -islandPad
        visible: Settings.data.bar.segmentedIslands && root.leftWidgetsModel.count > 0
      }
      SectionIsland {
        anchors.fill: centerSection
        anchors.margins: -islandPad
        visible: Settings.data.bar.segmentedIslands && root.centerWidgetsModel.count > 0
      }
      SectionIsland {
        anchors.fill: rightSection
        anchors.margins: -islandPad
        visible: Settings.data.bar.segmentedIslands && root.rightWidgetsModel.count > 0
      }
```

with:

```qml
      component SectionIsland: NHoloPanel {
        z: -1
        fillColor: Color.mSurface
        fillOpacity: Settings.data.bar.capsuleOpacity
        glowColor: Color.mOutline
        showBorder: Settings.data.bar.showOutline
      }
      SectionIsland {
        id: leftIsland
        anchors.fill: leftSection
        anchors.margins: -islandPad
        visible: Settings.data.bar.segmentedIslands && root.leftWidgetsModel.count > 0
      }
      SectionIsland {
        id: centerIsland
        anchors.fill: centerSection
        anchors.margins: -islandPad
        visible: Settings.data.bar.segmentedIslands && root.centerWidgetsModel.count > 0
      }
      SectionIsland {
        id: rightIsland
        anchors.fill: rightSection
        anchors.margins: -islandPad
        visible: Settings.data.bar.segmentedIslands && root.rightWidgetsModel.count > 0
      }
```

(The `id`s on the three instances aren't used until Task 4, but adding them now avoids a second edit to this block later.)

`Bar.qml` already has `import qs.Widgets` (line 14), so no import changes are needed.

- [ ] **Step 3: Verify visually**

Run: `systemctl --user restart quickshell-noctalia.service`
Then: `journalctl --user -u quickshell-noctalia.service -n 50 --no-pager | grep -i error`
Expected: no QML errors (property binding errors show up here immediately if `NHoloPanel` has a typo).

Look at the Bar: each non-empty section (left/center/right) should now show an angular cut-corner glass panel with a glowing border instead of the old rounded pill, in whatever scheme's `mSurface`/`mOutline` colors are currently active. Switch to the Aether scheme from Task 1 and confirm the glow reads cyan.

- [ ] **Step 4: Commit**

```bash
cd ~/Projects/ii-lacuna
git add dots/.config/quickshell/noctalia-shell/Widgets/NHoloPanel.qml dots/.config/quickshell/noctalia-shell/Modules/Bar/Bar.qml
git commit -m "noctalia-shell: add NHoloPanel, use it for Bar section islands"
```

---

## Task 3: Add the idle scanline sweep shader

**Files:**
- Create: `dots/.config/quickshell/noctalia-shell/Shaders/frag/holoScanline.frag`
- Create (generated): `dots/.config/quickshell/noctalia-shell/Shaders/qsb/holoScanline.frag.qsb`
- Modify: `dots/.config/quickshell/noctalia-shell/Widgets/NHoloPanel.qml`

**Interfaces:**
- Consumes: `PowerProfileService.noctaliaPerformanceMode` (existing singleton, `qs.Services.Power`).
- Produces: no new public interface — this is purely a visual overlay added inside `NHoloPanel`.

- [ ] **Step 1: Write the shader source**

```glsl
#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 glowColor;
} ubuf;

void main() {
    vec4 base = texture(source, qt_TexCoord0);

    float dist = abs(qt_TexCoord0.y - ubuf.time);
    float band = smoothstep(0.05, 0.0, dist) * base.a;

    fragColor = vec4(ubuf.glowColor.rgb * band * ubuf.qt_Opacity, band * ubuf.qt_Opacity);
}
```

This only ever draws the sweep band, clipped to the panel's alpha shape (`base.a`) — it does not redraw the panel's own fill, so it composites cleanly as an overlay on top of the `Shape` from Task 2.

- [ ] **Step 2: Compile it**

Run (from `dots/.config/quickshell/noctalia-shell/`): `Scripts/dev/shaders-compile.sh holoScanline.frag`
Expected output: `Compiled holoScanline.frag to Shaders/qsb/holoScanline.frag.qsb` then `Shader compilation complete.`

- [ ] **Step 3: Add the overlay to `NHoloPanel.qml`**

Add inside the `Item { id: root ... }` block, after the `Shape { id: panelShape ... }` block:

```qml
  Loader {
    id: scanlineLoader
    anchors.fill: parent
    active: !PowerProfileService.noctaliaPerformanceMode

    sourceComponent: Item {
      property real shaderTime: 0
      NumberAnimation on shaderTime {
        loops: Animation.Infinite
        from: 0
        to: 1
        duration: 4000
      }

      ShaderEffect {
        anchors.fill: parent
        blending: true
        property var source: ShaderEffectSource {
          sourceItem: panelShape
          hideSource: false
        }
        property real time: parent.shaderTime
        property color glowColor: root.glowColor

        fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/holoScanline.frag.qsb")
      }
    }
  }
```

Add the two missing imports at the top of `NHoloPanel.qml`:

```qml
import Quickshell
import qs.Services.Power
```

(alongside the existing `import QtQuick` / `import QtQuick.Shapes` / `import qs.Commons`)

- [ ] **Step 4: Verify visually**

Run: `systemctl --user restart quickshell-noctalia.service`
Run: `journalctl --user -u quickshell-noctalia.service -n 50 --no-pager | grep -i error`
Expected: no shader-compile or QML errors. Watch the Bar's section panels — a soft glow band should sweep vertically through each one on a ~4 second loop, tinted the panel's `glowColor`.

Then toggle performance mode (however it's currently exposed — check `Settings.data.general` / the settings UI power section for the noctalia-performance-mode toggle) and confirm the sweep stops entirely while the plain glass+border panel remains visible.

- [ ] **Step 5: Commit**

```bash
cd ~/Projects/ii-lacuna
git add dots/.config/quickshell/noctalia-shell/Shaders/frag/holoScanline.frag dots/.config/quickshell/noctalia-shell/Shaders/qsb/holoScanline.frag.qsb dots/.config/quickshell/noctalia-shell/Widgets/NHoloPanel.qml
git commit -m "noctalia-shell: add idle scanline shader to NHoloPanel"
```

---

## Task 4: Add the flicker-pulse shader, triggered on workspace switch

**Files:**
- Create: `dots/.config/quickshell/noctalia-shell/Shaders/frag/holoFlicker.frag`
- Create (generated): `dots/.config/quickshell/noctalia-shell/Shaders/qsb/holoFlicker.frag.qsb`
- Modify: `dots/.config/quickshell/noctalia-shell/Widgets/NHoloPanel.qml`
- Modify: `dots/.config/quickshell/noctalia-shell/Modules/Bar/Bar.qml`

**Interfaces:**
- Consumes: `CompositorService.workspaceChanged` signal (existing, `qs.Services.Compositor` — already imported in `Bar.qml`).
- Produces: `NHoloPanel.pulse()` becomes functional — calling it triggers a brief flicker overlay.

- [ ] **Step 1: Write the shader source**

```glsl
#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float intensity;
    vec4 glowColor;
} ubuf;

void main() {
    vec4 base = texture(source, qt_TexCoord0);
    float a = base.a * ubuf.intensity;
    fragColor = vec4(ubuf.glowColor.rgb * a * ubuf.qt_Opacity, a * ubuf.qt_Opacity);
}
```

- [ ] **Step 2: Compile it**

Run (from `dots/.config/quickshell/noctalia-shell/`): `Scripts/dev/shaders-compile.sh holoFlicker.frag`
Expected: `Compiled holoFlicker.frag to Shaders/qsb/holoFlicker.frag.qsb` then `Shader compilation complete.`

- [ ] **Step 3: Add the flicker overlay + wire up `pulse()` in `NHoloPanel.qml`**

Replace the no-op `pulse()` function:

```qml
  function pulse() {
    // Hooked up by shader tasks later; no-op until then.
  }
```

with:

```qml
  function pulse() {
    if (flickerLoader.item)
      flickerLoader.item.pulse();
  }
```

Add a second `Loader`, after the `scanlineLoader` block:

```qml
  Loader {
    id: flickerLoader
    anchors.fill: parent
    active: !PowerProfileService.noctaliaPerformanceMode

    sourceComponent: Item {
      id: flickerRoot
      property real intensity: 0

      function pulse() {
        flickerAnim.restart();
      }

      SequentialAnimation {
        id: flickerAnim
        NumberAnimation {
          target: flickerRoot
          property: "intensity"
          to: 1.0
          duration: 60
        }
        NumberAnimation {
          target: flickerRoot
          property: "intensity"
          to: 0.0
          duration: 220
        }
      }

      ShaderEffect {
        anchors.fill: parent
        blending: true
        property var source: ShaderEffectSource {
          sourceItem: panelShape
          hideSource: false
        }
        property real intensity: flickerRoot.intensity
        property color glowColor: root.glowColor

        fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/holoFlicker.frag.qsb")
      }
    }
  }
```

- [ ] **Step 4: Trigger it from `Bar.qml` on workspace switch**

Add, right after the three `SectionIsland` instances (after the `rightIsland` block from Task 2):

```qml
      Connections {
        target: CompositorService
        function onWorkspaceChanged() {
          leftIsland.pulse();
          centerIsland.pulse();
          rightIsland.pulse();
        }
      }
```

`Bar.qml` already imports `qs.Services.Compositor` (line 11), so no import changes are needed there.

- [ ] **Step 5: Verify visually**

Run: `systemctl --user restart quickshell-noctalia.service`
Run: `journalctl --user -u quickshell-noctalia.service -n 50 --no-pager | grep -i error`
Expected: no errors.

Switch Hyprland workspaces (whatever your existing workspace-switch keybind is). Expected: each Bar section panel gives a quick bright flicker pulse in sync with the switch, then fades back to normal within ~300ms. Confirm it does not loop or repeat on its own between switches.

Toggle performance mode again and confirm workspace switches no longer trigger any flicker (the panel just stays static).

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/ii-lacuna
git add dots/.config/quickshell/noctalia-shell/Shaders/frag/holoFlicker.frag dots/.config/quickshell/noctalia-shell/Shaders/qsb/holoFlicker.frag.qsb dots/.config/quickshell/noctalia-shell/Widgets/NHoloPanel.qml dots/.config/quickshell/noctalia-shell/Modules/Bar/Bar.qml
git commit -m "noctalia-shell: add flicker-pulse shader, trigger on workspace switch"
```

---

## Deferred (not part of this plan)

Rolling `NHoloPanel` + the Aether scheme out to Dock, Panels, OSD, Toast, Tooltip, LockScreen, Cheatsheet, GameLauncher, DesktopWidgets, and the AudioSpectrum widget. Same foundation, no new design work — future passes just swap each module's background container the same way Task 2 did for the Bar, and decide their own `pulse()` triggers the way Task 4 did for workspace switches.
