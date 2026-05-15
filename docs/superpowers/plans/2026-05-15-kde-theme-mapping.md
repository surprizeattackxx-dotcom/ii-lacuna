# KDE Theme Mapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire each non-Matugen theme chip to a specific KDE Plasma color scheme so that selecting a theme updates KDE apps, Dolphin, and window decorations with the matching palette.

**Architecture:** Bundle 8 `.colors` files in the repo under `dots/.local/share/color-schemes/` (stowed to `~/.local/share/color-schemes/`). Trim `themeNames` to the 11 themes that have official KDE equivalents. Pass `themeName` as `$2` to `apply_custom_theme.sh`. Inside the script, a `declare -A KDE_SCHEME` map routes each theme name to the correct `plasma-apply-colorscheme` call, while Matugen keeps its existing `kde-material-you-colors` path.

**Tech Stack:** bash, QML (Quickshell), `plasma-apply-colorscheme` CLI

---

## Files

| File | Change |
|------|--------|
| `dots/.local/share/color-schemes/CatppuccinMochaMauve.colors` | New — bundled from catppuccin/kde |
| `dots/.local/share/color-schemes/CatppuccinFrappeMauve.colors` | New — bundled from catppuccin/kde |
| `dots/.local/share/color-schemes/CatppuccinLatteMauve.colors` | New — bundled from catppuccin/kde |
| `dots/.local/share/color-schemes/CatppuccinMacchiatoMauve.colors` | New — bundled from catppuccin/kde |
| `dots/.local/share/color-schemes/Dracula-kde.colors` | New — bundled from igorpadua/Dracula-kde |
| `dots/.local/share/color-schemes/Nordic.colors` | New — bundled from EliverLara/Nordic-kde |
| `dots/.local/share/color-schemes/RosePineMoon.colors` | New — bundled from kelpwave/Rose-pine-for-KDE |
| `dots/.local/share/color-schemes/KanagawaWave.colors` | New — bundled from EClaesson/plasma_kanagawa |
| `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml` | Trim `themeNames` to 11; add `themeName` as `$2` to script command |
| `dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh` | Add `KDE_SCHEME` map; replace KDE block with conditional |

Note: `GruvboxColors.colors` (`Name=GruvboxColors`) and `kvGlass.colors` (`Name=KvGlass`) are already installed at `~/.local/share/color-schemes/` on the live system and do **not** need to be bundled.

---

### Task 1: Bundle the Catppuccin `.colors` files

**Files:**
- Create: `dots/.local/share/color-schemes/CatppuccinMochaMauve.colors`
- Create: `dots/.local/share/color-schemes/CatppuccinFrappeMauve.colors`
- Create: `dots/.local/share/color-schemes/CatppuccinLatteMauve.colors`
- Create: `dots/.local/share/color-schemes/CatppuccinMacchiatoMauve.colors`

- [ ] **Step 1: Create the color-schemes directory in the repo**

  ```bash
  mkdir -p /home/donnie/projects/ii-lacuna/dots/.local/share/color-schemes
  ```

- [ ] **Step 2: Download and extract the four Catppuccin flavor tarballs**

  Each tarball extracts to a differently-named directory. Run these one at a time:

  ```bash
  cd /tmp

  # Mocha
  curl -L -o mocha.tar.gz https://github.com/catppuccin/kde/releases/download/v0.2.6/Mocha-color-schemes.tar.gz
  tar xzf mocha.tar.gz
  ls  # will show Mocha-color-schemes/ or similar

  # Frappe (note: British spelling in extracted dir name)
  curl -L -o frappe.tar.gz https://github.com/catppuccin/kde/releases/download/v0.2.6/Frappe-color-schemes.tar.gz
  tar xzf frappe.tar.gz
  ls

  # Latte
  curl -L -o latte.tar.gz https://github.com/catppuccin/kde/releases/download/v0.2.6/Latte-color-schemes.tar.gz
  tar xzf latte.tar.gz
  ls

  # Macchiato
  curl -L -o macchiato.tar.gz https://github.com/catppuccin/kde/releases/download/v0.2.6/Macchiato-color-schemes.tar.gz
  tar xzf macchiato.tar.gz
  ls
  ```

