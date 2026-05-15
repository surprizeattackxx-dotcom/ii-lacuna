# Quickshell + Chrome Live Theming Design

**Date:** 2026-05-15
**Status:** Approved

## Goal

Two connected features:

1. **Quickshell shell theming** — Make the bar, sidebars, widgets, and notifications visually follow the active theme when a chip is clicked. Currently `Appearance.colors` uses Catppuccin-named keys that theme JSONs don't provide.

2. **Chrome live theming** — Automatically apply a matching generated Chrome theme to `google-chrome-beta` on every theme switch, updating while Chrome is running (no restart required).

---

## Feature 1: Quickshell Shell Theming

### Problem

`MaterialThemeLoader.qml` watches `~/.local/state/quickshell/user/generated/colors.json` and populates `Appearance.m3colors` with M3-prefixed keys (e.g. `m3Primary`, `m3Background`). But `Appearance.colors` — the object the shell UI actually renders with — uses Catppuccin-named keys:

```
base, blue, mantle, mauve, overlay0, overlay1,
red, subtext0, surface0, surface1, surface2, teal, text
```

Theme JSONs only contain M3 keys (`primary`, `background`, `surface_container`, etc.), so the Catppuccin aliases are never set, and the shell stays stuck on whatever Matugen last generated.

### Solution

Add 13 Catppuccin alias keys to each of the 10 non-Matugen theme JSONs. The aliases map Catppuccin semantic names to the M3 values that best match their role. `MaterialThemeLoader` already handles any key it finds in the JSON, so no QML changes are needed.

### Alias Mapping

| Catppuccin key | M3 source key |
|----------------|---------------|
| `mauve` | `primary` |
| `blue` | `secondary` |
| `teal` | `tertiary` |
| `red` | `error` |
| `base` | `background` |
| `mantle` | `surface_container_low` |
| `text` | `on_background` |
| `subtext0` | `on_surface_variant` |
| `overlay0` | `outline` |
| `overlay1` | `outline_variant` |
| `surface0` | `surface_container` |
| `surface1` | `surface_container_high` |
| `surface2` | `surface_container_highest` |

### Theme JSONs to Update (10 files)

All in `dots/.config/quickshell/ii/defaults/themes/`:

- `mocha.json`
- `frappe.json`
- `latte.json`
- `macchiato.json`
- `dracula.json`
- `nord.json`
- `rose_pine.json`
- `gruvbox.json`
- `glass.json`
- `kanagawa.json`

Matugen is dynamic — no JSON, skip.

### Data Flow

```
User clicks "Dracula" chip
  → apply_custom_theme.sh dracula.json
      → cp dracula.json → colors.json
          → MaterialThemeLoader sees file change
              → applyColors() reads all keys including aliases
                  → Appearance.m3colors.mauve = dracula primary color
                  → Appearance.m3colors.base = dracula background color
                  → ... (all 13 aliases)
                      → Appearance.colors.colPrimary = m3colors.mauve  ✓
                      → bar, sidebar, widgets update
```

---

## Feature 2: Chrome Live Theming

### Approach

Generate an unpacked Chrome extension on each theme switch and reload it into a running Chrome instance via the Chrome DevTools Protocol (CDP). This requires Chrome to be launched with `--remote-debugging-port=9222` and `--load-extension=<path>`.

### Files

| File | Description |
|------|-------------|
| `dots/.config/quickshell/ii/scripts/colors/generate_chrome_theme.py` | Reads theme JSON, maps M3 keys to Chrome color slots, writes manifest.json |
| `dots/.config/quickshell/ii/scripts/colors/reload_chrome_theme.py` | Connects to CDP, sends `Extensions.loadUnpacked`, exits silently if Chrome isn't running |
| `dots/.local/share/ii-lacuna-chrome-theme/manifest.json` | Bundled placeholder extension with stable `"key"` for consistent extension ID |
| `dots/.local/share/applications/google-chrome-beta.desktop` | Overrides system `.desktop` to launch via wrapper |
| `dots/.local/bin/google-chrome-beta-themed` | Wrapper script adding `--remote-debugging-port=9222 --load-extension=<theme-path>` |

### Chrome Color Slot Mapping

