# Quickshell + Chrome Live Theming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Quickshell's bar/widgets follow the active theme color palette, and automatically apply a matching Chrome theme to google-chrome-beta live while it runs.

**Architecture:** Add 13 Catppuccin alias keys to 10 theme JSONs so `MaterialThemeLoader` populates `Appearance.colors` correctly (zero QML changes). For Chrome: generate an unpacked Chrome extension on each theme switch and reload it live via CDP (`Extensions.loadUnpacked`) with a wrapper script that starts Chrome with `--remote-debugging-port=9222`.

**Tech Stack:** Python 3, bash, JSON, Chrome DevTools Protocol (CDP), `websockets` PyPI package

All paths are relative to `/home/donnie/projects/ii-lacuna/`.

---

## Files

| File | Change |
|------|--------|
| `dots/.config/quickshell/ii/defaults/themes/*.json` (10 files) | Add 13 Catppuccin alias keys |
| `dots/.config/quickshell/ii/scripts/colors/generate_chrome_theme.py` | New — map M3 keys → Chrome color slots, write manifest.json |
| `dots/.config/quickshell/ii/scripts/colors/reload_chrome_theme.py` | New — CDP reload via websockets |
| `dots/.local/share/ii-lacuna-chrome-theme/manifest.json` | New — placeholder Chrome extension with stable key |
| `dots/.local/bin/google-chrome-beta-themed` | New — wrapper script adding CDP + extension flags |
| `dots/.local/share/applications/google-chrome-beta.desktop` | New — local override pointing to wrapper |
| `dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh` | Add Chrome generate + reload calls at bottom |

---

### Task 1: Add Catppuccin alias keys to 10 theme JSONs

**Files:**
- Modify: `dots/.config/quickshell/ii/defaults/themes/mocha.json`
- Modify: `dots/.config/quickshell/ii/defaults/themes/frappe.json`
- Modify: `dots/.config/quickshell/ii/defaults/themes/latte.json`
- Modify: `dots/.config/quickshell/ii/defaults/themes/macchiato.json`
- Modify: `dots/.config/quickshell/ii/defaults/themes/dracula.json`
- Modify: `dots/.config/quickshell/ii/defaults/themes/nord.json`
- Modify: `dots/.config/quickshell/ii/defaults/themes/rose_pine.json`
- Modify: `dots/.config/quickshell/ii/defaults/themes/gruvbox.json`
- Modify: `dots/.config/quickshell/ii/defaults/themes/glass.json`
- Modify: `dots/.config/quickshell/ii/defaults/themes/kanagawa.json`

**Context:** `Appearance.colors` in the Quickshell config uses Catppuccin-named keys (`mauve`, `base`, `text`, etc.) to look up colors from `Appearance.m3colors`. Theme JSONs only have M3 keys. Adding 13 alias keys to each JSON makes `MaterialThemeLoader` populate those Catppuccin names when it reads the JSON. No QML changes needed.

- [ ] **Step 1: Write the alias injection script**

  Create a temporary script to patch all 10 JSONs. Run from the repo root:

  ```bash
  cd /home/donnie/projects/ii-lacuna
  python3 - << 'EOF'
  import json
  from pathlib import Path

  ALIAS_MAP = {
      "mauve":    "primary",
      "blue":     "secondary",
      "teal":     "tertiary",
      "red":      "error",
      "base":     "background",
      "mantle":   "surface_container_low",
      "text":     "on_background",
      "subtext0": "on_surface_variant",
      "overlay0": "outline",
      "overlay1": "outline_variant",
      "surface0": "surface_container",
      "surface1": "surface_container_high",
      "surface2": "surface_container_highest",
  }

  THEMES = [
      "mocha", "frappe", "latte", "macchiato",
      "dracula", "nord", "rose_pine", "gruvbox", "glass", "kanagawa",
  ]

  base = Path("dots/.config/quickshell/ii/defaults/themes")
  for name in THEMES:
      p = base / f"{name}.json"
      data = json.loads(p.read_text())
      for alias, src in ALIAS_MAP.items():
          if src in data:
              data[alias] = data[src]
      p.write_text(json.dumps(data, indent=2) + "\n")
      print(f"patched {name}.json")
  EOF
  ```

  Expected output:
  ```
  patched mocha.json
  patched frappe.json
  patched latte.json
  patched macchiato.json
  patched dracula.json
  patched nord.json
  patched rose_pine.json
  patched gruvbox.json
  patched glass.json
  patched kanagawa.json
  ```

