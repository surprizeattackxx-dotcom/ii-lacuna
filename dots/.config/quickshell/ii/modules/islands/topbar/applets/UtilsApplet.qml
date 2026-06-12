import QtQuick
import QtQuick.Effects
import Quickshell

Rectangle {
    id: root
    property var bar
    property var barZone
    property bool editMode: false

    radius: bar.s(14)
    border.width: 0
    color: "transparent"

    implicitHeight: bar.barHeight
    implicitWidth: utilRow.width + bar.s(16)
    clip: true

    component UtilButton: Item {
        property string icon
        property var action
        property alias hovered: btnMouse.containsMouse

        width: btnText.width + root.bar.s(8)
        height: root.bar.barHeight

        scale: btnMouse.pressed ? 0.9 : (hovered ? 1.1 : 1.0)
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        Text {
            id: btnText
            anchors.centerIn: parent
            text: parent.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: root.bar.s(15)
            color: parent.hovered ? root.barZone.adaptiveText : root.barZone.adaptiveSubtext
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.editMode
            onClicked: parent.action()
        }
    }

    Row {
        id: utilRow
        anchors.centerIn: parent
        spacing: root.bar.s(2)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }

        UtilButton {
            icon: "󰹑"
            action: () => Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "region", "screenshot"])
        }
        UtilButton {
            icon: "󰈊"
            action: () => Quickshell.execDetached(["hyprpicker", "-a"])
        }
        UtilButton {
            icon: "󰌌"
            action: () => Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "osk", "toggle"])
        }
    }
}
