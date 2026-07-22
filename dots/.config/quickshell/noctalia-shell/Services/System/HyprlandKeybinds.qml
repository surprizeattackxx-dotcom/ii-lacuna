pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Loads categorized keybindings for the cheatsheet from the JSON that the
// Hyprland config itself dumps on every (re)load (config/cheatsheet.lua wraps
// hl.bind and records each real, variable-resolved bind at registration
// time). Replaces the old parse_binds_lua.py regex parser, which pointed at a
// pre-migration path and couldn't resolve Lua variables anyway.
Singleton {
    id: root

    property var keybinds: []         // flat: [{key_combo, category, description}]
    property var categories: []       // [{name, binds: [...]}]

    readonly property string jsonPath: Quickshell.env("HOME") + "/.local/state/quickshell/hypr-binds.json"

    function reload() { bindsFile.reload() }

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

    // The config rewrites the JSON on every Hyprland reload; watchChanges
    // picks that up, so no configreloaded event plumbing is needed.
    FileView {
        id: bindsFile
        path: root.jsonPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.keybinds = JSON.parse(text()); } catch (e) { root.keybinds = []; }
            root._regroup();
        }
    }
}