- [ ] **Step 2: Verify aliases are present in one file**

  ```bash
  jq '{mauve, blue, teal, red, base, mantle, text, subtext0, overlay0, overlay1, surface0, surface1, surface2}' \
      dots/.config/quickshell/ii/defaults/themes/dracula.json
  ```

  Expected output (13 keys, all with hex values):
  ```json
  {
    "mauve": "#bd93f9",
    "blue": "#50fa7b",
    "teal": "#8be9fd",
    "red": "#ff5555",
    "base": "#282a36",
    "mantle": "#1f2029",
    "text": "#f8f8f2",
    "subtext0": "#d6d6cf",
    "overlay0": "#ffb86c",
    "overlay1": "#f1fa8c",
    "surface0": "#282a36",
    "surface1": "#44475a",
    "surface2": "#5a5c70"
  }
  ```

- [ ] **Step 3: Verify all 10 files have the `mauve` key**

  ```bash
  for f in dots/.config/quickshell/ii/defaults/themes/{mocha,frappe,latte,macchiato,dracula,nord,rose_pine,gruvbox,glass,kanagawa}.json; do
      echo -n "$f: "; jq -r '.mauve' "$f"
  done
  ```

  Expected: 10 lines each showing a hex color string (not `null`).

- [ ] **Step 4: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.config/quickshell/ii/defaults/themes/
  git commit -m "feat: add Catppuccin alias keys to 10 theme JSONs for Quickshell shell theming"
  ```

---

### Task 2: Create Chrome extension placeholder manifest

**Files:**
- Create: `dots/.local/share/ii-lacuna-chrome-theme/manifest.json`

**Context:** The Chrome extension needs a stable `"key"` field so Chrome assigns the same extension ID every time it's reloaded. The key is a base64-encoded DER RSA public key. The manifest is a placeholder — `generate_chrome_theme.py` overwrites it with real colors on every theme switch. Chrome loads this once at startup via `--load-extension`, then we replace it via CDP.

- [ ] **Step 1: Create the extension directory and placeholder manifest**

  ```bash
  mkdir -p /home/donnie/projects/ii-lacuna/dots/.local/share/ii-lacuna-chrome-theme
  ```

  Create `dots/.local/share/ii-lacuna-chrome-theme/manifest.json`:

  ```json
  {
    "manifest_version": 3,
    "name": "ii-lacuna Active Theme",
    "version": "1.0",
    "key": "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo2W5eySXff2kmRcAS8EXMqYj0/rRQc4ww8mMIwudja0OAw/w1HGB/3gK+8KKqDZX9QzyhYfTp7oRqA7Y+8lhfb7cVBC1AFjIp6pyVbG3xQVFNKDXMa4jzxmzLd6l7uEfVJmOjoLWD1OCtsblyG3Wx27qAXV9jRltu+tK4HgPDvzkUcwgy7ef9kCEdxPSWjWe/ayfNmkXT0+rGwDeZEXoCk6fyO6X7/m51fZwIFdE82HQuly+eOltU4rAE7bZjkUvDxDLpedyVyeonWDjJWYRAnOoEm82z4flgyacMxiJnM86R7IaDXea+l5fl0xrUDJPolHuaeBzs9E+WNJ0JYHC2wIDAQAB",
    "theme": {
      "colors": {
        "frame": [30, 30, 46],
        "frame_inactive": [24, 24, 37],
        "toolbar": [30, 30, 46],
        "tab_text": [205, 214, 244],
        "tab_background_text": [166, 173, 200],
        "ntp_background": [30, 30, 46],
        "ntp_text": [205, 214, 244],
        "ntp_link": [203, 166, 247],
        "button_background": [49, 50, 68]
      }
    }
  }
  ```

- [ ] **Step 2: Verify it's valid JSON**

  ```bash
  python3 -m json.tool dots/.local/share/ii-lacuna-chrome-theme/manifest.json > /dev/null && echo "valid JSON"
  ```

  Expected: `valid JSON`

- [ ] **Step 3: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.local/share/ii-lacuna-chrome-theme/manifest.json
  git commit -m "feat: add Chrome extension placeholder manifest with stable key"
  ```

