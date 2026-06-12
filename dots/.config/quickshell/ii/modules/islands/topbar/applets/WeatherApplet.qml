import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property var bar
    property var barZone
    property bool editMode: false

    property string weatherText: ""
    property bool isHovered: weatherMouse.containsMouse

    radius: bar.s(14)
    border.width: 0
    color: "transparent"

    implicitHeight: bar.barHeight
    implicitWidth: weatherText === "" ? 0 : weatherRow.width + bar.s(16)
    clip: true

    Behavior on implicitWidth { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }

    scale: isHovered ? 1.04 : 1.0
    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    Timer {
        interval: 20 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherFetch.running = true
    }

    Process {
        id: weatherFetch
        command: ["bash", "-c", "curl -sf --max-time 10 'wttr.in/?format=%c+%t' 2>/dev/null | head -c 40"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim()
                if (t !== "" && !t.includes("Unknown") && !t.includes("Sorry"))
                    root.weatherText = t.replace(/\s+/g, " ")
            }
        }
    }

    Row {
        id: weatherRow
        anchors.centerIn: parent
        spacing: bar.s(6)

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
            text: root.weatherText
            font.family: "JetBrains Mono"
            font.pixelSize: bar.s(12)
            font.weight: Font.DemiBold
            color: barZone.adaptiveText
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    MouseArea {
        id: weatherMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.editMode
        onClicked: weatherFetch.running = true
    }
}
