pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: root
    required property var clientDimensions

    property color colBackground: Qt.rgba(0.1, 0.1, 0.1, 0.9)
    property color colForeground: Qt.rgba(1, 1, 1, 0.87)
    property bool showLabel: true
    property bool showIcon: false
    property bool targeted: false
    property color borderColor
    property color fillColor: "transparent"
    property string text: ""
    property real textPadding: 10
    z: 2
    color: fillColor
    border.color: borderColor
    border.width: targeted ? 4 : 2
    radius: 4

    visible: opacity > 0
    x: clientDimensions.at[0]
    y: clientDimensions.at[1]
    width: clientDimensions.size[0]
    height: clientDimensions.size[1]

    Loader {
        anchors {
            top: parent.top
            left: parent.left
            topMargin: root.textPadding
            leftMargin: root.textPadding
        }
        
        active: root.showLabel
        sourceComponent: Rectangle {
            property real verticalPadding: 5
            property real horizontalPadding: 10
            radius: 10
            color: root.colBackground
            border.width: 1
            border.color: Style.accentColor
            implicitWidth: regionInfoRow.implicitWidth + horizontalPadding * 2
            implicitHeight: regionInfoRow.implicitHeight + verticalPadding * 2

            Row {
                id: regionInfoRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    id: regionText
                    text: root.text
                    color: root.colForeground
                }
            }
        }
    }
}