- [ ] **Step 3: Find and copy the Mauve variant for each flavor**

  After extraction, find the Mauve `.colors` file in each extracted directory and copy it to the repo. The exact subdirectory names vary — use `find` to locate them:

  ```bash
  DEST=/home/donnie/projects/ii-lacuna/dots/.local/share/color-schemes

  find /tmp -name "*Mauve*" -name "*.colors" 2>/dev/null
  # Copy each found file — example paths (actual may differ slightly):
  # Mocha:
  cp /tmp/Mocha-color-schemes/CatppuccinMochaMauve.colors "$DEST/"
  # Frappe (British spelling in dir name):
  cp /tmp/Frappe-Colour-Schemes/CatppuccinFrappeMauve.colors "$DEST/"
  # Latte:
  cp /tmp/Latte-color-schemes/CatppuccinLatteMauve.colors "$DEST/"
  # Macchiato:
  cp /tmp/Macchiato-color-schemes/CatppuccinMacchiatoMauve.colors "$DEST/"
  ```

- [ ] **Step 4: Verify the `Name=` field in each file**

  ```bash
  DEST=/home/donnie/projects/ii-lacuna/dots/.local/share/color-schemes
  for f in CatppuccinMochaMauve CatppuccinFrappeMauve CatppuccinLatteMauve CatppuccinMacchiatoMauve; do
      echo -n "$f: "; grep "^Name=" "$DEST/$f.colors"
  done
  ```

  Expected output:
  ```
  CatppuccinMochaMauve: Name=Catppuccin Mocha Mauve
  CatppuccinFrappeMauve: Name=Catppuccin Frappe Mauve
  CatppuccinLatteMauve: Name=Catppuccin Latte Mauve
  CatppuccinMacchiatoMauve: Name=Catppuccin Macchiato Mauve
  ```

- [ ] **Step 5: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.local/share/color-schemes/CatppuccinMochaMauve.colors \
          dots/.local/share/color-schemes/CatppuccinFrappeMauve.colors \
          dots/.local/share/color-schemes/CatppuccinLatteMauve.colors \
          dots/.local/share/color-schemes/CatppuccinMacchiatoMauve.colors
  git commit -m "feat: bundle Catppuccin Mauve KDE color schemes"
  ```

---

### Task 2: Bundle the remaining `.colors` files (Dracula, Nord, Rose Pine Moon, Kanagawa Wave)

**Files:**
- Create: `dots/.local/share/color-schemes/Dracula-kde.colors`
- Create: `dots/.local/share/color-schemes/Nordic.colors`
- Create: `dots/.local/share/color-schemes/RosePineMoon.colors`
- Create: `dots/.local/share/color-schemes/KanagawaWave.colors`

- [ ] **Step 1: Download Dracula**

  ```bash
  DEST=/home/donnie/projects/ii-lacuna/dots/.local/share/color-schemes
  curl -L -o "$DEST/Dracula-kde.colors" \
    https://raw.githubusercontent.com/igorpadua/Dracula-kde/master/color-schemes/Dracula-kde.colors
  grep "^Name=" "$DEST/Dracula-kde.colors"
  ```

  Expected: `Name=Dracula-kde`

- [ ] **Step 2: Download Nordic**

  The Nordic-kde repo has a single file named `colors` (no extension) — save it with the `.colors` extension:

  ```bash
  DEST=/home/donnie/projects/ii-lacuna/dots/.local/share/color-schemes
  curl -L -o "$DEST/Nordic.colors" \
    https://raw.githubusercontent.com/EliverLara/Nordic-kde/master/colors
  grep "^Name=" "$DEST/Nordic.colors"
  ```

  Expected: `Name=Nordic`

- [ ] **Step 3: Download Rose Pine Moon**

  The path has a URL-encoded space (`Rose%20Pine%20Moon`):

  ```bash
  DEST=/home/donnie/projects/ii-lacuna/dots/.local/share/color-schemes
  curl -L -o "$DEST/RosePineMoon.colors" \
    "https://raw.githubusercontent.com/kelpwave/Rose-pine-for-KDE/main/Rose%20Pine%20Moon/colorschemes/RosePineMoon.colors"
  grep "^Name=" "$DEST/RosePineMoon.colors"
  ```

  Expected: `Name=Rose Pine Moon`

- [ ] **Step 4: Download Kanagawa Wave**

  ```bash
  DEST=/home/donnie/projects/ii-lacuna/dots/.local/share/color-schemes
  curl -L -o "$DEST/KanagawaWave.colors" \
    https://raw.githubusercontent.com/EClaesson/plasma_kanagawa/main/KanagawaWave.colors
  grep "^Name=" "$DEST/KanagawaWave.colors"
  ```

  Expected: `Name=Kanagawa Wave`

- [ ] **Step 5: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.local/share/color-schemes/Dracula-kde.colors \
          dots/.local/share/color-schemes/Nordic.colors \
          dots/.local/share/color-schemes/RosePineMoon.colors \
          dots/.local/share/color-schemes/KanagawaWave.colors
  git commit -m "feat: bundle Dracula, Nordic, Rose Pine Moon, Kanagawa KDE color schemes"
  ```

