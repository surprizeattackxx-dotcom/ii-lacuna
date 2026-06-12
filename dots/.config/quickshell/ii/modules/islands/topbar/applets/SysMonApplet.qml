import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property var bar
    property var barZone
    property bool editMode: false

    property int cpuPct: 0
    property int ramPct: 0
    property var _prevIdle: 0
    property var _prevTotal: 0

    radius: bar.s(14)
    border.width: 0
    color: "transparent"

    implicitHeight: bar.barHeight
    implicitWidth: monRow.width + bar.s(16)
    clip: true

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statFetch.running = true
    }

    Process {
        id: statFetch
        command: ["bash", "-c", "head -1 /proc/stat; grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const cpu = lines[0].trim().split(/\s+/).slice(1).map(Number)
                const idle = cpu[3] + cpu[4]
                const total = cpu.reduce((a, b) => a + b, 0)
                if (root._prevTotal > 0 && total > root._prevTotal) {
                    const dIdle = idle - root._prevIdle
                    const dTotal = total - root._prevTotal
                    root.cpuPct = Math.round(100 * (1 - dIdle / dTotal))
                }
                root._prevIdle = idle
                root._prevTotal = total
                const memTotal = parseInt(lines[1].split(/\s+/)[1])
                const memAvail = parseInt(lines[2].split(/\s+/)[1])
                root.ramPct = Math.round(100 * (1 - memAvail / memTotal))
            }
        }
    }

    Row {
        id: monRow
        anchors.centerIn: parent
        spacing: bar.s(10)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }

        Row {
            spacing: bar.s(4)
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family: "Iosevka Nerd Font"
                font.pixelSize: bar.s(13)
                color: barZone.adaptiveSubtext
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.cpuPct + "%"
                font.family: "JetBrains Mono"
                font.pixelSize: bar.s(12)
                font.weight: Font.DemiBold
                color: barZone.adaptiveText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
        Row {
            spacing: bar.s(4)
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family: "Iosevka Nerd Font"
                font.pixelSize: bar.s(13)
                color: barZone.adaptiveSubtext
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.ramPct + "%"
                font.family: "JetBrains Mono"
                font.pixelSize: bar.s(12)
                font.weight: Font.DemiBold
                color: barZone.adaptiveText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }
}
