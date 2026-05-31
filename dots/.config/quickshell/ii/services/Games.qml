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

    property ListModel gameModel: ListModel {}

    property bool scanning: false
    property bool available: false

    property list<string> favorites: []
    property list<string> hidden: []
    property var launchOpts: ({})
    property var firstSeen: ({})
    readonly property int newWindowSecs: 14 * 86400

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
                            hero: g.hero || "",
                            installed: g.installed !== false,
                            playMinutes: g.playMinutes || 0,
                            lastPlayed: g.lastPlayed || 0,
                            storeUrl: g.storeUrl || "",
                            size: g.size || 0,
                            launch: g.launch,
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

    Component.onCompleted: {
        favoritesFile.reload()
        hiddenFile.reload()
        launchOptsFile.reload()
        firstSeenFile.reload()
        root.scan()
    }
}