---

### Task 3: Trim `themeNames` and pass `themeName` as `$2` in `applyTheme()`

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml:81` (themeNames)
- Modify: `dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml:141` (applyTheme)

- [ ] **Step 1: Replace `themeNames` with the trimmed 11-theme list**

  Find this line (line 81):
  ```qml
  readonly property var themeNames: ["Mocha", "Glass", "Matugen", "Gruvbox", "Apple", "Nord", "Angel", "Ayu", "Cobalt2", "Cursor", "Dracula", "Flexoki", "Frappe", "Github", "Kanagawa", "Latte", "Macchiato", "Material_ocean", "Matrix", "Mercury", "Open_code", "Orng", "Osaka_jade", "Rose_pine", "Sakura", "Samurai", "Synthwave84", "Vercel", "Vesper", "Zen_burn", "Zen_garden"]
  ```

  Replace with:
  ```qml
  readonly property var themeNames: ["Matugen", "Mocha", "Frappe", "Latte", "Macchiato", "Dracula", "Nord", "Rose_pine", "Gruvbox", "Glass", "Kanagawa"]
  ```

- [ ] **Step 2: Add `themeName` as `$2` to the script command**

  Find this line (line 141):
  ```qml
              themeApplyProc.command = ["bash", Directories.applyCustomThemeScriptPath, path];
  ```

  Replace with:
  ```qml
              themeApplyProc.command = ["bash", Directories.applyCustomThemeScriptPath, path, themeName];
  ```

- [ ] **Step 3: Verify no reference to removed theme names remains**

  ```bash
  grep -n "Apple\|Angel\|Ayu\|Cobalt2\|Cursor\|Flexoki\|Github\|Material_ocean\|Matrix\|Mercury\|Open_code\|Orng\|Osaka_jade\|Sakura\|Samurai\|Synthwave84\|Vercel\|Vesper\|Zen_burn\|Zen_garden" \
    /home/donnie/projects/ii-lacuna/dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml
  ```

  Expected: no output (all removed themes gone).

- [ ] **Step 4: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.config/quickshell/ii/modules/ii/bar/BarAppletsOverlay.qml
  git commit -m "feat: trim themeNames to 11 KDE-mapped themes; pass themeName as \$2"
  ```

---

### Task 4: Update `apply_custom_theme.sh` — add KDE_SCHEME map and conditional

**Files:**
- Modify: `dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh`

- [ ] **Step 1: Add `THEME_NAME` and `KDE_SCHEME` immediately after the `THEME_FILE` line**

  Find this line (line 4):
  ```bash
  THEME_FILE="$1"
  ```

  Replace with:
  ```bash
  THEME_FILE="$1"
  THEME_NAME="${2:-}"

  declare -A KDE_SCHEME=(
      [Mocha]="Catppuccin Mocha Mauve"
      [Frappe]="Catppuccin Frappe Mauve"
      [Latte]="Catppuccin Latte Mauve"
      [Macchiato]="Catppuccin Macchiato Mauve"
      [Dracula]="Dracula-kde"
      [Nord]="Nordic"
      [Rose_pine]="Rose Pine Moon"
      [Gruvbox]="GruvboxColors"
      [Glass]="KvGlass"
      [Kanagawa]="Kanagawa Wave"
  )
  ```

