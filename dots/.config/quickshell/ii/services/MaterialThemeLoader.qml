pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath
    property string activeMonitor: ""

    IpcHandler {
        target: "theme"
        function reload(): void {
            root.reloadAfterExternalColorChange()
        }
        function toggleLightDark(): void {
            root.toggleLightDark()
        }
    }

    function reapplyTheme() {
        themeFileView.reload()
    }

    function reloadAfterExternalColorChange() {
        delayedExternalReload1.restart()
        delayedExternalReload2.restart()
    }

    Timer {
        id: delayedExternalReload1
        interval: 120
        repeat: false
        onTriggered: root.reapplyTheme()
    }

    Timer {
        id: delayedExternalReload2
        interval: 520
        repeat: false
        onTriggered: root.reapplyTheme()
    }

    function applyColors(fileContent) {
        let json
        try { json = JSON.parse(fileContent) }
        catch (e) { console.warn("[MaterialThemeLoader] Failed to parse theme:", e); return }
        for (const key in json) {
            if (json.hasOwnProperty(key)) {
                const camelCaseKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
                // Unknown matugen keys (surface_tint, *_fixed, inverse_primary…) aren't
                // declared on m3colors and throw — catch so one bad key can't abort the
                // whole loop and freeze every later color on the hardcoded defaults.
                try { Appearance.m3colors[`m3${camelCaseKey}`] = json[key] } catch (e) {}
            }
        }
        Appearance.m3colors.darkmode = (Appearance.m3colors.m3background.hslLightness < 0.5)
    }

    function resetFilePathNextTime() {
        resetFilePathNextWallpaperChange.enabled = true
    }

    Connections {
        id: resetFilePathNextWallpaperChange
        enabled: false
        target: Config.options.background
        function onWallpaperPathChanged() {
            root.filePath = ""
            root.filePath = Directories.generatedMaterialThemePath
            resetFilePathNextWallpaperChange.enabled = false
        }
    }

    Timer {
        id: delayedFileRead
        interval: Config.options?.hacks?.arbitraryRaceConditionDelay ?? 100
        repeat: false
        running: false
        onTriggered: root.applyColors(themeFileView.text())
    }

    FileView {
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            this.reload()
            delayedFileRead.start()
        }
        onLoadedChanged: root.applyColors(themeFileView.text())
        onLoadFailed: root.resetFilePathNextTime()
    }

    function toggleLightDark() {
        const currentlyDark = Appearance.m3colors.darkmode
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", currentlyDark ? "light" : "dark", "--noswitch"])
    }

    GlobalShortcut {
        name: "toggleLightDark"
        description: "Toggles between dark theme and light theme"
        onPressed: root.toggleLightDark()
    }

    Process {
        id: monitorColorCopy
        running: false
        onExited: (code) => { if (code === 0) root.reloadAfterExternalColorChange() }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            const mon = Hyprland.focusedMonitor?.name
            if (!mon || mon === root.activeMonitor) return
            root.activeMonitor = mon
            if (!Persistent.ready || GlobalStates.activeTheme !== "Matugen") return
            const src = Directories.generatedMaterialThemePath
                .replace(/colors\.json$/, `wallpaper/monitors/${mon}-colors.json`)
            monitorColorCopy.command = ["cp", src, Directories.generatedMaterialThemePath]
            monitorColorCopy.running = true
        }
    }
}
