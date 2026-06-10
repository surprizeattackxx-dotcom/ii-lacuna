import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

Item {
    id: effect
    property Item frontImg
    property Item backImg
    property int duration

    property bool hideFront: true
    signal finished()

    property real progress: 0
    readonly property real pieRadius: Math.ceil(Math.sqrt(width * width + height * height) / 2) + 50

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
        layer.textureSize: Qt.size(Math.max(1, Math.round(width / 2)), Math.max(1, Math.round(height / 2)))
        width: effect.width
        height: effect.height
        visible: false
        layer.enabled: false

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillColor: "black"
                startX: effect.width / 2
                startY: effect.height / 2

                PathAngleArc {
                    centerX: effect.width / 2
                    centerY: effect.height / 2
                    radiusX: effect.pieRadius
                    radiusY: effect.pieRadius
                    startAngle: -90
                    sweepAngle: Math.min(effect.progress * 360, 359.99)
                }

                PathLine {
                    x: effect.width / 2
                    y: effect.height / 2
                }
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
