import QtQuick
import qs.modules.common

Item {
    id: poof

    readonly property real cellSize: Appearance.sizes.dockButtonSize
    property real progress: 0

    width: cellSize * 1.8
    height: cellSize * 1.8
    visible: false

    function burst(centerX, centerY) {
        poof.x = centerX - width / 2
        poof.y = centerY - height / 2
        poof.progress = 0
        poof.visible = true
        anim.restart()
    }

    Rectangle {
        anchors.centerIn: parent
        width: poof.cellSize * (0.5 + poof.progress * 0.9)
        height: width
        radius: width / 2
        color: Appearance.colors.colOnLayer0
        opacity: (1.0 - poof.progress) * 0.25
    }

    Repeater {
        model: 7
        delegate: Rectangle {
            required property int index
            readonly property real ang: index / 7 * 2 * Math.PI
            readonly property real dist: poof.progress * poof.cellSize * 0.95
            width: poof.cellSize * 0.22 * (1.0 - poof.progress * 0.6)
            height: width
            radius: width / 2
            color: Appearance.colors.colOnLayer0
            opacity: 1.0 - poof.progress
            x: poof.width / 2 - width / 2 + Math.cos(ang) * dist
            y: poof.height / 2 - height / 2 + Math.sin(ang) * dist
        }
    }

    SequentialAnimation {
        id: anim
        NumberAnimation { target: poof; property: "progress"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
        ScriptAction { script: poof.visible = false }
    }
}
