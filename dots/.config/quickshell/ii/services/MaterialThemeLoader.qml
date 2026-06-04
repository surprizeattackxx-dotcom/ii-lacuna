pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Automatically reloads generated material colors.
 * It is necessary to run reapplyTheme() on startup because Singletons are lazily loaded.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath
    property int sequenceNum: 0

    function nextSeq() {
        root.sequenceNum += 1
        return root.sequenceNum
    }

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

    /** Call after toggle_darkmode.sh / switchwall updates colors.json — FileView often misses rapid writes. */
    function reloadAfterExternalColorChange() {
        delayedExternalReload1.restart()
        delayedExternalReload2.restart()
    }

    Timer {
        id: delayedExternalReload1
        interval: 120
        repeat: false
        onTriggered: {
            const seq = root.nextSeq()
            console.log(`[MTL DEBUG] [${seq}] delayedExternalReload1 fired`);
            root.reapplyTheme()
        }
    }
    Timer {
        id: delayedExternalReload2
        interval: 520
        repeat: false
        onTriggered: {
            const seq = root.nextSeq()
            console.log(`[MTL DEBUG] [${seq}] delayedExternalReload2 fired`);
            root.reapplyTheme()
        }
    }

    function hashStr(s) {
        let h = 0
        for (let i = 0; i < s.length; i++) {
            h = ((h << 5) - h) + s.charCodeAt(i)
            h |= 0
        }
        return h
    }

    function applyColors(fileContent, caller) {
        const len = fileContent?.length ?? 0
        const fp = hashStr(fileContent ?? "")
        const prefix = fileContent?.substring(0, 80)?.replace(/\n/g, "\\n") ?? ""
        console.log(`[MTL DEBUG] applyColors called from: ${caller ?? "unknown"}, len: ${len}, hash: ${fp}, prefix: "${prefix}"`);
        let json
        try { json = JSON.parse(fileContent) }
        catch (e) { console.warn("[MaterialThemeLoader] Failed to parse theme:", e); return }
        console.log(`[MTL DEBUG]   darkmode: ${json.darkmode}, primary: ${json.primary}, keys: ${Object.keys(json).length}`);
        for (const key in json) {
            if (json.hasOwnProperty(key)) {
                // Convert snake_case to CamelCase
                const camelCaseKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
                const m3Key = `m3${camelCaseKey}`
                try { Appearance.m3colors[m3Key] = json[key] } catch (e) {}            }
        }
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
        onTriggered: {
            const seq = root.nextSeq()
            const ts = Date.now()
            root.applyColors(themeFileView.text(), `delayedFileRead#${seq}@${ts}`)
        }
    }

	FileView { 
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            const seq = root.nextSeq()
            console.log(`[MTL DEBUG] [${seq}] onFileChanged — file changed on disk, triggering reload`);
            this.reload()
            delayedFileRead.start()
        }
        onLoadedChanged: {
            const seq = root.nextSeq()
            const fileContent = themeFileView.text()
            const fp = root.hashStr(fileContent ?? "")
            const len = fileContent?.length ?? 0
            const ts = Date.now()
            console.log(`[MTL DEBUG] [${seq}] onLoadedChanged — loaded: ${themeFileView.loaded}, len: ${len}, hash: ${fp}, ts: ${ts}`);
            root.applyColors(fileContent, `onLoadedChanged#${seq}`)
        }
        onLoadFailed: {
            const seq = root.nextSeq()
            console.log(`[MTL DEBUG] [${seq}] onLoadFailed`);
            root.resetFilePathNextTime();
        }
    }

    function toggleLightDark() {
        const currentlyDark = Appearance.m3colors.darkmode;
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", currentlyDark ? "light" : "dark", "--noswitch"]);
    }

    GlobalShortcut {
        name: "toggleLightDark"
        description: "Toggles between dark theme and light theme"

        onPressed: {
            root.toggleLightDark();
        }
    }
}
