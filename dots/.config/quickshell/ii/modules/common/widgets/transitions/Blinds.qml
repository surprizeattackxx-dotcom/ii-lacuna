import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: effect
    property Item frontImg
    property Item backImg
    property int duration

    property bool hideFront: true
    signal finished()

    property real progress: 0
    readonly property int stripCount: 12

    function start() {
        maskContainer.layer.enabled = true
        effect.progress = 0
        wipeMask.visible = true
        revealAnim.restart()
    }

    function cleanup() {
        wipeMask.visible = false
        effect.progress = 0
        maskContainer.layer.enabled = false
    }

    NumberAnimation {
        id: revealAnim
        target: effect
        property: "progress"
        from: 0
        to: 1
        duration: effect.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.227, 0.877, 0.959, 0.310, 1.0, 1.0]
        onFinished: effect.finished()
    }

    Item {
        id: maskContainer
        width: effect.width
        height: effect.height
        visible: false
        layer.enabled: false

        Repeater {
            model: effect.stripCount
            Rectangle {
                required property int index
                readonly property real stripW: effect.width / effect.stripCount
                x: index * stripW
                y: 0
                height: effect.height
                width: stripW * effect.progress + (effect.progress >= 1 ? 1 : 0)
                color: "black"
            }
        }
    }

    OpacityMask {
        id: wipeMask
        anchors.fill: parent
        visible: false
        source: effect.frontImg
        maskSource: maskContainer
    }
}
