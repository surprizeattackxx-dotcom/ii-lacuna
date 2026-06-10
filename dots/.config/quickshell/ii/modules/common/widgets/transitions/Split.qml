import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: effect
    property Item frontImg
    property Item backImg
    property int duration

    property bool hideFront: true
    signal finished()

    function start() {
        maskContainer.layer.enabled = true
        splitRect.width = 0
        wipeMask.visible = true

        revealAnim.from = 0
        revealAnim.to = effect.width + 2
        revealAnim.restart()
    }

    function cleanup() {
        wipeMask.visible = false
        splitRect.width = 0
        maskContainer.layer.enabled = false
    }

    NumberAnimation {
        id: revealAnim
        target: splitRect
        property: "width"
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

        Rectangle {
            id: splitRect
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            height: effect.height
            width: 0
            color: "black"
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
