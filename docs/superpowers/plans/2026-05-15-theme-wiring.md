# Theme Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist the active theme selection to disk, expose it globally via GlobalStates, auto-apply on startup, and replace the wrapping Flow chip layout with a tighter 3-column grid.

**Architecture:** `Persistent.states.activeTheme` is the source of truth (disk-backed via JsonAdapter). `GlobalStates.activeTheme` is a two-way binding convenience handle. `BarAppletsOverlay` drops its local property and binds through GlobalStates. On startup, non-Matugen themes are re-applied via the existing `applyTheme()` function.

**Tech Stack:** QML (Quickshell), QtQuick, QtQuick.Layouts

---

## Files

| File | Change |
|------|--------|
| `dots/.config/quickshell/ii/modules/common/Persistent.qml` | Add `property string activeTheme` to JsonAdapter |
| `dots/.config/quickshell/ii/GlobalStates.qml` | Add two-way binding `activeTheme` property |
| `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml` | Remove local property, update click handler, add startup apply, replace Flow with GridLayout |

All paths are relative to `/home/donnie/projects/ii-lacuna/`.

---

### Task 1: Add activeTheme to Persistent.states

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/common/Persistent.qml:62`

- [ ] **Step 1: Open the file and locate the insertion point**

  The `JsonAdapter` block starts around line 55. Find this line:
  ```
  property bool followNightLight: false
  ```

- [ ] **Step 2: Add the activeTheme property immediately after followNightLight**

  The result should look like:
  ```qml
  /** When true, shell light/dark (bar, sidebars, notifications) tracks Night Light (hyprsunset): on → dark theme, off → light. Toggle via right‑click the right dashboard button. */
  property bool followNightLight: false

  property string activeTheme: "Matugen"
  ```

- [ ] **Step 3: Verify the file is valid QML — no syntax errors**

  Run:
  ```bash
  cd /home/donnie/projects/ii-lacuna/dots/.config/quickshell/ii
  qmlformat --dry-run modules/common/Persistent.qml 2>&1 | grep -i error
  ```
  Expected: no output (no errors). If `qmlformat` isn't available, visually check the braces/indentation around the change.

- [ ] **Step 4: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.config/quickshell/ii/modules/common/Persistent.qml
  git commit -m "feat: persist activeTheme in Persistent.states"
  ```

---

### Task 2: Expose activeTheme globally via GlobalStates

**Files:**
- Modify: `dots/.config/quickshell/ii/GlobalStates.qml:16`

- [ ] **Step 1: Open the file and locate the insertion point**

  Find this line (around line 16):
  ```qml
  property bool barOpen: true
  ```

- [ ] **Step 2: Add the two-way binding property directly above barOpen**

  ```qml
  property string activeTheme: Persistent.states.activeTheme
  onActiveThemeChanged: Persistent.states.activeTheme = activeTheme

  property bool barOpen: true
  ```

  Note: `Persistent` is already accessible here because `GlobalStates.qml` imports `qs.modules.common`, which is the module containing `Persistent.qml`.

- [ ] **Step 3: Verify no syntax errors**

  ```bash
  qmlformat --dry-run /home/donnie/projects/ii-lacuna/dots/.config/quickshell/ii/GlobalStates.qml 2>&1 | grep -i error
  ```
  Expected: no output.

- [ ] **Step 4: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.config/quickshell/ii/GlobalStates.qml
  git commit -m "feat: expose activeTheme globally via GlobalStates"
  ```

---

### Task 3: Wire BarAppletsOverlay to GlobalStates.activeTheme

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml:74` (remove local property)
- Modify: `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml:295` (update click handler)
- Modify: `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml:50` (add Component.onCompleted)

- [ ] **Step 1: Remove the local activeTheme property**

  Find and delete this line (around line 74):
  ```qml
  property string activeTheme: "Matugen"
  ```
  Remove it entirely. `root.activeTheme` will now resolve to `GlobalStates.activeTheme` everywhere it's referenced in this file — QML property lookup will find it on `GlobalStates` since the binding is done there.

  Wait — QML won't automatically resolve `root.activeTheme` to `GlobalStates.activeTheme`. You need to update every reference to `root.activeTheme` to `GlobalStates.activeTheme`.

  Search for all occurrences:
  ```bash
  grep -n "root\.activeTheme\|activeTheme" /home/donnie/projects/ii-lacuna/dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml
  ```
  Expected lines to update: the property declaration (line ~74), the `isActive` binding (line ~266), and the click handler (line ~295).

- [ ] **Step 2: Update the isActive binding in the chip delegate**

  Find (around line 266):
  ```qml
  readonly property bool isActive: root.activeTheme === modelData
  ```
  Change to:
  ```qml
  readonly property bool isActive: GlobalStates.activeTheme === modelData
  ```

- [ ] **Step 3: Update the click handler**

  Find (around line 295):
  ```qml
  onClicked: { root.activeTheme = themeChip.modelData; root.applyTheme(themeChip.modelData) }
  ```
  Change to:
  ```qml
  onClicked: { GlobalStates.activeTheme = themeChip.modelData; root.applyTheme(themeChip.modelData) }
  ```

