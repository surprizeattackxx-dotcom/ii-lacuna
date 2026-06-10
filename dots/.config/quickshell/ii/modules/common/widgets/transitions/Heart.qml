import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: effect
    property Item frontImg
    property Item backImg
    property int duration

    property bool hideFront: true
    signal finished()

    // Distance from center to the notch between the lobes at base size — the
    // largest circle the filled heart fully covers. Drives the end scale.
    readonly property real coverageRadius: 140

    function start() {
        maskContainer.layer.enabled = true

        let d = Math.sqrt(effect.width * effect.width + effect.height * effect.height) / 2
        let targetScale = (d / effect.coverageRadius) * 1.08

        heartMask.scale = 0
        wipeMask.visible = true

        revealAnim.from = 0
        revealAnim.to = targetScale
        revealAnim.restart()
    }

    function cleanup() {
        wipeMask.visible = false
        heartMask.scale = 0
        maskContainer.layer.enabled = false
    }

    NumberAnimation {
        id: revealAnim
        target: heartMask
        property: "scale"
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

        Image {
            id: heartMask
            width: 800
            height: 800
            sourceSize: Qt.size(800, 800)
            x: effect.width / 2 - width / 2
            y: effect.height / 2 - height / 2
            scale: 0
            transformOrigin: Item.Center
            source: "data:image/svg+xml;utf8,<svg width='800' height='800' xmlns='http://www.w3.org/2000/svg'><path d='M400,720 C80,480 80,240 240,160 C340,110 400,180 400,260 C400,180 460,110 560,160 C720,240 720,480 400,720 Z' fill='black'/></svg>"
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
