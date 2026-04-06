import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: heroCardRoot

    Layout.fillWidth: true
    Layout.minimumWidth: 320
    implicitWidth: heroRow.implicitWidth + margins * 2
    implicitHeight: heroRow.implicitHeight + margins * 2

    radius: Appearance.rounding.normal
    color: containerColor

    property int margins: 24
    property int iconSize: 110
    property string shapeString: "Cookie9Sided"
    property string icon: ""
    property real iconFontSize: 48
    property color containerColor: Appearance.colors.colPrimaryContainer
    property color shapeColor: Appearance.colors.colPrimary
    property color onShapeColor: Appearance.colors.colOnPrimaryContainer
    property color textColor: Appearance.colors.colOnPrimaryContainer

    default property alias content: contentColumn.children
    property alias shapeContent: shapeItem.data

    RowLayout {
        id: heroRow
        anchors.fill: parent
        anchors.margins: heroCardRoot.margins
        spacing: 20

        MaterialShape {
            id: shapeItem
            shapeString: heroCardRoot.shapeString
            implicitSize: heroCardRoot.iconSize
            color: heroCardRoot.shapeColor

            MaterialSymbol {
                id: iconSymbol
                visible: heroCardRoot.icon !== "" && shapeItem.children.length <= 1
                anchors.centerIn: parent
                text: heroCardRoot.icon
                iconSize: heroCardRoot.iconFontSize
                color: heroCardRoot.onShapeColor
            }
        }

        Item {
            Layout.fillWidth: true
        }

        ColumnLayout {
            id: contentColumn
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: -2
        }
    }
}
