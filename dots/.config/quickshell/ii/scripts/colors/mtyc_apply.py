#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.expanduser("~/.local/state/quickshell/.venv/lib/python3.12/site-packages"))

from kde_material_you_colors.utils.m3_scheme_utils import themeFromSourceColor, argbFromHex
from kde_material_you_colors.utils import plasma_utils
from kde_material_you_colors.utils.color_utils import hexFromArgb
from kde_material_you_colors.schemeconfigs import ThemeConfig

color = sys.argv[1].lstrip("#")
mode = sys.argv[2] if len(sys.argv) > 2 else "dark"

seed = argbFromHex(color)
theme = themeFromSourceColor(seed)
best = [hexFromArgb(seed)]

material_colors = {
    "best": best,
    "seed": {"index": 0, "color": hexFromArgb(seed)},
    "schemes": {"light": theme["schemes"]["light"], "dark": theme["schemes"]["dark"]},
    "palettes": theme["palettes"],
    "custom": theme["customColors"],
}

schemes = ThemeConfig(material_colors, None,
    toolbar_opacity=100, toolbar_opacity_dark=100)
plasma_utils.make_scheme(schemes)
plasma_utils.apply_color_schemes(mode == "light")
print(f"Applied KDE color scheme from #{color}")
