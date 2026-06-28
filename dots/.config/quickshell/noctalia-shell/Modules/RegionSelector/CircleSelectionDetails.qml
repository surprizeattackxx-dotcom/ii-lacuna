pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Item {
    id: root
    required property color color
    required property color overlayColor
    required property list<point> points
    property int strokeWidth: 2

    Rectangle {
        id: darkenOverlay
        z: 1
        anchors.fill: parent
        color: root.overlayColor
    }

    Shape {
        id: shape
        z: 2
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true

        ShapePath {
            id: shapePath
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            strokeColor: root.color
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root.points
            }
        }
    }
}
