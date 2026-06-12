import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property var bar
    property var barZone
    property bool editMode: false

    property string winClass: ""
    property string winTitle: ""

    radius: bar.s(14)
    border.width: 0
    color: "transparent"

    implicitHeight: bar.barHeight
    implicitWidth: winTitle === "" ? 0 : Math.min(titleRow.width + bar.s(16), bar.s(360))
    clip: true

    Behavior on implicitWidth { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }

    Process {
        id: initialFetch
        running: true
        command: ["bash", "-c", "hyprctl activewindow -j 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(this.text)
                    root.winClass = w.class || ""
                    root.winTitle = w.title || ""
                } catch (e) {}
            }
        }
    }

    Process {
        running: true
        command: ["bash", "-c",
            "socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - 2>/dev/null | grep --line-buffered '^activewindow>>'"]
        stdout: SplitParser {
            onRead: line => {
                const payload = line.slice("activewindow>>".length)
                const comma = payload.indexOf(",")
                root.winClass = comma >= 0 ? payload.slice(0, comma) : payload
                root.winTitle = comma >= 0 ? payload.slice(comma + 1) : ""
            }
        }
    }

    Row {
        id: titleRow
        anchors.verticalCenter: parent.verticalCenter
        x: bar.s(8)
        spacing: bar.s(7)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󱂬"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: bar.s(15)
            color: barZone.adaptiveSubtext
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: root.winClass
                visible: text !== ""
                font.family: "JetBrains Mono"
                font.pixelSize: bar.s(9)
                color: barZone.adaptiveSubtext
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                text: root.winTitle
                width: Math.min(implicitWidth, root.bar.s(320))
                elide: Text.ElideRight
                font.family: "JetBrains Mono"
                font.pixelSize: bar.s(12)
                font.weight: Font.DemiBold
                color: barZone.adaptiveText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }
}
