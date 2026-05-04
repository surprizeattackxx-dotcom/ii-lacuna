import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    width: 300
    height: 150
    color: "#222222"
    radius: 10

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: "Wallpaper Controls"
            color: "white"
            font.pixelSize: 16
        }

        Button {
            text: "Random Wallpaper"
            onClicked: rotatorProc.running = true
        }
    }

    Process {
        id: rotatorProc
        command: ["bash", "-c",
            'DIR="$(xdg-user-dir PICTURES)/Wallpapers"; ' +
            'img=$(find "$DIR" -type f \\( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" \\) 2>/dev/null | shuf -n1); ' +
            '[ -n "$img" ] && bash "$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh" --image "$img"'
        ]
        running: false
        onExited: console.log("[WallpaperController] exited code=" + code)
    }
}
