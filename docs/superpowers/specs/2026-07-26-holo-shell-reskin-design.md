# Holographic Glass Shell Reskin — Foundation + Bar

**Date:** 2026-07-26
**Status:** Approved

## Goal

Give the shell a "holographic HUD glass" look and feel: frosted-glass panels with soft glow blobs as the calm base, layered with angular cut-corner outlines, glowing borders, and active motion (idle scanline sweep + flicker pulse on state changes). Ship it as a new selectable color scheme plus one reusable panel component, and prove it out on the Bar first. Other modules (Dock, OSD, Panels, Toast, Tooltip, LockScreen, Cheatsheet, GameLauncher, DesktopWidgets, AudioSpectrum) reuse the same foundation in later fast-follow passes — not part of this plan.

Visual direction locked in during brainstorming: Sci-Fi HUD + Aurora Glass combined, cyan/violet accent pair, "active HUD" motion level (not calm-ambient).

## Non-Goals

- Rolling `HoloPanel` out to modules beyond the Bar in this pass.
- Building a new settings UI for motion intensity — motion follows the existing `PowerProfileService.noctaliaPerformanceMode` toggle, no new setting.
- Changing the underlying M3 token structure in `Style.qml`/`Color.qml` — this scheme works entirely within the existing `mPrimary`/`mSecondary`/`mSurface`/etc. role system.

## Architecture

Three additive pieces. Nothing existing is rewired.

### 1. New color scheme: `Aether`

New file `Assets/ColorScheme/Aether/Aether.json`, matching the existing one-file-per-scheme layout (see `Assets/ColorScheme/Rosepine/Rosepine.json`) — a single JSON file containing both `dark` and `light` objects, each with `mPrimary`, `mOnPrimary`, `mSecondary`, `mOnSecondary`, `mTertiary`, `mOnTertiary`, `mError`, `mOnError`, `mSurface`, `mOnSurface`, `mSurfaceVariant`, `mOnSurfaceVariant`, `mOutline`, `mShadow`, `mHover`, `mOnHover`, plus the `terminal` block.

Palette (dark variant — the one this pass targets; light variant gets a same-hue lighter derivative so the scheme doesn't break if the user is in light mode, but isn't the design focus here):
- `mSurface` / `mSurfaceVariant`: `#050710` (near-black glass base)
- `mPrimary`: `#3ad6ff` (cyan — matches the accepted mockup)
- `mSecondary`: `#7c4dff` (violet — matches the accepted mockup)
- `mOutline`: `#3ad6ff` at reduced alpha, used for the glow border

Picked up automatically by `ColorSchemeService` / the existing scheme picker — no service changes needed.

### 2. New shared widget: `HoloPanel.qml`

Lives in `Widgets/`, next to other shared widgets. Replaces the current rounded-pill background container. Responsibilities:
- Renders a glass panel (blurred/translucent fill using existing opacity tokens from `Style.qml`) with angular cut corners instead of the current uniform rounded rect
- Glowing border using the active scheme's `mOutline`/`mPrimary`
- Exposes the two shader effects (below) as optional overlays, each independently toggleable
- Falls back to a plain glowing-border glass panel (no shaders) if a shader fails to compile or `noctaliaPerformanceMode` is on

Consumed by the Bar's section containers in this pass.

### 3. Two shaders in `Shaders/frag`

- **`Shaders/frag/holoScanline.frag`** — continuous idle-loop shader, subtle horizontal sweep across the panel. Always-on when enabled (ambient motion, not tied to an event).
- **`Shaders/frag/holoFlicker.frag`** — short one-shot brightness/glitch pulse, triggered on state-change signals (volume change, workspace switch, notification fired, etc.) rather than looping continuously.

Both follow the existing `Shaders/frag` + `Shaders/qsb` build pattern already used elsewhere in the codebase. Both gated behind `PowerProfileService.noctaliaPerformanceMode` the same way `Style.qml`'s `effectivePanelOpacity`/`effectiveBarOpacity` already are — when performance mode is on, `HoloPanel` skips shader loading entirely rather than instantiating and hiding them.

## Data Flow

```
User picks "Aether" in scheme picker
  → ColorSchemeService loads Aether.json, picks the dark variant (existing mechanism, unchanged)
      → Color.qml exposes mPrimary/mSecondary/mSurface/mOutline as usual
          → HoloPanel reads those tokens like any other widget would
              → Bar renders with cyan/violet glass + glow, no code path changes elsewhere

Idle:
  → HoloPanel's scanline shader runs continuously (if enabled + not in performance mode)

State change (e.g. volume changed):
  → existing service/signal fires (no new signals invented)
      → HoloPanel subscribes, triggers one flicker-pulse shader shot

noctaliaPerformanceMode toggled on:
  → HoloPanel does not instantiate either shader; renders plain glass+glow panel only
```

## Error Handling

- **Shader fails to compile** (driver/GPU quirk): `HoloPanel` catches this and renders the plain glass+glow panel with no scanline/flicker — the Bar keeps working, it just loses the motion effects. Never crashes the shell.
- **Aether JSON malformed**: falls through to whatever fallback `ColorSchemeService` already uses for a bad scheme file (existing behavior, unchanged) — not a new failure mode introduced by this work.
- **Performance mode toggled mid-session**: shaders unload/reload following whatever pattern `effectivePanelOpacity`/`effectiveBarOpacity` already use for reacting to the same flag.

## Testing / Validation

No unit-test story here — this is UI look-and-feel. Validation is manual:
1. Launch the shell with Aether selected, confirm Bar renders glass+glow+angular corners correctly
2. Toggle `noctaliaPerformanceMode` on/off, confirm shaders disable/enable and panel still looks correct without them
3. Trigger a few state changes (volume, workspace switch) and confirm the flicker pulse fires once per event, not continuously
4. Switch to a different existing scheme (e.g. Nord) and confirm the Bar falls back to a plain (non-glow) panel with no errors
5. Confirm Aether shows up correctly named in the existing scheme picker UI

## Files Changed / Added

| File | Change |
|------|--------|
| `Assets/ColorScheme/Aether/Aether.json` | New — holo palette (dark + light variants in one file), following existing scheme schema |
| `Widgets/HoloPanel.qml` | New — shared glass+glow+angular-corner panel component |
| `Shaders/frag/holoScanline.frag` | New — idle scanline sweep shader |
| `Shaders/frag/holoFlicker.frag` | New — one-shot flicker/glitch pulse shader |
| Bar module section container(s) | Modified — swap current background container for `HoloPanel` |

## Deferred (explicitly out of scope for this pass)

Rolling `HoloPanel` + the Aether scheme out to Dock, Panels, OSD, Toast, Tooltip, LockScreen, Cheatsheet, GameLauncher, DesktopWidgets, and the AudioSpectrum widget — same foundation, no new design work needed, just sequential swap-in passes once the Bar proves the look out.
