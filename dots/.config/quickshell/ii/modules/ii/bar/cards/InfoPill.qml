import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: 64
    radius: 32

    color: Appearance.colors.colSecondaryContainer

    property string shapeString: "Circle"
    property int shapeSize: 40
    property color containerColor: Appearance.colors.colSecondaryContainer
    property color shapeColor: Appearance.colors.colSecondary
    property color onShapeColor: Appearance.colors.colOnSecondary
    property color textColor: Appearance.colors.colOnSecondaryContainer

    default property alias shapeContent: shapeItem.children
    property alias text: pillText.text

    RowLayout {
        anchors.centerIn: parent
        spacing: 12

        MaterialShape {
            id: shapeItem
            shapeString: root.shapeString
            implicitSize: root.shapeSize
            color: root.shapeColor
        }

        StyledText {
            id: pillText
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            font.weight: Font.Bold
            color: root.textColor
        }

        Item {
            width: 8
        }
    }
}
