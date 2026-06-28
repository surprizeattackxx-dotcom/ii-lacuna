#!/usr/bin/env python3
import re, json, sys
from pathlib import Path


def _fmt_workspace(args, prefix="Focus"):
    w = args.get("workspace", "")
    d = args.get("direction", "")
    if d:
        return f"{prefix} {d}"
    if w:
        return f"{prefix} workspace"
    return prefix


DESC_MAP = {
    "exec_cmd": lambda a: f"Execute: {a.get('_str', '')}",
    "window.close": lambda a: "Close window",
    "window.pin": lambda a: "Pin window",
    "window.move": lambda a: _fmt_workspace(a, "Move window to"),
    "window.drag": lambda a: "Drag window",
    "window.resize": lambda a: "Resize window",
    "focus": lambda a: _fmt_workspace(a, "Focus"),
    "layout": lambda a: f"Split ratio {a.get('_str', '').removeprefix('splitratio ')}",
}


GLOBAL_CLEANUP = re.compile(r"^quickshell:")


def autogen_description(dispatcher_text: str) -> str:
    if dispatcher_text.startswith("hl.dsp."):
        body = dispatcher_text.removeprefix("hl.dsp.")
    elif dispatcher_text.startswith("hl.plugin."):
        return dispatcher_text.removeprefix("hl.plugin.").removesuffix(".toggle").replace(".", " ").title()
    else:
        return ""

    m = re.match(r"(\w[\w.]*)\((.*)\)\s*$", body)
    if not m:
        return body.replace("_", " ").title()

    func = m.group(1)
    raw_args = m.group(2).strip()

    args = {}
    if raw_args.startswith("{"):
        for kv in re.finditer(r'(\w+)\s*=\s*(?:"([^"]*)"|(\d+)|(\w+))', raw_args):
            args[kv.group(1)] = kv.group(2) or kv.group(3) or kv.group(4) or ""
    elif raw_args.startswith('"'):
        s = re.match(r'"([^"]*)"', raw_args)
        if s:
            args["_str"] = s.group(1)

    if func == "global":
        label = args.get("_str", "")
        label = GLOBAL_CLEANUP.sub("", label)
        label = label.removesuffix("Toggle").removesuffix("Open").removesuffix("Close")
        label = re.sub(r"([a-z])([A-Z])", r"\1 \2", label)
        return f"Toggle {label.lower()}"

    if func in DESC_MAP:
        return DESC_MAP[func](args)

    return func.replace("_", " ").title()


def parse_binds_lua(path: str) -> list:
    text = Path(path).expanduser().read_text()
    lines = text.splitlines()

    binds = []
    category = ""
    pending_comment = ""

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        if stripped.startswith("-- ───"):
            category = stripped.removeprefix("--").strip().strip("─").strip()
            pending_comment = ""
        elif stripped.startswith("--"):
            c = stripped.removeprefix("--").strip()
            if c and not c.startswith("Uses "):
                pending_comment = c
        elif "hl.bind(" in line:
            raw = ""
            depth = 0
            started = False
            j = i
            while j < len(lines):
                for ch in lines[j]:
                    if ch == "(":
                        started = True
                        depth += 1
                    elif ch == ")":
                        depth -= 1
                        if started and depth == 0:
                            raw += ch
                            break
                    if started:
                        raw += ch
                if started and depth == 0:
                    j += 1
                    break
                j += 1

            m = re.search(r'^\s*\(\s*"([^"]+)"', raw)
            if m:
                key_combo = m.group(1)

                description = ""
                desc_m = re.search(r'description\s*=\s*"([^"]+)"', raw)
                if desc_m:
                    description = desc_m.group(1)
                elif pending_comment:
                    description = pending_comment

                disp_m = re.search(r",\s*(hl\.[\w.]+(?:\([^)]*\))?)", raw)
                if not description and disp_m:
                    description = autogen_description(disp_m.group(1))

                binds.append({
                    "key_combo": key_combo,
                    "category": category,
                    "description": description,
                })

            pending_comment = ""
            i = j - 1
        i += 1

    return binds


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else str(Path("~/.config/hypr/binds.lua").expanduser())
    result = parse_binds_lua(path)
    print(json.dumps(result, indent=2))