- [ ] **Step 4: Add Component.onCompleted for startup auto-apply**

  Find (around line 50):
  ```qml
  anchors.left: true
  anchors.right: true
  anchors.top: true
  anchors.bottom: true
  ```
  Add `Component.onCompleted` after the anchors block:
  ```qml
  anchors.left: true
  anchors.right: true
  anchors.top: true
  anchors.bottom: true

  Component.onCompleted: {
      if (GlobalStates.activeTheme !== "Matugen")
          applyTheme(GlobalStates.activeTheme)
  }
  ```

- [ ] **Step 5: Verify no remaining root.activeTheme references**

  ```bash
  grep -n "root\.activeTheme" /home/donnie/projects/ii-lacuna/dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml
  ```
  Expected: no output.

- [ ] **Step 6: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml
  git commit -m "feat: wire BarAppletsOverlay theme to GlobalStates"
  ```

---

### Task 4: Replace Flow with 3-column GridLayout

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml` (theme chip section ~257–297)

- [ ] **Step 1: Locate the Flow block**

  Find this block (around line 257):
  ```qml
  Flow {
      Layout.fillWidth: true
      spacing: 6

      Repeater {
          model: root.themeNames
          delegate: Rectangle {
              id: themeChip
              required property string modelData
              readonly property bool isActive: GlobalStates.activeTheme === modelData

              height: 30
              width: themeChipText.implicitWidth + 22
              radius: Appearance.rounding.full
              ...
          }
      }
  }
  ```

- [ ] **Step 2: Replace the entire Flow block with GridLayout**

  Replace the `Flow { ... }` block (from `Flow {` to its closing `}`) with:
  ```qml
  GridLayout {
      Layout.fillWidth: true
      columns: 3
      columnSpacing: 6
      rowSpacing: 6

      Repeater {
          model: root.themeNames
          delegate: Rectangle {
              id: themeChip
              required property string modelData
              readonly property bool isActive: GlobalStates.activeTheme === modelData

              Layout.fillWidth: true
              height: 30
              radius: Appearance.rounding.full
              color: isActive
              ? Appearance.colors.colPrimary
              : Appearance.m3colors.m3surfaceContainerHigh
              border.width: 1
              border.color: isActive ? "transparent"
              : Qt.rgba(Appearance.m3colors.m3outlineVariant.r,
                        Appearance.m3colors.m3outlineVariant.g,
                        Appearance.m3colors.m3outlineVariant.b, 0.5)
              Behavior on color {
                  animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
              }

              Text {
                  id: themeChipText
                  anchors.centerIn: parent
                  text: themeChip.modelData
                  color: themeChip.isActive ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                  font.pixelSize: Appearance.font.pixelSize.small
                  font.weight: themeChip.isActive ? Font.Medium : Font.Normal
              }

              MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { GlobalStates.activeTheme = themeChip.modelData; root.applyTheme(themeChip.modelData) }
              }
          }
      }
  }
  ```

  Key changes vs the original:
  - `Flow` → `GridLayout` with `columns: 3`
  - `spacing: 6` → `columnSpacing: 6` + `rowSpacing: 6`
  - Removed `width: themeChipText.implicitWidth + 22` from the chip
  - Added `Layout.fillWidth: true` to the chip (makes all 3 chips per row equal width)

- [ ] **Step 3: Verify QtQuick.Layouts is imported**

  ```bash
  grep "QtQuick.Layouts" /home/donnie/projects/ii-lacuna/dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml
  ```
  Expected: `import QtQuick.Layouts` — it's already present (line 4). No change needed.

- [ ] **Step 4: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml
  git commit -m "feat: replace theme Flow with 3-column GridLayout"
  ```

---

### Task 5: Smoke test

- [ ] **Step 1: Reload the Quickshell config**

  ```bash
  qs ipc call shell reload
  ```
  Or if that's not available, kill and restart:
  ```bash
  pkill -f quickshell; sleep 1; quickshell &
  ```

- [ ] **Step 2: Open the bar applets panel and verify**

  - Theme chips appear in a 3-column grid (not a wrapping flow)
  - Clicking a non-Matugen theme (e.g., "Dracula") applies it — terminal, GTK, bar colors update
  - The active chip is highlighted in primary color

- [ ] **Step 3: Verify persistence**

  - With a non-Matugen theme active, reload Quickshell again (same command as Step 1)
  - Open bar applets — the previously selected chip should still be highlighted
  - The theme should have been re-applied automatically on startup

- [ ] **Step 4: Verify Matugen still works**

  - Click the "Matugen" chip — colors should regenerate from the current wallpaper
  - Reload Quickshell — since Matugen skips `Component.onCompleted`, `MaterialThemeLoader`'s file watcher handles color restoration silently (no flash)

- [ ] **Step 5: Check states.json has the activeTheme key**

  ```bash
  cat ~/.local/state/quickshell/states.json | python3 -m json.tool | grep activeTheme
  ```
  Expected output:
  ```
  "activeTheme": "Dracula",
  ```
  (or whatever theme you selected)
