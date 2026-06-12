#!/usr/bin/env python3
import json, os, sys

SRC = os.path.expanduser("~/.local/state/quickshell/user/generated/colors.json")
DST = os.path.expanduser("~/.config/hypr/scripts/quickshell/qs_colors.json")

MAP = {
    "base": "surface_container_lowest",
    "mantle": "surface_container_low",
    "crust": "surface",
    "text": "on_surface",
    "subtext0": "on_surface_variant",
    "subtext1": "outline",
    "surface0": "surface_container",
    "surface1": "surface_container_high",
    "surface2": "surface_container_highest",
    "overlay0": "inverse_surface",
    "overlay1": "inverse_surface",
    "overlay2": "inverse_surface",
    "blue": "primary",
    "sapphire": "primary_container",
    "peach": "tertiary",
    "green": "secondary",
    "red": "error",
    "mauve": "primary",
    "pink": "tertiary_container",
    "yellow": "secondary_container",
    "maroon": "error_container",
    "teal": "secondary",
}

try:
    src = json.load(open(SRC))
except Exception as e:
    sys.exit(f"gen_qs_colors: {e}")

out = {k: src[v] for k, v in MAP.items() if v in src}
json.dump(out, open(DST, "w"), indent=2)