- [ ] **Step 2: Replace the KDE block at the bottom of the script**

  Find this block (last 13 lines of the file):
  ```bash
  # Theme Qt/KDE apps (Dolphin, etc.) via kde-material-you-colors
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
  ```

  Replace with:
  ```bash
  # Theme Qt/KDE apps via color scheme (non-Matugen) or dynamic kde-material-you-colors (Matugen)
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

- [ ] **Step 3: Verify the script is valid bash**

  ```bash
  bash -n /home/donnie/projects/ii-lacuna/dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh
  ```

  Expected: no output (no syntax errors).

- [ ] **Step 4: Verify THEME_NAME appears in the right places**

  ```bash
  grep -n "THEME_NAME\|KDE_SCHEME\|plasma-apply" \
    /home/donnie/projects/ii-lacuna/dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh
  ```

  Expected lines (approximate):
  - Line 5: `THEME_NAME="${2:-}"`
  - Lines 7-19: `declare -A KDE_SCHEME=(...)`
  - Near bottom: `if [[ "$THEME_NAME" == "Matugen" || -z "$THEME_NAME" ]];`
  - Near bottom: `elif [[ -n "${KDE_SCHEME[$THEME_NAME]+_}" ]];`
  - Near bottom: `plasma-apply-colorscheme "${KDE_SCHEME[$THEME_NAME]}"`

- [ ] **Step 5: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh
  git commit -m "feat: add KDE_SCHEME map; gate kde-material-you-colors to Matugen only"
  ```

---

### Task 5: Smoke test

- [ ] **Step 1: Install the bundled `.colors` files to the live system**

  The stow setup handles this normally, but for a quick test symlink or copy:

  ```bash
  cp /home/donnie/projects/ii-lacuna/dots/.local/share/color-schemes/*.colors \
     ~/.local/share/color-schemes/
  ```

- [ ] **Step 2: Verify `plasma-apply-colorscheme` can find each scheme**

  ```bash
  plasma-apply-colorscheme --list-schemes 2>/dev/null | grep -E "Catppuccin|Dracula|Nordic|Rose Pine|Gruvbox|KvGlass|Kanagawa"
  ```

  Expected: all 10 scheme names appear in the list.

- [ ] **Step 3: Reload Quickshell**

  ```bash
  qs ipc call shell reload
  ```

  Or if unavailable:
  ```bash
  pkill -f quickshell; sleep 1; quickshell &
  ```

- [ ] **Step 4: Verify theme chip grid now shows 11 chips (not 31)**

  Open bar applets panel. Count the chips — should be exactly 11 in a 3-column grid (4 rows with 3, then 1 remaining chip).

- [ ] **Step 5: Test a non-Matugen theme**

  Click "Dracula" in the bar applets panel.

  Expected:
  - Bar/terminal/GTK colors update (existing behavior)
  - KDE title bar, Dolphin, and KDE app colors update to Dracula palette

  Verify KDE scheme changed:
  ```bash
  plasma-apply-colorscheme --list-schemes 2>/dev/null | grep -i current
  # Or check kdedefaults:
  kreadconfig5 --group "General" --key "ColorScheme" --file kdeglobals
  ```

  Expected output includes `Dracula-kde`.

- [ ] **Step 6: Test Matugen still works**

  Click "Matugen". Colors should regenerate from the current wallpaper via `kde-material-you-colors`. No error in the terminal.

- [ ] **Step 7: Test persistence of KDE scheme across reload**

  With Dracula active, reload Quickshell (same command as Step 3). After reload, KDE scheme should auto-reapply to Dracula via `Component.onCompleted → applyTheme("Dracula") → plasma-apply-colorscheme "Dracula-kde"`.
