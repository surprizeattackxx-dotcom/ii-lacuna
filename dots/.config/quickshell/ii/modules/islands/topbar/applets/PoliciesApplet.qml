import QtQuick
import QtQuick.Effects
import Quickshell

Rectangle {
    id: root
    property var bar
    property var barZone
    property bool editMode: false

    property bool isHovered: polMouse.containsMouse

    radius: bar.s(14)
    border.width: 0
    color: "transparent"

    implicitHeight: bar.barHeight
    implicitWidth: polIcon.width + bar.s(16)
    clip: true

    scale: polMouse.pressed ? 0.95 : (isHovered ? 1.04 : 1.0)
    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    Text {
        id: polIcon
        anchors.centerIn: parent
        text: "󰍜"
        font.family: "Iosevka Nerd Font"
        font.pixelSize: bar.s(17)
        color: root.isHovered ? barZone.adaptiveText : barZone.adaptiveSubtext
        Behavior on color { ColorAnimation { duration: 200 } }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }
    }

    MouseArea {
        id: polMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.editMode
        onClicked: Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "sidebarLeft", "toggle"])
    }
}
