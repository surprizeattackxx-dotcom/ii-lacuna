import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    property string title
    property string icon: ""
    property string tooltip: ""
    property list<string> stringMap: []
    default property alias data: sectionContent.data

    Layout.fillWidth: true
    spacing: 6

    Timer {
        id: registerDelayTimer
        interval: 250
        onTriggered: {
            
        }
    }

    Component.onCompleted: {
        if (page?.register == false) return
        // console.log("KEYWORDS", root.stringMap)
        if (!page?.index) return
        SearchRegistry.registerSection({
            pageIndex: page?.index,
            title: root.title,
            searchStrings: root.stringMap.slice(),
            yPos: root.y
        })
    }

    function addKeyword(word) {
        if (!word) return
        // console.log("ADD KEYWORD", word)
        stringMap.push(word)
    }

    

    RowLayout {
        spacing: 6
        OptionalMaterialSymbol {
            icon: root.icon
            iconSize: Appearance.font.pixelSize.hugeass
        }
        StyledText {
            text: root.title
            font.pixelSize: Appearance.font.pixelSize.larger
            font.weight: Font.Medium
            color: Appearance.colors.colOnSecondaryContainer
        }
        MaterialSymbol {
            visible: root.tooltip && root.tooltip.length > 0
            text: "info"
            iconSize: Appearance.font.pixelSize.larger
            
            color: Appearance.colors.colOnSecondaryContainer
            MouseArea {
                id: infoMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.WhatsThisCursor
                StyledToolTip {
                    extraVisibleCondition: false
                    alternativeVisibleCondition: infoMouseArea.containsMouse
                    text: root.tooltip
                }
            }
        }
    }

    ColumnLayout {
        id: sectionContent
        Layout.fillWidth: true
        spacing: 4

    }
}