| Chrome slot | M3 source key |
|-------------|---------------|
| `frame` | `surface` |
| `frame_inactive` | `surface_dim` |
| `toolbar` | `surface_container` |
| `tab_text` | `on_background` |
| `tab_background_text` | `on_surface_variant` |
| `ntp_background` | `background` |
| `ntp_text` | `on_background` |
| `ntp_link` | `primary` |
| `button_background` | `surface_container_high` |

### Stable Extension ID

The placeholder `manifest.json` includes a `"key"` field (base64 RSA public key). Chrome uses this to assign a deterministic extension ID, so reloading via `Extensions.loadUnpacked` updates the existing theme rather than installing a duplicate.

### Chrome Wrapper and Desktop Entry

`.desktop` Exec lines don't expand `$HOME` or shell variables, so a wrapper script at `~/.local/bin/google-chrome-beta-themed` handles the flags:

```bash
#!/usr/bin/env bash
exec google-chrome-beta \
    --remote-debugging-port=9222 \
    --load-extension="$HOME/.local/share/ii-lacuna-chrome-theme" \
    "$@"
```

`dots/.local/share/applications/google-chrome-beta.desktop` overrides the system entry (stowed to `~/.local/share/applications/`) with:

```
Exec=/home/donnie/.local/bin/google-chrome-beta-themed %U
```

### `apply_custom_theme.sh` changes

At the bottom of the script, after all existing color application steps, add:

```bash
# Generate and reload Chrome theme
SCRIPT_DIR="$(dirname "$0")"
CHROME_THEME_DIR="$HOME/.local/share/ii-lacuna-chrome-theme"
"$VENV_DIR/bin/python" "$SCRIPT_DIR/generate_chrome_theme.py" "$THEME_FILE" "$CHROME_THEME_DIR"
"$VENV_DIR/bin/python" "$SCRIPT_DIR/reload_chrome_theme.py" "$CHROME_THEME_DIR" &
```

The `&` runs the CDP reload in the background so theme switching isn't blocked by Chrome's response time.

### CDP Reload Behavior

`reload_chrome_theme.py`:
1. GETs `http://localhost:9222/json/version` to get the WebSocket debugger URL
2. Connects via websocket
3. Sends `{"method": "Extensions.loadUnpacked", "params": {"path": "<abs-theme-dir>"}}`
4. If connection refused / port not open / Chrome not running → exits silently
5. Uses `websockets` Python library (already in quickshell venv)

### Data Flow

```
User clicks "Nord" chip
  → apply_custom_theme.sh nord.json Nord
      → colors.json updated → Quickshell colors update
      → KDE plasma-apply-colorscheme "Nordic"
      → generate_chrome_theme.py nord.json → manifest.json written
      → reload_chrome_theme.py (background)
          → CDP Extensions.loadUnpacked
              → Chrome reloads extension → browser colors update live
```

---

## Files Changed

| File | Change |
|------|--------|
| `dots/.config/quickshell/ii/defaults/themes/*.json` (10 files) | Add 13 Catppuccin alias keys |
| `dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh` | Add Chrome generate + reload calls |
| `dots/.config/quickshell/ii/scripts/colors/generate_chrome_theme.py` | New — generate Chrome theme manifest |
| `dots/.config/quickshell/ii/scripts/colors/reload_chrome_theme.py` | New — CDP reload script |
| `dots/.local/share/ii-lacuna-chrome-theme/manifest.json` | New — placeholder extension with stable key |
| `dots/.local/share/applications/google-chrome-beta.desktop` | New — `.desktop` override |
| `dots/.local/bin/google-chrome-beta-themed` | New — Chrome wrapper script |

---

## Edge Cases

- **Chrome not running**: `reload_chrome_theme.py` catches `ConnectionRefusedError` and exits silently — no error, no hang.
- **Matugen theme**: JSON aliases aren't needed (Matugen populates all M3 keys dynamically). Chrome theme still generated from the current `colors.json` if Matugen is active.
- **First launch before theme switch**: The placeholder `manifest.json` is blank-ish (all white/default colors). Chrome loads it on startup. First theme switch overwrites it and reloads.
- **`$VENV_DIR` availability in `apply_custom_theme.sh`**: `VENV_DIR` is already defined in the script for the KDE material-you block — reuse it.
- **`websockets` not installed**: Add install step to `generate_chrome_theme.py` prologue, or document as a one-time setup in the plan.
