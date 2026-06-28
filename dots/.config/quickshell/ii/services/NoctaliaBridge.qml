pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Single canonical bridge: noctalia settings.json is the SOLE source of truth.
// It is watched live and every mapped key is pushed into ii's live Config.options.
// One-directional (noctalia -> ii). No reverse write, so there is no feedback loop.
Item {
    id: root

    property string settingsPath: Quickshell.env("HOME") + "/.config/noctalia/settings.json"
    property var noct: ({})
    property var maps: []

    // ---- nested helpers ----
    function getNoct(path) {
        var parts = path.split(".");
        var obj = root.noct;
        for (var i = 0; i < parts.length; ++i) {
            if (obj === undefined || obj === null)
                return undefined;
            obj = obj[parts[i]];
        }
        return obj;
    }

    function setII(path, value) {
        if (value === undefined || value === null)
            return;
        var parts = path.split(".");
        var obj = Config.options;
        for (var i = 0; i < parts.length - 1; ++i) {
            obj = obj[parts[i]];
            if (obj === undefined || obj === null)
                return;
        }
        var last = parts[parts.length - 1];
        var cur = obj[last];
        // Deep-compare objects/arrays so freshly-built values don't rewrite config every sync.
        var changed = (typeof value === "object") ? (JSON.stringify(cur) !== JSON.stringify(value)) : (cur !== value);
        if (changed)
            obj[last] = value;
    }

    // ---- declarative mapping table ----
    // n: noctalia path | i: ii Config.options path | t: optional transform(value, fullNoct)
    function buildMaps() {
        root.maps = [
            // ===== Bar styling =====
            { n: "bar.barType", i: "bar.barType" },
            { n: "bar.density", i: "bar.density" },
            { n: "bar.showOutline", i: "bar.showOutline" },
            { n: "bar.showCapsule", i: "bar.showCapsule" },
            { n: "bar.capsuleOpacity", i: "bar.capsuleOpacity" },
            { n: "bar.capsuleColorKey", i: "bar.capsuleColorKey" },
            { n: "bar.widgetSpacing", i: "bar.widgetSpacing" },
            { n: "bar.contentPadding", i: "bar.contentPadding" },
            { n: "bar.fontScale", i: "bar.fontScale" },
            { n: "bar.backgroundOpacity", i: "bar.backgroundOpacity" },
            { n: "bar.useSeparateOpacity", i: "bar.useSeparateOpacity" },
            { n: "bar.marginVertical", i: "bar.marginVertical" },
            { n: "bar.marginHorizontal", i: "bar.marginHorizontal" },
            { n: "bar.frameThickness", i: "bar.frameThickness" },
            { n: "bar.frameThickness", i: "appearance.wrappedFrameThickness" },
            { n: "bar.frameRadius", i: "bar.frameRadius" },
            { n: "bar.outerCorners", i: "bar.outerCorners" },
            // Bar position string -> ii vertical/bottom booleans
            { n: "bar.position", i: "bar.vertical", t: function (v) { return v === "left" || v === "right"; } },
            { n: "bar.position", i: "bar.bottom", t: function (v) { return v === "bottom" || v === "right"; } },

            // ===== Bar resource warning thresholds =====
            { n: "systemMonitor.cpuWarningThreshold", i: "bar.resources.cpuWarningThreshold" },
            { n: "systemMonitor.memWarningThreshold", i: "bar.resources.memoryWarningThreshold" },
            { n: "systemMonitor.swapWarningThreshold", i: "bar.resources.swapWarningThreshold" },

            // ===== Color scheme / wallpaper theming =====
            { n: "colorSchemes.darkMode", i: "appearance.colorMode", t: function (v) { return v ? "dark" : "light"; } },
            { n: "colorSchemes.useWallpaperColors", i: "appearance.wallpaperTheming.enableAppsAndShell" },
            { n: "colorSchemes.useWallpaperColors", i: "appearance.wallpaperTheming.enableQtApps" },
            { n: "colorSchemes.useWallpaperColors", i: "appearance.wallpaperTheming.enableTerminal" },
            { n: "colorSchemes.generationMethod", i: "appearance.palette.type", t: function (v) { return v ? "scheme-" + v : undefined; } },

            // ===== Night light =====
            { n: "nightLight.enabled", i: "light.night.automatic" },
            { n: "nightLight.nightTemp", i: "light.night.colorTemperature", t: function (v) { var n = parseInt(v); return isNaN(n) ? undefined : n; } },
            { n: "nightLight.manualSunset", i: "light.night.from" },
            { n: "nightLight.manualSunrise", i: "light.night.to" },

            // ===== Idle / lock =====
            { n: "idle.enabled", i: "lock.idle.enable" },
            { n: "idle.screenOffTimeout", i: "lock.idle.screenOffTimeout" },
            { n: "idle.lockTimeout", i: "lock.idle.lockTimeout" },
            { n: "idle.suspendTimeout", i: "lock.idle.suspendTimeout" },
            { n: "idle.fadeDuration", i: "lock.idle.fadeDuration" },

            // ===== Notifications =====
            { n: "notifications.normalUrgencyDuration", i: "notifications.timeout", t: function (v) { return v > 0 ? v * 1000 : undefined; } },
            { n: "notifications.monitors", i: "notifications.monitor.enable", t: function (v) { return Array.isArray(v) && v.length > 0; } },
            { n: "notifications.monitors", i: "notifications.monitor.name", t: function (v) { return Array.isArray(v) && v.length > 0 ? v[0] : undefined; } },

            // ===== OSD =====
            { n: "osd.autoHideMs", i: "osd.timeout", t: function (v) { return v > 0 ? v : undefined; } },

            // ===== Dock =====
            { n: "dock.enabled", i: "dock.enable" },
            { n: "dock.position", i: "dock.position" },
            { n: "dock.pinnedApps", i: "dock.pinnedApps" },
            { n: "dock.colorizeIcons", i: "dock.monochromeIcons", t: function (v) { return !v; } },

            // ===== Weather / location =====
            { n: "location.name", i: "bar.weather.city" },
            { n: "location.weatherEnabled", i: "bar.weather.enable" },
            { n: "location.useFahrenheit", i: "bar.weather.useUSCS" },
            { n: "location.autoLocate", i: "bar.weather.enableGPS" },

            // ===== Time / calendar =====
            { n: "location.firstDayOfWeek", i: "time.firstDayOfWeek", t: function (v) { return v >= 0 ? v : undefined; } },
            { n: "location.use12hourFormat", i: "time.format", t: function (v) { return v ? "hh:mm AP" : "HH:mm"; } },

            // ===== Fonts (only when noctalia provides a non-empty value) =====
            { n: "ui.fontDefault", i: "appearance.fonts.main", t: function (v) { return v ? v : undefined; } },
            { n: "ui.fontDefault", i: "appearance.fonts.title", t: function (v) { return v ? v : undefined; } },
            { n: "ui.fontDefault", i: "appearance.fonts.numbers", t: function (v) { return v ? v : undefined; } },
            { n: "ui.fontFixed", i: "appearance.fonts.monospace", t: function (v) { return v ? v : undefined; } },

            // ===== Wallpaper / background =====
            { n: "wallpaper.enabled", i: "background.enable" },
            { n: "wallpaper.directory", i: "wallpaperSelector.directories", t: function (v) {
                if (!v) return undefined;
                var p = v.indexOf("file://") === 0 ? v : "file://" + v;
                return [{ icon: "wallpaper", name: "Wallpapers", path: p }];
            } },

            // ===== Launcher / terminal =====
            { n: "appLauncher.pinnedApps", i: "launcher.pinnedApps" },
            { n: "appLauncher.terminalCommand", i: "apps.terminal", t: function (v) { return v ? v : undefined; } }
        ];
    }

    function syncAll() {
        if (!Config.options || !root.maps || root.maps.length === 0)
            return;
        var applied = 0;
        for (var k = 0; k < root.maps.length; ++k) {
            var m = root.maps[k];
            var raw = getNoct(m.n);
            if (raw === undefined)
                continue;
            var val = m.t ? m.t(raw, root.noct) : raw;
            setII(m.i, val);
            applied++;
        }
        console.log("NoctaliaBridge: synced", applied, "mappings -> Config.options");
    }

    function reloadNoct() {
        try {
            var txt = settingsFileView.text();
            if (!txt || txt.length === 0)
                return;
            root.noct = JSON.parse(txt);
            syncAll();
        } catch (e) {
            console.warn("NoctaliaBridge: failed to parse noctalia settings.json:", e);
        }
    }

    FileView {
        id: settingsFileView
        path: root.settingsPath
        watchChanges: true
        blockWrites: true // we never write back to noctalia
        onFileChanged: {
            console.log("NoctaliaBridge: settings.json changed, reloading");
            settingsFileView.reload();
        }
        onLoaded: root.reloadNoct()
        onLoadFailed: error => console.warn("NoctaliaBridge: load failed", error)
    }

    // Re-apply once Config becomes ready (in case settings.json loaded first).
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                root.syncAll();
        }
    }

    Component.onCompleted: {
        buildMaps();
        Qt.callLater(reloadNoct);
    }
}
