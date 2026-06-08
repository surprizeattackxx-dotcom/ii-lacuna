pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Filesystem icon index (basename -> path) for the dirs Qt's iconPath doesn't
// search — pixmaps, flatpak exports, hicolor sizes. Mirrors how hamr resolves
// icons. Built once per session, cached to disk so the first open is instant.
Singleton {
    id: root

    property var index: ({})
    property bool ready: false
    readonly property string cachePath: `${Directories.cache}/sphereLauncher_icons.json`

    function resolve(iconName, appName) {
        const idx = root.index;
        if (!idx) return "";
        const cands = [];
        if (iconName) {
            cands.push(iconName, iconName.toLowerCase());
            if (iconName.includes(".")) {
                const last = iconName.split(".").pop();
                cands.push(last, last.toLowerCase());
            }
            cands.push(iconName.toLowerCase().replace(/\s+/g, "-"));
            cands.push(iconName.toLowerCase().replace(/_/g, "-"));
        }
        if (appName) cands.push(appName.toLowerCase().replace(/\s+/g, "-"));
        for (const c of cands) if (c && idx[c]) return idx[c];
        return "";
    }

    function refresh() { findProc.running = true; }

    FileView {
        id: cacheFile
        path: root.cachePath
        blockLoading: true
        onLoaded: {
            root.index = cacheAdapter.data || ({});
            root.ready = Object.keys(root.index).length > 0;
            root.refresh();   // pick up newly-installed apps in the background
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) root.refresh();
        }
        adapter: JsonAdapter {
            id: cacheAdapter
            property var data: ({})
        }
    }

    Process {
        id: findProc
        command: ["bash", "-c",
            'find /usr/share/pixmaps /usr/share/icons/hicolor ' +
            '"$HOME/.local/share/icons/hicolor" ' +
            '/var/lib/flatpak/exports/share/icons/hicolor ' +
            '"$HOME/.local/share/flatpak/exports/share/icons/hicolor" ' +
            '-maxdepth 4 -type f \\( -iname "*.svg" -o -iname "*.png" -o -iname "*.xpm" \\) 2>/dev/null']
        stdout: StdioCollector {
            function sizeScore(path) {
                if (path.endsWith(".svg")) return 100000;       // scalable wins
                const m = path.match(/\/(\d+)x\1\//);
                if (m) return parseInt(m[1]);                   // larger px better
                return 64;                                      // pixmaps / flat dir
            }
            onStreamFinished: {
                const best = {};   // base -> { path, score }
                for (const line of text.split("\n")) {
                    if (!line) continue;
                    const base = line.split("/").pop().replace(/\.(png|svg|xpm)$/i, "");
                    const score = sizeScore(line);
                    if (!best[base] || score > best[base].score)
                        best[base] = { path: line, score: score };
                }
                const map = {};
                for (const k in best) map[k] = best[k].path;
                root.index = map;
                root.ready = true;
                cacheAdapter.data = map;
                cacheFile.writeAdapter();
            }
        }
    }
}