---

### Task 3: Create `generate_chrome_theme.py`

**Files:**
- Create: `dots/.config/quickshell/ii/scripts/colors/generate_chrome_theme.py`

**Context:** This script reads a theme JSON and writes a Chrome extension `manifest.json` mapping M3 color keys to Chrome theme color slots. It uses only Python stdlib. Called from `apply_custom_theme.sh` on every theme switch.

- [ ] **Step 1: Create the script**

  Create `dots/.config/quickshell/ii/scripts/colors/generate_chrome_theme.py`:

  ```python
  #!/usr/bin/env python3
  """Generate a Chrome extension manifest.json from a theme JSON file.

  Usage: generate_chrome_theme.py <theme.json> <output_dir>
  """
  import json
  import sys
  from pathlib import Path

  STABLE_KEY = (
      "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo2W5eySXff2kmRcAS8EX"
      "MqYj0/rRQc4ww8mMIwudja0OAw/w1HGB/3gK+8KKqDZX9QzyhYfTp7oRqA7Y+8l"
      "hfb7cVBC1AFjIp6pyVbG3xQVFNKDXMa4jzxmzLd6l7uEfVJmOjoLWD1OCtsblyG3"
      "Wx27qAXV9jRltu+tK4HgPDvzkUcwgy7ef9kCEdxPSWjWe/ayfNmkXT0+rGwDeZEX"
      "oCk6fyO6X7/m51fZwIFdE82HQuly+eOltU4rAE7bZjkUvDxDLpedyVyeonWDjJWY"
      "RAnOoEm82z4flgyacMxiJnM86R7IaDXea+l5fl0xrUDJPolHuaeBzs9E+WNJ0JYHC"
      "2wIDAQAB"
  )

  # Maps Chrome color slot → M3 key in theme JSON
  SLOT_MAP = {
      "frame":               "surface",
      "frame_inactive":      "surface_dim",
      "toolbar":             "surface_container",
      "tab_text":            "on_background",
      "tab_background_text": "on_surface_variant",
      "ntp_background":      "background",
      "ntp_text":            "on_background",
      "ntp_link":            "primary",
      "button_background":   "surface_container_high",
  }


  def hex_to_rgb(hex_color: str) -> list[int]:
      h = hex_color.lstrip("#")
      return [int(h[i:i+2], 16) for i in (0, 2, 4)]


  def main() -> None:
      if len(sys.argv) != 3:
          print(f"Usage: {sys.argv[0]} <theme.json> <output_dir>", file=sys.stderr)
          sys.exit(1)

      theme_path = Path(sys.argv[1])
      output_dir = Path(sys.argv[2])
      output_dir.mkdir(parents=True, exist_ok=True)

      theme = json.loads(theme_path.read_text())

      colors = {}
      for slot, key in SLOT_MAP.items():
          hex_val = theme.get(key)
          if hex_val and hex_val.startswith("#"):
              colors[slot] = hex_to_rgb(hex_val)

      manifest = {
          "manifest_version": 3,
          "name": "ii-lacuna Active Theme",
          "version": "1.0",
          "key": STABLE_KEY,
          "theme": {"colors": colors},
      }

      (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


  if __name__ == "__main__":
      main()
  ```

- [ ] **Step 2: Make it executable**

  ```bash
  chmod +x dots/.config/quickshell/ii/scripts/colors/generate_chrome_theme.py
  ```

