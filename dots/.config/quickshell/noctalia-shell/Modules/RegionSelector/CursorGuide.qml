pragma ComponentBehavior: Bound
import qs.Commons
import QtQuick

Item {
    id: root
    property int action: 0
    property int selectionMode: 0

    property string description: {
        switch (root.action) {
        case 0: return "Copy region";
        case 1: return "Edit region";
        case 2: return "Search with image";
        case 3: return "Recognize text";
        case 4: return "Record region";
        case 5: return "Record with sound";
        default: return "";
        }
    }
    property string materialSymbol: {
        switch (root.action) {
        case 0:
        case 1: return "content_cut";
        case 2: return "image_search";
        case 3: return "document_scanner";
        case 4:
        case 5: return "videocam";
        default: return "";
        }
    }

    property bool showDescription: true
    function hideDescription() {
        root.showDescription = false
    }
    Timer {
        id: descTimeout
        interval: 1000
        running: true
        onTriggered: {
            root.hideDescription()
        }
    }
    onActionChanged: {
        root.showDescription = true
        descTimeout.restart()
    }

    property int margins: 8
    implicitWidth: content.implicitWidth + margins * 2
    implicitHeight: content.implicitHeight + margins * 2

    Rectangle {
        id: content
        anchors.centerIn: parent

        property real padding: 8
        implicitHeight: 38
        implicitWidth: root.showDescription ? contentRow.implicitWidth + padding * 2 : implicitHeight
        clip: true

        radius: 6
        color: Style.accentColor

        Row {
            id: contentRow
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: content.padding
            }
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.materialSymbol
                color: Style.textOnAccent
                font.pointSize: 16
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.description
                color: Style.textOnAccent
                visible: root.showDescription
                rightPadding: 6
            }
        }
    }
}
