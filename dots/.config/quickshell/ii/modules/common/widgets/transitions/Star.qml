import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: effect
    property Item frontImg
    property Item backImg
    property int duration

    property bool hideFront: true
    signal finished()

    // Distance from center to the star's inner vertices at base size — the
    // largest circle the filled star fully covers. Drives the end scale.
    readonly property real coverageRadius: 145

    function start() {
        maskContainer.layer.enabled = true

        let d = Math.sqrt(effect.width * effect.width + effect.height * effect.height) / 2
        let targetScale = (d / effect.coverageRadius) * 1.05

        starMask.scale = 0
        wipeMask.visible = true

        revealAnim.from = 0
        revealAnim.to = targetScale
        revealAnim.restart()
    }

    function cleanup() {
        wipeMask.visible = false
        starMask.scale = 0
        maskContainer.layer.enabled = false
    }

    NumberAnimation {
        id: revealAnim
        target: starMask
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
            id: starMask
            width: 800
            height: 800
            sourceSize: Qt.size(800, 800)
            x: effect.width / 2 - width / 2
            y: effect.height / 2 - height / 2
            scale: 0
            rotation: 18
            transformOrigin: Item.Center
            source: "data:image/svg+xml;utf8,<svg width='800' height='800' xmlns='http://www.w3.org/2000/svg'><polygon points='400,20 485.3,282.5 761.4,282.6 538.1,444.9 623.4,707.4 400,545.2 176.6,707.4 261.9,444.9 38.6,282.6 314.7,282.5' fill='black'/></svg>"
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
