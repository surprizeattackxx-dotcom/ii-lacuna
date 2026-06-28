pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Parses the Hyprland Lua keybinds file into categorized keybindings for the
// cheatsheet (ported from illogical-impulse). The config is Lua (hl.bind), so
// hyprctl binds shows opaque __lua dispatchers — we parse the .lua file instead.
Singleton {
    id: root

    property var keybinds: []         // flat: [{key_combo, category, description}]
    property var categories: []       // [{name, binds: [...]}]

    readonly property string scriptPath: Quickshell.shellPath("Scripts/hyprland/parse_binds_lua.py")
    readonly property string bindsPath: Quickshell.env("HOME") + "/.config/hypr/hyprland/keybinds.lua"

    function reload() { parseProc.running = true }

    // Collapse runs of binds that share a modifier prefix + description and
    // differ only by a trailing digit (e.g. SUPER+1..0 "Focus workspace") into
    // one ranged row like "SUPER + 1–0".
    function _compact(binds) {
        const groups = ({});
        const result = [];
        for (var i = 0; i < binds.length; i++) {
            const b = binds[i];
            const parts = ("" + b.key_combo).split(" + ");
            const last = parts[parts.length - 1];
            if (parts.length > 1 && /^[0-9]$/.test(last)) {
                const prefix = parts.slice(0, -1).join(" + ");
                const gk = prefix + "||" + b.description;
                if (!groups[gk]) { groups[gk] = { prefix: prefix, description: b.description, digits: [] }; result.push({ __group: gk }); }
                groups[gk].digits.push(last);
            } else {
                result.push(b);
            }
        }
        return result.map(r => {
            if (!r.__group) return r;
            const g = groups[r.__group];
            if (g.digits.length >= 3) {
                const ds = g.digits.slice().sort((a, c) => (a === "0" ? 10 : +a) - (c === "0" ? 10 : +c));
                return { key_combo: g.prefix + " + " + ds[0] + "–" + ds[ds.length - 1], description: g.description };
            }
            return { key_combo: g.prefix + " + " + g.digits.join("/"), description: g.description };
        });
    }

    function _regroup() {
        const order = [];
        const map = ({});
        for (var i = 0; i < root.keybinds.length; i++) {
            const b = root.keybinds[i];
            const cat = b.category || "Other";
            if (!map[cat]) { map[cat] = []; order.push(cat); }
            map[cat].push({
                key_combo: b.key_combo,
                category: cat,
                description: ("" + (b.description || "")).replace(/^Execute:\s*/, "")
            });
        }
        root.categories = order.map(c => ({ name: c, binds: root._compact(map[c]) }));
    }

    Process {
        id: parseProc
        command: ["python3", root.scriptPath, root.bindsPath]
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                try { root.keybinds = JSON.parse(out.text); } catch (e) { root.keybinds = []; }
                root._regroup();
            }
        }
    }

    // Re-parse when Hyprland reloads its config.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && event.name === "configreloaded") root.reload();
        }
    }

    Component.onCompleted: reload()
}
