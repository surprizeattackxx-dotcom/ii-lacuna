pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string scanScript: Directories.scriptPath + "/games/scan_games.py"
    readonly property string installScript: Directories.scriptPath + "/games/install_heroic.py"
    readonly property string installStatePath: Directories.gameInstallStatePath

    property ListModel gameModel: ListModel {}

    property bool scanning: false
    property bool available: false

    property list<string> favorites: []
    property list<string> hidden: []
    property var launchOpts: ({})
    property var firstSeen: ({})
    readonly property int newWindowSecs: 14 * 86400

    property var wineVersions: []
    property string defaultInstallPath: ""
    property var defaultWine: null

    property string installingId: ""
    property real installProgress: 0
    property string installStatus: ""

    function scan() {
        if (root.scanning) return
        root.scanning = true
        scanProc.running = true
    }

    function isFavorite(appId) { return root.favorites.indexOf(appId) !== -1 }

    function toggleFavorite(appId) {
        if (root.isFavorite(appId))
            root.favorites = root.favorites.filter(a => a !== appId)
        else
            root.favorites = [...root.favorites, appId]
        favoritesFile.setText(JSON.stringify(root.favorites))
    }

    function isHidden(appId) { return root.hidden.indexOf(appId) !== -1 }

    function toggleHidden(appId) {
        if (root.isHidden(appId))
            root.hidden = root.hidden.filter(a => a !== appId)
        else
            root.hidden = [...root.hidden, appId]
        hiddenFile.setText(JSON.stringify(root.hidden))
    }

    function openStorePage(game) {
        if (game.storeUrl && game.storeUrl.length > 0)
            Quickshell.execDetached(["xdg-open", game.storeUrl])
    }

    function getLaunchOpts(appId) { return root.launchOpts[appId] || {} }

    function setLaunchOpt(appId, key, value) {
        var all = JSON.parse(JSON.stringify(root.launchOpts))
        if (!all[appId]) all[appId] = {}
        all[appId][key] = value
        root.launchOpts = all
        launchOptsFile.setText(JSON.stringify(all))
    }

    function launchGame(game) {
        var o = root.launchOpts[game.appId] || {}
        var inner = (o.mangohud ? "mangohud " : "") + (o.gamemode ? "gamemoderun " : "") + game.launch
        var cmd = o.gamescope ? ("gamescope -f -- " + inner) : inner
        Quickshell.execDetached(["bash", "-c", cmd])
    }

    function isNew(appId) {
        var ts = root.firstSeen[appId]
        if (!ts || ts <= 0) return false
        return (Math.floor(Date.now() / 1000) - ts) < root.newWindowSecs
    }

    function progressColor(pct) {
        var hue = Math.max(0, Math.min(120, pct * 1.2)) / 360
        return Qt.hsva(hue, 0.65, 0.95, 1)
    }

    function canInstall(game) {
        return game && !game.installed && game.platform === "heroic" && game.runner === "legendary"
    }

    function installGame(game, basePath, wine) {
        if (game.platform === "heroic" && game.runner !== "legendary") {
            Quickshell.execDetached(["xdg-open", "heroic://install/" + game.appName])
            return
        }
        if (root.installingId.length > 0) return
        var w = wine || root.defaultWine || { name: "System Wine", bin: "/usr/bin/wine", type: "wine" }
        var path = (basePath && basePath.length > 0) ? basePath : root.defaultInstallPath
        Quickshell.execDetached(["systemd-run", "--user", "--quiet", "--collect",
            "python3", root.installScript, "install",
            "--app", game.appName, "--app-id", game.appId, "--name", game.name,
            "--base-path", path, "--state-file", root.installStatePath,
            "--wine-name", w.name, "--wine-bin", w.bin, "--wine-type", w.type])
        root.installingId = game.appId
        root.installProgress = 0
        root.installStatus = "Preparing…"
    }

    property string lastInstallState: ""

    function applyInstallState(t) {
        try {
            var d = JSON.parse(t)
            var st = d.state || ""
            if (d.active) {
                root.installingId = d.appId || ""
                root.installProgress = d.progress || 0
                root.installStatus = d.status || ""
            } else if (root.installingId === "" || root.installingId === d.appId) {
                root.installingId = ""
                root.installProgress = 0
                root.installStatus = ""
            }
            if (st === "done" && root.lastInstallState !== "done" && root.lastInstallState !== "")
                root.scan()
            root.lastInstallState = st
        } catch (e) {}
    }

    function canUninstall(game) {
        return game && game.installed && (game.platform === "steam" || game.platform === "rom")
    }

    function uninstall(game) {
        if (!game) return
        if (game.platform === "steam")
            Quickshell.execDetached(["bash", "-c", "steam steam://uninstall/" + game.appId])
        else if (game.platform === "rom")
            Quickshell.execDetached(["rm", "-f", game.appId])
    }

    FileView {
        id: favoritesFile
        path: Qt.resolvedUrl(Directories.gameFavoritesPath)
        onLoaded: {
            try { root.favorites = JSON.parse(favoritesFile.text()) } catch (e) { root.favorites = [] }
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) { root.favorites = []; favoritesFile.setText("[]") }
        }
    }

    FileView {
        id: hiddenFile
        path: Qt.resolvedUrl(Directories.gameHiddenPath)
        onLoaded: {
            try { root.hidden = JSON.parse(hiddenFile.text()) } catch (e) { root.hidden = [] }
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) { root.hidden = []; hiddenFile.setText("[]") }
        }
    }

    FileView {
        id: launchOptsFile
        path: Qt.resolvedUrl(Directories.gameLaunchOptsPath)
        onLoaded: {
            try { root.launchOpts = JSON.parse(launchOptsFile.text()) } catch (e) { root.launchOpts = ({}) }
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) { root.launchOpts = ({}); launchOptsFile.setText("{}") }
        }
    }

    FileView {
        id: firstSeenFile
        path: Qt.resolvedUrl(Directories.gameFirstSeenPath)
        onLoaded: {
            try { root.firstSeen = JSON.parse(firstSeenFile.text()) } catch (e) { root.firstSeen = ({}) }
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) { root.firstSeen = ({}); firstSeenFile.setText("{}") }
        }
    }

    function updateFirstSeen(games) {
        var fs = JSON.parse(JSON.stringify(root.firstSeen))
        var wasEmpty = Object.keys(fs).length === 0
        var now = Math.floor(Date.now() / 1000)
        var changed = false
        for (var i = 0; i < games.length; i++) {
            if (!(games[i].appId in fs)) {
                fs[games[i].appId] = wasEmpty ? 0 : now
                changed = true
            }
        }
        if (changed) {
            root.firstSeen = fs
            firstSeenFile.setText(JSON.stringify(fs))
        }
    }

    Process {
        id: scanProc
        command: ["python3", root.scanScript]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var games = JSON.parse(text)
                    root.gameModel.clear()
                    for (var i = 0; i < games.length; i++) {
                        var g = games[i]
                        root.gameModel.append({
                            name: g.name,
                            appId: g.appId,
                            platform: g.platform,
                            art: g.art || "",
                            iconArt: g.iconArt === true,
                            hero: g.hero || "",
                            installed: g.installed !== false,
                            playMinutes: g.playMinutes || 0,
                            lastPlayed: g.lastPlayed || 0,
                            storeUrl: g.storeUrl || "",
                            size: g.size || 0,
                            launch: g.launch,
                            runner: g.runner || "",
                            appName: g.appName || "",
                        })
                    }
                    root.available = root.gameModel.count > 0
                    root.updateFirstSeen(games)
                } catch (e) {
                    console.warn("Games: failed to parse scan output:", e)
                }
                root.scanning = false
            }
        }

        onExited: (code, status) => {
            if (code !== 0) {
                root.scanning = false
            }
        }
    }

    Process {
        id: runnersProc
        command: ["python3", root.installScript, "list-runners"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.wineVersions = d.runners || []
                    root.defaultInstallPath = d.defaultPath || ""
                    root.defaultWine = d.defaultWine || null
                } catch (e) {
                    console.warn("Games: failed to parse runners:", e)
                }
            }
        }
    }

    Timer {
        running: root.installingId.length > 0
        interval: 1000
        repeat: true
        onTriggered: installStateFile.reload()
    }

    FileView {
        id: installStateFile
        path: Qt.resolvedUrl(root.installStatePath)
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyInstallState(installStateFile.text())
    }

    Component.onCompleted: {
        favoritesFile.reload()
        hiddenFile.reload()
        launchOptsFile.reload()
        firstSeenFile.reload()
        runnersProc.running = true
        Quickshell.execDetached(["python3", root.installScript, "check-stale",
            "--state-file", root.installStatePath])
        installStateFile.reload()
        root.scan()
    }
}