- [ ] **Step 3: Test it against dracula.json**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  python3 dots/.config/quickshell/ii/scripts/colors/generate_chrome_theme.py \
      dots/.config/quickshell/ii/defaults/themes/dracula.json \
      /tmp/test-chrome-theme
  jq '.theme.colors' /tmp/test-chrome-theme/manifest.json
  ```

  Expected output (all values are RGB arrays, 9 slots):
  ```json
  {
    "frame": [40, 42, 54],
    "frame_inactive": [31, 32, 41],
    "toolbar": [40, 42, 54],
    "tab_text": [248, 248, 242],
    "tab_background_text": [214, 214, 207],
    "ntp_background": [40, 42, 54],
    "ntp_text": [248, 248, 242],
    "ntp_link": [189, 147, 249],
    "button_background": [68, 71, 90]
  }
  ```

- [ ] **Step 4: Verify the `key` field is preserved**

  ```bash
  jq -r '.key' /tmp/test-chrome-theme/manifest.json | head -c 20
  ```

  Expected: starts with `MIIBIjANBgkqhkiG9w0B`

- [ ] **Step 5: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.config/quickshell/ii/scripts/colors/generate_chrome_theme.py
  git commit -m "feat: add generate_chrome_theme.py to map theme colors to Chrome extension"
  ```

---

### Task 4: Create `reload_chrome_theme.py` and install `websockets`

**Files:**
- Create: `dots/.config/quickshell/ii/scripts/colors/reload_chrome_theme.py`

**Context:** This script connects to Chrome's DevTools Protocol (CDP) WebSocket and calls `Extensions.loadUnpacked` with the theme directory path. Chrome reinstalls the extension from disk, applying the new colors live. The `websockets` package must be installed into the quickshell venv (`~/.local/state/quickshell/.venv`). If Chrome isn't running or the CDP port isn't open, the script exits silently.

- [ ] **Step 1: Install `websockets` into the quickshell venv**

  ```bash
  /home/donnie/.local/state/quickshell/.venv/bin/pip install websockets
  ```

  Expected: `Successfully installed websockets-...` (or `Requirement already satisfied`)

- [ ] **Step 2: Create the script**

  Create `dots/.config/quickshell/ii/scripts/colors/reload_chrome_theme.py`:

  ```python
  #!/usr/bin/env python3
  """Reload ii-lacuna Chrome theme via Chrome DevTools Protocol.

  Usage: reload_chrome_theme.py <theme_dir>

  Exits silently if Chrome is not running or CDP is unavailable.
  Requires: websockets (pip install websockets)
  """
  import asyncio
  import json
  import sys
  import urllib.request
  from pathlib import Path


  async def reload(theme_dir: str) -> None:
      import websockets

      # Get CDP WebSocket URL from Chrome's debug endpoint
      try:
          with urllib.request.urlopen("http://localhost:9222/json/version", timeout=2) as r:
              ws_url = json.loads(r.read())["webSocketDebuggerUrl"]
      except Exception:
          return  # Chrome not running or --remote-debugging-port not set

      try:
          async with websockets.connect(ws_url, open_timeout=3) as ws:
              await ws.send(json.dumps({
                  "id": 1,
                  "method": "Extensions.loadUnpacked",
                  "params": {"path": str(Path(theme_dir).resolve())},
              }))
              await asyncio.wait_for(ws.recv(), timeout=3)
      except Exception:
          return  # Chrome closed, timed out, or CDP rejected — ignore


  if __name__ == "__main__":
      if len(sys.argv) != 2:
          print(f"Usage: {sys.argv[0]} <theme_dir>", file=sys.stderr)
          sys.exit(1)
      asyncio.run(reload(sys.argv[1]))
  ```

- [ ] **Step 3: Make it executable**

  ```bash
  chmod +x dots/.config/quickshell/ii/scripts/colors/reload_chrome_theme.py
  ```

- [ ] **Step 4: Test it with Chrome NOT running (should exit silently)**

  ```bash
  time /home/donnie/.local/state/quickshell/.venv/bin/python3 \
      dots/.config/quickshell/ii/scripts/colors/reload_chrome_theme.py \
      /tmp/test-chrome-theme
  echo "exit code: $?"
  ```

  Expected: completes in ~2 seconds (timeout), prints nothing, exit code 0.

