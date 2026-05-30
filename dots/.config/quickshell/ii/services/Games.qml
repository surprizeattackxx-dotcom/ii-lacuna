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
                            installed: g.installed !== false,
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
        root.scan()
    }
}
