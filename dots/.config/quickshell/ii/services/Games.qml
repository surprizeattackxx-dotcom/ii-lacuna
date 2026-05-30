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

    function launchGame(game) {
        Quickshell.execDetached(["bash", "-c", game.launch])
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
                            launch: g.launch,
                        })
                    }
                    root.available = root.gameModel.count > 0
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
        root.scan()
    }
}
