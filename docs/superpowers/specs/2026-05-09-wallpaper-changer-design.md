# Wallpaper Changer Redesign

**Date:** 2026-05-09  
**Status:** Approved

## Summary

Redesign `WallpaperChangerContent.qml` to fix a silent bug, use the existing `WallpaperThumb` component, and add proper navigation, labels, and confirm/cancel UX. Layout stays a centered carousel — cinematic feel, one wallpaper in focus at a time.

## Bug Fixed

`PathView.itemIndex` is not a valid QML attached property. The current delegate uses it to compute `dist` for scale/opacity tiers, so all tiers silently evaluate to `NaN` — the depth effect is broken. Fix: replace `PathView` with `ListView` and use `index - currentIndex` directly.

## Layout

- **Carousel track:** 5 items visible (2 far, 2 near, 1 center). Scale tiers: center 1.35×, near 0.90×, far 0.65×. Opacity tiers: 1.0 / 0.7 / 0.35.
- **Nav buttons:** `‹` / `›` round buttons flanking the carousel.
- **Name label:** Filename/folder name of the center item displayed below the track.
- **Action row:** Cancel + Apply buttons below the label.
- **Keyboard hints:** Small hint strip at the bottom (← → scroll ↵ Esc).

## Navigation

| Input | Action |
|-------|--------|
| `←` / `→` arrow keys | Move to prev/next item |
| Mouse scroll wheel | Move to prev/next item |
| `‹` / `›` buttons | Move to prev/next item |
| Single click | Select + live preview (apply without saving) |
| Double-click | Apply + close |
| Enter / `↵` | Apply + close |
| Escape | Revert to original wallpaper + close |
| Cancel button | Revert to original wallpaper + close |
| Apply button | Apply + close |

## Components

### `WallpaperChanger.qml`
No changes. Already correct.

### `WallpaperChangerContent.qml`
Full rewrite of the view layer. Key changes:
- Replace `PathView` + arc `Path` with horizontal `ListView`
  - `snapMode: ListView.SnapToItem`
  - `preferredHighlightBegin` / `preferredHighlightEnd` to keep selected item centered
  - `highlightRangeMode: ListView.StrictlyEnforceRange`
- Delegates use `WallpaperThumb` instead of inline `Rectangle` + `Image`
- `Keys.onLeftPressed` / `Keys.onRightPressed` for arrow navigation
- `WheelHandler` on root for scroll navigation
- `Keys.onReturnPressed` → `confirmSelected()`
- `Keys.onEscapePressed` → revert + close
- Prev/Next `Rectangle` buttons flanking the `ListView`
- `Text` label below showing center item name (filename or folder basename)
- Cancel + Apply button row at the bottom

### `WallpaperThumb.qml`
Minor change only: trigger the `revealing` circle-out animation when the item becomes the center/selected item (i.e., when `selected` transitions from false to true).

## Data Flow

1. **Single click** → `doPreview()` — calls `Wallpapers.apply(..., false)`, no save
2. **Double-click / Apply / Enter** → `confirmSelected()` — calls `Wallpapers.apply(..., true)`, closes changer
3. **Cancel / Escape** → restore `originalWallpaper` via `Wallpapers.apply(originalWallpaper, ..., false)`, close changer

## Out of Scope

- Search / filter
- Multi-monitor per-wallpaper selection
- Drag to reorder