- [ ] **Step 5: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.config/quickshell/ii/scripts/colors/reload_chrome_theme.py
  git commit -m "feat: add reload_chrome_theme.py for CDP-based live Chrome theme reload"
  ```

---

### Task 5: Create Chrome wrapper script and `.desktop` override

**Files:**
- Create: `dots/.local/bin/google-chrome-beta-themed`
- Create: `dots/.local/share/applications/google-chrome-beta.desktop`

**Context:** Chrome must be launched with `--remote-debugging-port=9222` and `--load-extension=<theme-dir>` for CDP reloads to work. `.desktop` Exec lines don't expand shell variables, so a wrapper script handles the flags. The local `.desktop` file at `~/.local/share/applications/` takes precedence over the system one at `/usr/share/applications/`.

- [ ] **Step 1: Create the wrapper script**

  ```bash
  mkdir -p /home/donnie/projects/ii-lacuna/dots/.local/bin
  ```

  Create `dots/.local/bin/google-chrome-beta-themed`:

  ```bash
  #!/usr/bin/env bash
  exec /usr/bin/google-chrome-beta \
      --remote-debugging-port=9222 \
      --load-extension="$HOME/.local/share/ii-lacuna-chrome-theme" \
      "$@"
  ```

- [ ] **Step 2: Make the wrapper executable**

  ```bash
  chmod +x dots/.local/bin/google-chrome-beta-themed
  ```

- [ ] **Step 3: Create the `.desktop` override**

  ```bash
  mkdir -p /home/donnie/projects/ii-lacuna/dots/.local/share/applications
  ```

  Create `dots/.local/share/applications/google-chrome-beta.desktop`:

  ```ini
  [Desktop Entry]
  Version=1.0
  Name=Google Chrome (beta)
  GenericName=Web Browser
  Comment=Access the Internet
  StartupWMClass=Google-chrome-beta
  Exec=/home/donnie/.local/bin/google-chrome-beta-themed %U
  StartupNotify=true
  Terminal=false
  Icon=google-chrome-beta
  Type=Application
  Categories=Network;WebBrowser;
  MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
  Actions=new-window;new-private-window;

  [Desktop Action new-window]
  Name=New Window
  StartupWMClass=Google-chrome-beta
  Exec=/home/donnie/.local/bin/google-chrome-beta-themed

  [Desktop Action new-private-window]
  Name=New Incognito Window
  StartupWMClass=Google-chrome-beta
  Exec=/home/donnie/.local/bin/google-chrome-beta-themed --incognito
  ```

- [ ] **Step 4: Verify the wrapper parses correctly**

  ```bash
  bash -n dots/.local/bin/google-chrome-beta-themed && echo "syntax ok"
  ```

  Expected: `syntax ok`

- [ ] **Step 5: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.local/bin/google-chrome-beta-themed \
          dots/.local/share/applications/google-chrome-beta.desktop
  git commit -m "feat: add Chrome wrapper script and .desktop override for CDP theming"
  ```

---

### Task 6: Update `apply_custom_theme.sh` to generate and reload Chrome theme

**Files:**
- Modify: `dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh`

**Context:** The script already sets `SCRIPT_DIR` and `VENV_PYTHON` near the top. Add Chrome generation + background reload at the very end of the script, after the KDE block. The `if [[ -d "$CHROME_THEME_DIR" ]]` guard means the Chrome feature is silently skipped if the extension directory hasn't been stowed yet.

- [ ] **Step 1: Add the Chrome block at the end of the script**

  The current file ends with:
  ```bash
  elif [[ -n "${KDE_SCHEME[$THEME_NAME]+_}" ]]; then
      plasma-apply-colorscheme "${KDE_SCHEME[$THEME_NAME]}"
  fi
  ```

  Append after that closing `fi` (the last line of the file):

  ```bash

  # Generate and reload Chrome theme
  CHROME_THEME_DIR="$HOME/.local/share/ii-lacuna-chrome-theme"
  if [[ -d "$CHROME_THEME_DIR" ]]; then
      python3 "$SCRIPT_DIR/generate_chrome_theme.py" "$THEME_FILE" "$CHROME_THEME_DIR" 2>/dev/null
      "$VENV_PYTHON" "$SCRIPT_DIR/reload_chrome_theme.py" "$CHROME_THEME_DIR" &
  fi
  ```

- [ ] **Step 2: Verify the script has no syntax errors**

  ```bash
  bash -n dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh && echo "syntax ok"
  ```

  Expected: `syntax ok`

