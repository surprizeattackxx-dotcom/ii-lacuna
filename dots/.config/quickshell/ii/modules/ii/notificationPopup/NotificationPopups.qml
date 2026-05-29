import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.ii.bar as Bar

PanelWindow {
    id: island
    anchors { top: true; right: true }
    margins { top: 200; right: 16 }

    implicitHeight: islandShape.height + 16
    implicitWidth: islandShape.width + 16
    color: "transparent"

    WlrLayershell.namespace: "qs-popups"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    Bar.MatugenColors { id: _theme }

    property var popupList: Notifications.popupList
    property var currentPopup: popupList.length > 0 ? popupList[0] : null
    property bool expanded: currentPopup !== null

    onCurrentPopupChanged: if (currentPopup) cycleTimer.restart()

    Timer {
        id: cycleTimer
        interval: 5000
        onTriggered: {
            if (popupList.length > 0) Notifications.discardNotification(popupList[0].notificationId)
        }
    }

    Rectangle {
        id: islandShape
        x: 8; y: 8
        width: expanded ? mainLayout.implicitWidth + 48 : 0
        height: expanded ? mainLayout.implicitHeight + 36 : 0
        radius: 18
        color: _theme.surface0
        clip: true

        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.5
            shadowOpacity: 0.35
            shadowVerticalOffset: 8
            shadowColor: "#000"
        }

        visible: width > 0

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            radius: 1.5
            color: _theme.blue
            anchors.leftMargin: 6
            anchors.topMargin: 12
            anchors.bottomMargin: 12
        }

        ColumnLayout {
            id: mainLayout
            x: 20; y: 18
            width: parent.width - 40
            spacing: 4
            visible: parent.width > 0

            RowLayout {
                id: topRow
                spacing: 12
                Layout.fillWidth: true

                Rectangle {
                    width: 24; height: 24; radius: 7
                    color: _theme.surface2
                    Image {
                        anchors.fill: parent; anchors.margins: 4
                        source: currentPopup ? "image://icon/" + currentPopup.appIcon : ""
                        sourceSize { width: 16; height: 16 }
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Text {
                    text: currentPopup ? (currentPopup.appName || "System") : ""
                    color: _theme.text
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Text {
                text: currentPopup && currentPopup.notification ? currentPopup.notification.summary || "" : ""
                color: _theme.text
                font.pixelSize: 12
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.maximumHeight: 36
                visible: text.length > 0
            }

            Text {
                text: currentPopup && currentPopup.notification ? currentPopup.notification.body || "" : ""
                color: _theme.subtext0
                font.pixelSize: 12
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.maximumHeight: 40
            }
        }
    }
}
