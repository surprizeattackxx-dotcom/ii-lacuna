import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property var bar
    property var barZone
    property bool editMode: false

    property string downRate: "0 B/s"
    property string upRate: "0 B/s"
    property var _prevRx: -1
    property var _prevTx: -1
    property var _prevTime: 0

    radius: bar.s(14)
    border.width: 0
    color: "transparent"

    implicitHeight: bar.barHeight
    implicitWidth: netRow.width + bar.s(16)
    clip: true

    function fmt(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024) return Math.round(bps / 1024) + " KB/s"
        return Math.round(bps) + " B/s"
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netFetch.running = true
    }

    Process {
        id: netFetch
        command: ["bash", "-c", "awk '/:/ {gsub(/:/,\"\",$1); if ($1!=\"lo\") {rx+=$2; tx+=$10}} END {print rx, tx}' /proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/)
                const rx = parseInt(parts[0]) || 0
                const tx = parseInt(parts[1]) || 0
                const now = Date.now()
                if (root._prevRx >= 0 && now > root._prevTime) {
                    const dt = (now - root._prevTime) / 1000
                    root.downRate = root.fmt((rx - root._prevRx) / dt)
                    root.upRate = root.fmt((tx - root._prevTx) / dt)
                }
                root._prevRx = rx
                root._prevTx = tx
                root._prevTime = now
            }
        }
    }

    Row {
        id: netRow
        anchors.centerIn: parent
        spacing: bar.s(8)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }

        Row {
            spacing: bar.s(3)
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰇚"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: bar.s(12)
                color: barZone.adaptiveSubtext
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.downRate
                font.family: "JetBrains Mono"
                font.pixelSize: bar.s(11)
                font.weight: Font.DemiBold
                color: barZone.adaptiveText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
        Row {
            spacing: bar.s(3)
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰕒"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: bar.s(12)
                color: barZone.adaptiveSubtext
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.upRate
                font.family: "JetBrains Mono"
                font.pixelSize: bar.s(11)
                font.weight: Font.DemiBold
                color: barZone.adaptiveText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }
}
