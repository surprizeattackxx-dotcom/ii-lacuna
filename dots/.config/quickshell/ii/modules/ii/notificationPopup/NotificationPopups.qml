import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.ii.bar as Bar

PanelWindow {
    id: island
    anchors { top: true; right: true }
    margins { top: 200; right: 16 }
    color: "transparent"

    implicitWidth: islandShape.width + 24
    implicitHeight: islandShape.height + 24

    WlrLayershell.namespace: "qs-popups"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    Bar.MatugenColors { id: _theme }

    property var popupList: Notifications.popupList
    property var currentPopup: popupList.length > 0 ? popupList[0] : null
    property var notif: currentPopup ? currentPopup.notification : null
    property bool expanded: currentPopup !== null

    readonly property real expandedWidth: 380
    readonly property real expandedHeight: 92

    Item {
        id: islandShape
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 12

        width: expanded ? expandedWidth : 0
        height: expanded ? expandedHeight : 0

        Behavior on width  { NumberAnimation { duration: 380; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 1, 0.3, 1] } }
        Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 1, 0.3, 1] } }

        Rectangle {
            id: islandBg
            anchors.fill: parent
            radius: height / 2
            clip: true
            visible: width > 1
            color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 0.95)
            border.width: 1
            border.color: Qt.rgba(_theme.mauve.r, _theme.mauve.g, _theme.mauve.b, 0.4)

            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowBlur: 1.0
                shadowOpacity: 0.45
                shadowVerticalOffset: 8
            }

            Item {
                id: expandedContent
                anchors.fill: parent
                anchors.margins: 12
                opacity: expanded ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }

                transform: Translate {
                    y: expanded ? 0 : 10
                    Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                }

                Rectangle {
                    id: iconContainer
                    width: 48; height: 48; radius: 12
                    color: _theme.surface0
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: appIcon
                        anchors.fill: parent; anchors.margins: 4
                        source: currentPopup && currentPopup.appIcon ? "image://icon/" + currentPopup.appIcon : ""
                        sourceSize { width: 40; height: 40 }
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "notifications"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 24
                        color: _theme.mauve
                        visible: appIcon.status !== Image.Ready
                    }
                }

                Column {
                    anchors.left: iconContainer.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: currentPopup ? (currentPopup.appName || "System") : ""
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: _theme.overlay1
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: notif ? (notif.summary || "") : ""
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: _theme.text
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                    Text {
                        width: parent.width
                        text: notif ? (notif.body || "") : ""
                        font.pixelSize: 12
                        color: _theme.subtext0
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        visible: text.length > 0
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: expanded
            onClicked: if (currentPopup) Notifications.timeoutNotification(currentPopup.notificationId)
        }
    }
}
