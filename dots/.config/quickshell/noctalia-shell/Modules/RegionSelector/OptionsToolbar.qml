pragma ComponentBehavior: Bound
import qs.Commons
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property int action: 0
    property int selectionMode: 0
    signal dismiss()

    color: Style.backgroundColor
    border.color: Style.accentColor
    border.width: 1
    radius: 6
    
    implicitWidth: layout.implicitWidth + 16
    implicitHeight: layout.implicitHeight + 16

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8

        Button {
            text: "Rectangle"
            Layout.preferredWidth: 80
            highlighted: root.selectionMode === 0
            onClicked: root.selectionMode = 0
        }

        Button {
            text: "Circle"
            Layout.preferredWidth: 80
            highlighted: root.selectionMode === 1
            onClicked: root.selectionMode = 1
        }

        Button {
            text: "Done"
            Layout.preferredWidth: 60
            onClicked: root.dismiss()
        }
    }
}
