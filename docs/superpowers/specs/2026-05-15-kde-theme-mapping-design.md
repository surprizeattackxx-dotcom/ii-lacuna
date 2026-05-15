# KDE Theme Mapping Design

**Date:** 2026-05-15
**Status:** Approved

## Goal

Wire each non-Matugen theme chip to a specific KDE Plasma color scheme so that selecting a theme updates everything KDE manages (Dolphin, KDE apps, window decorations, titlebars) with the matching palette. Matugen keeps its existing dynamic `kde-material-you-colors` behavior. Trim `themeNames` to only the 11 themes that have official KDE color scheme sources.

---

## Theme List

| Theme | KDE Color Scheme Source |
|-------|------------------------|
| Matugen | dynamic — `kde-material-you-colors` (unchanged) |
| Mocha | [catppuccin/kde](https://github.com/catppuccin/kde) releases |
| Frappe | [catppuccin/kde](https://github.com/catppuccin/kde) releases |
| Latte | [catppuccin/kde](https://github.com/catppuccin/kde) releases |
| Macchiato | [catppuccin/kde](https://github.com/catppuccin/kde) releases |
| Dracula | [igorpadua/Dracula-kde](https://github.com/igorpadua/Dracula-kde) |
| Nord | [EliverLara/Nordic-kde](https://github.com/EliverLara/Nordic-kde) |
| Rose_pine | [kelpwave/Rose-pine-for-KDE](https://github.com/kelpwave/Rose-pine-for-KDE) |
| Gruvbox | already installed — `/usr/share/color-schemes/GruvboxColors.colors` |
| Glass | already installed — `~/.local/share/color-schemes/kvGlass.colors` |
| Kanagawa | [KDE Store p/2117860](https://store.kde.org/p/2117860) |

All themes removed from the previous list of 31 (Apple, Angel, Ayu, Cobalt2, Cursor, Flexoki, Github, Material_ocean, Matrix, Mercury, Open_code, Orng, Osaka_jade, Sakura, Samurai, Synthwave84, Vercel, Vesper, Zen_burn, Zen_garden) had no official KDE color scheme equivalents.

---

## Architecture

### 1. Bundled `.colors` files

Downloaded `.colors` files live at `dots/.local/share/color-schemes/` in the ii-lacuna repo. On dotfile install/stow they land in `~/.local/share/color-schemes/` where KDE picks them up. Gruvbox and Glass are already system/user installed and do not need to be bundled.

Files to bundle:
- `CatppuccinMocha.colors` (from catppuccin/kde releases)
- `CatppuccinFrappe.colors` (from catppuccin/kde releases)
- `CatppuccinLatte.colors` (from catppuccin/kde releases)
- `CatppuccinMacchiato.colors` (from catppuccin/kde releases)
- `Dracula.colors` (from igorpadua/Dracula-kde)
- `Nordic.colors` (from EliverLara/Nordic-kde)
- `RosePine.colors` (from kelpwave/Rose-pine-for-KDE)
- `Kanagawa.colors` (from KDE Store download)

The exact `Name=` value inside each `.colors` file determines the string passed to `plasma-apply-colorscheme`. This is read during implementation.

### 2. `applyTheme()` QML change

`BarAppletsOverlay.qml:140` — add `themeName` as `$2` to the script command:

```qml
themeApplyProc.command = ["bash", Directories.applyCustomThemeScriptPath, path, themeName];
```

`$1` = theme JSON path (unchanged), `$2` = theme name string (new).

### 3. `apply_custom_theme.sh` changes

Two changes at the bottom of the script, replacing the existing `kde-material-you-colors` block:

**Add mapping at top of script (after `THEME_FILE="$1"`):**
```bash
THEME_NAME="${2:-}"

declare -A KDE_SCHEME=(
    [Mocha]="Catppuccin Mocha"
    [Frappe]="Catppuccin Frappe"
    [Latte]="Catppuccin Latte"
    [Macchiato]="Catppuccin Macchiato"
    [Dracula]="Dracula"
    [Nord]="Nordic"
    [Rose_pine]="Rose Pine"
    [Gruvbox]="Gruvbox Colors"
    [Glass]="kvGlass"
    [Kanagawa]="Kanagawa"
)
```

Note: the string values must exactly match the `Name=` field in each `.colors` file. These are confirmed during implementation by inspecting each downloaded file.

**Replace KDE block at bottom:**
```bash
# Theme KDE apps via color scheme or dynamic kde-material-you-colors (Matugen only)
if [[ "$THEME_NAME" == "Matugen" || -z "$THEME_NAME" ]]; then
    COLOR_TXT="$STATE_DIR/user/generated/color.txt"
    printf '%s' "${PRIMARY#\#}" > "$COLOR_TXT"

    VENV_DIR="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}"
    KDE_BIN="$VENV_DIR/bin/kde-material-you-colors"
    if [[ -x "$KDE_BIN" ]]; then
        [[ "$MODE" == "dark" ]] && KDE_MODE_FLAG="-d" || KDE_MODE_FLAG="-l"
        source "$VENV_DIR/bin/activate" 2>/dev/null
        "$KDE_BIN" "$KDE_MODE_FLAG" --color "${PRIMARY#\#}" -sv 5 &
        deactivate 2>/dev/null
    fi
elif [[ -n "${KDE_SCHEME[$THEME_NAME]+_}" ]]; then
    plasma-apply-colorscheme "${KDE_SCHEME[$THEME_NAME]}"
fi
```

The `|| -z "$THEME_NAME"` guard preserves backward compatibility if the script is ever called without `$2`.

---

## Data Flow

```
User clicks "Dracula"
  → GlobalStates.activeTheme = "Dracula"
  → applyTheme("Dracula")
      → apply_custom_theme.sh /path/dracula.json Dracula
          → colors.json updated → terminal/GTK/Rofi/Hyprland update
          → plasma-apply-colorscheme "Dracula"
              → KDE apps, Dolphin, window decorations update

User clicks "Matugen"
  → applyTheme("Matugen")
      → switchwall.sh --noswitch --mode dark  (unchanged path)

Shell startup with saved theme "Nord"
  → Persistent.ready → applyTheme("Nord")
      → apply_custom_theme.sh /path/nord.json Nord
          → colors.json + plasma-apply-colorscheme "Nordic"
```

---

## Files Changed

| File | Change |
|------|--------|
| `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml` | Trim `themeNames` to 11; add `themeName` as `$2` to script command |
| `dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh` | Add `KDE_SCHEME` map; replace KDE block with conditional |
| `dots/.local/share/color-schemes/*.colors` | New — 8 bundled color scheme files |

---

## Edge Cases

- **`$2` missing** (script called directly or from old code path): falls through to `kde-material-you-colors` — safe fallback.
- **Unknown theme name in map**: the `elif [[ -n "${KDE_SCHEME[$THEME_NAME]+_}" ]]` guard skips silently — KDE keeps its current scheme.
- **Catppuccin `Name=` field**: catppuccin/kde uses accented characters in some flavor names (e.g. "Frappé"). The map must use the exact string from the file — confirmed during implementation.
- **Gruvbox / Glass already installed**: no `.colors` file bundled for these. Their scheme names are read from the existing installed files during implementation.
