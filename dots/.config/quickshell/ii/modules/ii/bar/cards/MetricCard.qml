import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    radius: Appearance.rounding.large
    color: Appearance.colors.colSurfaceContainerHigh
    implicitWidth: rowLayout.implicitWidth + (compact ? 16 : 24)
    implicitHeight: rowLayout.implicitHeight + (compact ? 14 : 20)
    Layout.fillWidth: true

    property alias title: title.text
    property alias value: value.text
    property alias symbol: symbol.text
    property string shapeString: "Slanted"
    property color accentColor: Appearance.colors.colPrimaryContainer
    property color onAccentColor: Appearance.colors.colOnPrimaryContainer
    property bool compact: false

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: compact ? 8 : 12

        MaterialShape {
            shapeString: root.shapeString
            implicitSize: compact ? 30 : 36
            color: root.accentColor

            MaterialSymbol {
                id: symbol
                anchors.centerIn: parent
                fill: 0
                iconSize: Appearance.font.pixelSize.normal
                color: root.onAccentColor
            }
        }

        ColumnLayout {
            spacing: -2
            StyledText {
                id: title
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
                font.weight: Font.DemiBold
            }
            StyledText {
                id: value
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurface
                font.weight: Font.Bold
            }
            Item {
                Layout.fillWidth: true
            }
        }
    }
}
