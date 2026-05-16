#!/usr/bin/env python3
"""Generate a Chrome extension manifest.json from a theme JSON file.

Usage: generate_chrome_theme.py <theme.json> <output_dir>
"""
import json
import sys
import time
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

    # Use timestamp as version so Chrome sees a change and reloads the theme
    version = time.strftime("%Y.%m%d.%H%M")

    # Delete stale Cached Theme.pak so Chrome re-reads updated colors
    pak = output_dir / "Cached Theme.pak"
    if pak.exists():
        pak.unlink()

    manifest = {
        "manifest_version": 3,
        "name": "ii-lacuna Active Theme",
        "version": version,
        "key": STABLE_KEY,
        "theme": {"colors": colors},
    }

    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
