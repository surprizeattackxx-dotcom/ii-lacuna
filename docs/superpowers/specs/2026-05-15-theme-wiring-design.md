# Theme Wiring Design

**Date:** 2026-05-15  
**Status:** Approved

## Goal

Wire up the theme picker in `BarAppletsOverlay.qml` so that the active theme:
- persists across shell restarts (written to `states.json`)
- is accessible globally to all components via `GlobalStates`
- auto-reapplies on startup (non-Matugen themes only)
- displays in a tighter 3-column grid instead of a wrapping Flow

---

## Architecture

### 1. Persistent.states — source of truth

Add `property string activeTheme: "Matugen"` to the `JsonAdapter` in `Persistent.qml`.

- Lives alongside existing persisted state (sidebar tabs, overlay positions, etc.)
- Automatically serialized to `states.json` via the existing `FileView`/`JsonAdapter` mechanism
- Default value `"Matugen"` matches current behavior for new installs

**File:** `dots/.config/quickshell/ii/modules/common/Persistent.qml`  
**Location in JsonAdapter:** top-level property, alongside `followNightLight`

### 2. GlobalStates — convenience handle

Add a two-way binding in `GlobalStates.qml`:

```qml
property string activeTheme: Persistent.states.activeTheme
onActiveThemeChanged: Persistent.states.activeTheme = activeTheme
```

- Any component reads `GlobalStates.activeTheme`
- Setting `GlobalStates.activeTheme = x` writes through to Persistent automatically
- No duplicate state — Persistent remains the single source of truth

**File:** `dots/.config/quickshell/ii/GlobalStates.qml`

### 3. BarAppletsOverlay — wiring changes

Three changes:

1. **Remove** `property string activeTheme: "Matugen"` from `root`
2. **Update chip click handler** from `root.activeTheme = x` → `GlobalStates.activeTheme = x`
3. **Add startup apply** — re-apply persisted theme when shell starts, skipping Matugen since `MaterialThemeLoader` already handles it via file watcher:

```qml
Component.onCompleted: {
    if (GlobalStates.activeTheme !== "Matugen")
        applyTheme(GlobalStates.activeTheme)
}
```

The `applyTheme()` function itself is unchanged.

**File:** `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml`

### 4. Grid layout

Replace the `Flow` theme chip container with `GridLayout` (3 equal-width columns):

```qml
GridLayout {
    Layout.fillWidth: true
    columns: 3
    columnSpacing: 6
    rowSpacing: 6

    Repeater {
        model: root.themeNames
        delegate: Rectangle {
            // same styling as current chips
            // remove explicit width, add:
            Layout.fillWidth: true
        }
    }
}
```

Chips become uniform width per row. With 31 themes, this produces ~11 rows — compact and scannable.

**File:** `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml`

---

## Data Flow

```
User clicks chip
  → GlobalStates.activeTheme = "Dracula"
  → Persistent.states.activeTheme = "Dracula"  (written to states.json)
  → applyTheme("Dracula")
      → bash apply_custom_theme.sh dracula.json
          → colors.json updated
          → MaterialThemeLoader watches colors.json → QML colors update
          → GTK4, Kitty, Rofi, Hyprland, KDE updated

Shell restart
  → Persistent loads states.json → activeTheme = "Dracula"
  → GlobalStates.activeTheme = "Dracula"
  → Component.onCompleted: applyTheme("Dracula")  [skipped if "Matugen"]
```

---

## Edge Cases

- **Matugen on startup**: skipped — `MaterialThemeLoader` file watcher handles it already. Re-running `switchwall.sh --noswitch` would be redundant and could cause a color flash.
- **New install / missing states.json**: defaults to `"Matugen"`, identical to current behavior.
- **Unknown theme name in states.json**: `applyTheme()` would attempt to load a non-existent JSON path. Not adding validation — same behavior as current code.

---

## Files Changed

| File | Change |
|------|--------|
| `modules/common/Persistent.qml` | Add `property string activeTheme: "Matugen"` to JsonAdapter |
| `GlobalStates.qml` | Add two-way binding property `activeTheme` |
| `modules/ii/bar/BarAppletsOverlay.qml` | Remove local property, update click handler, add `Component.onCompleted`, replace `Flow` with `GridLayout` |
