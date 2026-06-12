import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property var bar
    property var barZone
    property bool editMode: false

    property int updateCount: 0
    property bool isHovered: updMouse.containsMouse

    radius: bar.s(14)
    border.width: 0
    color: "transparent"

    implicitHeight: bar.barHeight
    implicitWidth: updateCount === 0 ? 0 : updRow.width + bar.s(16)
    clip: true

    Behavior on implicitWidth { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }

    scale: updMouse.pressed ? 0.95 : (isHovered ? 1.04 : 1.0)
    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updFetch.running = true
    }

    Process {
        id: updFetch
        command: ["bash", "-c", "checkupdates 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.updateCount = parseInt(this.text.trim()) || 0
        }
    }

    Row {
        id: updRow
        anchors.centerIn: parent
        spacing: bar.s(5)

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
            text: "󰚰"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: bar.s(15)
            color: root.isHovered ? barZone.adaptiveText : barZone.adaptiveSubtext
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.updateCount
            font.family: "JetBrains Mono"
            font.pixelSize: bar.s(12)
            font.weight: Font.DemiBold
            color: barZone.adaptiveText
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    MouseArea {
        id: updMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.editMode
        onClicked: Quickshell.execDetached(["bash", "-c", "kitty --class update-term -e bash -c 'sudo pacman -Syu; read -p \"done — enter to close\"' & disown"])
    }
}