- [ ] **Step 3: Verify the Chrome block appears at the end**

  ```bash
  tail -8 dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh
  ```

  Expected:
  ```bash
  # Generate and reload Chrome theme
  CHROME_THEME_DIR="$HOME/.local/share/ii-lacuna-chrome-theme"
  if [[ -d "$CHROME_THEME_DIR" ]]; then
      python3 "$SCRIPT_DIR/generate_chrome_theme.py" "$THEME_FILE" "$CHROME_THEME_DIR" 2>/dev/null
      "$VENV_PYTHON" "$SCRIPT_DIR/reload_chrome_theme.py" "$CHROME_THEME_DIR" &
  fi
  ```

- [ ] **Step 4: Commit**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  git add dots/.config/quickshell/ii/scripts/colors/apply_custom_theme.sh
  git commit -m "feat: generate and live-reload Chrome theme on every theme switch"
  ```

---

### Task 7: Stow new files and smoke test

**Context:** `stow` synlinks the `dots/` directory tree into `$HOME`. New files in `dots/.local/` and `dots/.config/` need to be stowed to take effect. The quickshell venv Python is the one that has `websockets`.

- [ ] **Step 1: Stow the new dotfiles**

  ```bash
  cd /home/donnie/projects/ii-lacuna
  stow --target="$HOME" dots
  ```

  Expected: no errors. If stow reports conflicts on existing files, check if you need `--adopt` or manually back up the conflicting file first.

- [ ] **Step 2: Verify stow created the symlinks**

  ```bash
  ls -la ~/.local/share/ii-lacuna-chrome-theme/manifest.json
  ls -la ~/.local/bin/google-chrome-beta-themed
  ls -la ~/.local/share/applications/google-chrome-beta.desktop
  ```

  Expected: all three show symlinks pointing into `~/projects/ii-lacuna/dots/`.

- [ ] **Step 3: Test Quickshell shell theming**

  Reload Quickshell:
  ```bash
  qs ipc call shell reload
  ```
  (If that fails: `pkill -f quickshell; sleep 1; quickshell &`)

  Open the bar applets panel, click the **Dracula** chip. The bar, sidebars, and notification backgrounds should update to Dracula's purple palette. The active chip should be highlighted in primary color (#bd93f9).

- [ ] **Step 4: Test that the Chrome wrapper launches Chrome correctly**

  Close Chrome if running. Launch via the wrapper:
  ```bash
  ~/.local/bin/google-chrome-beta-themed &
  ```

  Verify Chrome starts and the debug port is open:
  ```bash
  sleep 3 && curl -s http://localhost:9222/json/version | python3 -m json.tool | grep '"Browser"'
  ```

  Expected: `"Browser": "Chrome/..."` (or similar — confirms CDP is accessible)

- [ ] **Step 5: Test Chrome live theming**

  With Chrome running (from Step 4 or opened via the `.desktop` entry), switch to a theme in Quickshell (e.g., click **Nord**). Within 1-2 seconds Chrome's tab bar, toolbar, and New Tab page background should update to Nord's blue palette.

  If you click a chip and nothing happens in Chrome:
  1. Check `~/.local/share/ii-lacuna-chrome-theme/manifest.json` updated: `jq '.theme.colors.frame' ~/.local/share/ii-lacuna-chrome-theme/manifest.json`
  2. Check CDP is reachable: `curl -s http://localhost:9222/json/version`
  3. Run reload manually: `/home/donnie/.local/state/quickshell/.venv/bin/python3 ~/.config/quickshell/ii/scripts/colors/reload_chrome_theme.py ~/.local/share/ii-lacuna-chrome-theme`

- [ ] **Step 6: Test Matugen still works**

  Click the **Matugen** chip. Shell colors should regenerate from the wallpaper (no flash, `MaterialThemeLoader`'s file watcher handles it). Chrome gets a Matugen-generated theme too (since `apply_custom_theme.sh` runs `generate_chrome_theme.py` for all themes — but Matugen goes through `switchwall.sh`, not this script, so Chrome won't update for Matugen. This is expected behavior per the spec.)

  > **Note:** Matugen bypasses `apply_custom_theme.sh` entirely (it calls `switchwall.sh --noswitch` instead). Chrome will keep whatever theme was last applied by a non-Matugen switch. This is by design.
