#!/usr/bin/env python3
"""
hve2lua — convert a Hyprland Visual Editor overlay (hyprlang) into Lua (hl.* API).

The HVE plugin only knows how to emit legacy hyprlang and load it via
`source = overlay.conf` in hyprland.conf — which a Lua-based Hyprland never reads.
This translates that overlay into the equivalent hl.curve / hl.animation / hl.config
calls so it works under the 0.55 Lua parser.

Usage: hve2lua.py [overlay.conf] [colors.conf]   (defaults to the standard HVE paths)
Prints the generated Lua to stdout.
"""
import os, re, sys

HOME = os.path.expanduser("~")
OVERLAY = sys.argv[1] if len(sys.argv) > 1 else f"{HOME}/.cache/noctalia/HVE/overlay.conf"
COLORS  = sys.argv[2] if len(sys.argv) > 2 else f"{HOME}/.config/hypr/noctalia/noctalia-colors.conf"


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""


def to_hypr_hex(token):
    """Resolve a color token (rgb()/rgba()/0x.. ) to Hyprland 0xAARRGGBB."""
    t = token.strip()
    m = re.fullmatch(r"rgba\(\s*([0-9a-fA-F]{8})\s*\)", t)
    if m:  # rgba hex is RRGGBBAA -> 0xAARRGGBB
        h = m.group(1)
        return f"0x{h[6:8]}{h[0:6]}".lower()
    m = re.fullmatch(r"rgb\(\s*([0-9a-fA-F]{6})\s*\)", t)
    if m:
        return f"0xff{m.group(1)}".lower()
    m = re.fullmatch(r"rgba\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)\s*\)", t)
    if m:
        r, g, b = (int(m.group(i)) for i in (1, 2, 3))
        a = round(float(m.group(4)) * 255)
        return f"0x{a:02x}{r:02x}{g:02x}{b:02x}"
    m = re.fullmatch(r"rgb\(\s*(\d+),\s*(\d+),\s*(\d+)\s*\)", t)
    if m:
        r, g, b = (int(m.group(i)) for i in (1, 2, 3))
        return f"0xff{r:02x}{g:02x}{b:02x}"
    if re.fullmatch(r"0x[0-9a-fA-F]{8}", t):
        return t.lower()
    if re.fullmatch(r"[0-9a-fA-F]{8}", t):
        return f"0x{t}".lower()
    return None


def build_color_map(text):
    """Parse `$name = rgb(..)` definitions into name -> 0xAARRGGBB."""
    cmap = {}
    for name, val in re.findall(r"\$(\w+)\s*=\s*(rgba?\([^)]*\)|0x[0-9a-fA-F]+)", text):
        hx = to_hypr_hex(val)
        if hx:
            cmap[name] = hx
    return cmap


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def resolve_color(token, cmap):
    t = token.strip()
    if t.startswith("$"):
        return cmap.get(t[1:])
    return to_hypr_hex(t)


def parse_border_value(value, cmap):
    """`$primary $surface 90deg` -> ({colors=[..], angle=90})  or single color string."""
    parts = value.split()
    angle = None
    colors = []
    for p in parts:
        m = re.fullmatch(r"(\d+)deg", p)
        if m:
            angle = int(m.group(1))
            continue
        c = resolve_color(p, cmap)
        if c:
            colors.append(c)
    if not colors:
        return None
    if len(colors) == 1 and angle is None:
        return lua_str(colors[0])
    inner = ", ".join(lua_str(c) for c in colors)
    if angle is not None:
        return "{ colors = { %s }, angle = %d }" % (inner, angle)
    return "{ colors = { %s } }" % inner


def main():
    cmap = build_color_map(read(COLORS) + "\n" + read(OVERLAY))
    raw = read(OVERLAY)
    # Strip comments; drop `source =` lines (colors handled via the map).
    lines = []
    for ln in raw.splitlines():
        ln = re.sub(r"#.*$", "", ln)
        ln = re.sub(r"//.*$", "", ln)
        ln = ln.strip()
        if not ln or ln.lower().startswith("source"):
            continue
        lines.append(ln)
    # Flatten `cat { a=b c=d }` blocks: track current section prefix.
    flat = []          # list of (section, statement)
    section = None
    for ln in lines:
        mopen = re.match(r"^(\w+)\s*\{$", ln)
        if mopen:
            section = mopen.group(1)
            continue
        if ln == "}":
            section = None
            continue
        # inline block: `general { col.active_border = x }`
        minline = re.match(r"^(\w+)\s*\{(.*)\}$", ln)
        if minline:
            sec, body = minline.group(1), minline.group(2)
            for part in re.split(r";", body):
                part = part.strip()
                if part:
                    flat.append((sec, part))
            continue
        flat.append((section, ln))

    # hyprlang top-level sections that live under `decoration` in the Lua API.
    NS = {"shadow": "decoration.shadow", "blur": "decoration.blur"}

    def ns_for(prefix):
        return NS.get(prefix, prefix or "general")

    curves, animations = [], []
    cfg = {}   # luakey -> rendered RHS (dict dedupes; last write wins)
    for section, stmt in flat:
        m = re.match(r"^(?:(\w+)\s*:\s*)?([\w.]+)\s*=\s*(.*)$", stmt)
        if not m:
            continue
        sec_prefix = m.group(1) or section
        key = m.group(2)
        value = m.group(3).strip()

        if key == "bezier":
            f = [x.strip() for x in value.split(",")]
            if len(f) >= 5:
                curves.append('hl.curve(%s, { type = "bezier", points = { { %s, %s }, { %s, %s } } })'
                              % (lua_str(f[0]), f[1], f[2], f[3], f[4]))
        elif key == "animation":
            f = [x.strip() for x in value.split(",")]
            name = f[0]
            on = f[1] if len(f) > 1 else "1"
            parts = ["leaf = %s" % lua_str(name), "enabled = %s" % ("true" if on not in ("0", "false") else "false")]
            if len(f) > 2 and f[2]:
                parts.append("speed = %s" % f[2])
            if len(f) > 3 and f[3]:
                parts.append("bezier = %s" % lua_str(f[3]))
            if len(f) > 4 and f[4]:
                parts.append("style = %s" % lua_str(f[4]))
            animations.append("hl.animation({ %s })" % ", ".join(parts))
        elif key == "enabled" and (sec_prefix == "animations"):
            cfg["animations.enabled"] = "true" if value not in ("0", "false") else "false"
        elif key.startswith("col.") or key in ("active_border", "inactive_border"):
            full = "%s.%s" % (ns_for(sec_prefix), key) if key.startswith("col.") else "general.%s" % key
            bv = parse_border_value(value, cmap)
            if bv:
                cfg[full] = bv
        elif key == "screen_shader":
            cfg["decoration.screen_shader"] = lua_str(value)
        elif key == "border_size":
            cfg["general.border_size"] = value
        elif key == "rounding":
            cfg["decoration.rounding"] = value
        elif re.fullmatch(r"[-0-9.]+", value):
            cfg["%s.%s" % (ns_for(sec_prefix), key)] = value

    out = ["-- Generated by hve2lua.py from the Hyprland Visual Editor overlay. Do not edit."]
    out += curves
    out += animations
    if cfg:
        body = ",\n    ".join("[%s] = %s" % (lua_str(k), v) for k, v in cfg.items())
        out.append("hl.config({\n    " + body + ",\n})")
    print("\n".join(out))


if __name__ == "__main__":
    main()
