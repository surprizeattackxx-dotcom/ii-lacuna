import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: wallpaperController
    implicitWidth: 300
    implicitHeight: 150
    color: "transparent"
    visible: false
    screen: Quickshell.screens[0]

    Rectangle {
        anchors.fill: parent
        color: "#222222"
        radius: 10

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: "Wallpaper Controls"
                color: "white"
                font.pixelSize: 16
            }

            Rectangle {
                width: 120
                height: 40
                color: "#444444"
                radius: 5
                Text {
                    anchors.centerIn: parent
                    text: "Random Wallpaper"
                    color: "white"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: rotatorProc.running = true
                }
            }
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
    }
}
