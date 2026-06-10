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
    readonly property int cols: 10
    readonly property int rows: 6
    // Fraction of the timeline each cell spends growing; the rest is stagger budget
    readonly property real cellWindow: 0.45

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
            model: effect.cols * effect.rows
            Rectangle {
                required property int index
                readonly property int col: index % effect.cols
                readonly property int row: Math.floor(index / effect.cols)
                readonly property real cellW: effect.width / effect.cols
                readonly property real cellH: effect.height / effect.rows
                // Checkerboard parity first, then a diagonal sweep within each parity group
                readonly property real delay: ((col + row) % 2) * 0.18
                    + ((col + row) / (effect.cols + effect.rows)) * (1 - effect.cellWindow - 0.18)
                readonly property real cellScale: Math.max(0, Math.min(1, (effect.progress - delay) / effect.cellWindow))
                width: cellW * cellScale + (cellScale >= 1 ? 1 : 0)
                height: cellH * cellScale + (cellScale >= 1 ? 1 : 0)
                x: col * cellW + (cellW - width) / 2
                y: row * cellH + (cellH - height) / 2
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
