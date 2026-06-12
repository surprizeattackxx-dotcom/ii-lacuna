import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects
import qs.modules.ii.bar as Bar

Column {
    id: root
    readonly property int maxShown: 5
    readonly property var shownNotifs: Notifications.popupList.slice(0, maxShown)
    readonly property int hiddenCount: Notifications.popupList.length - shownNotifs.length

    width: 380
    spacing: 10

    Bar.MatugenColors { id: _theme }

    move: Transition {
        NumberAnimation { property: "y"; duration: 250; easing.type: Easing.OutCubic }
    }

    Repeater {
        model: root.shownNotifs

        delegate: Item {
            id: card
            required property var modelData
            width: root.width
            height: 92
            property bool dismissing: false

            Rectangle {
                id: cardBg
                width: card.width
                height: card.height
                radius: height / 2
                clip: true
                color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 0.95)
                border.width: 1
                border.color: card.modelData.urgency === "critical"
                    ? Qt.rgba(_theme.red.r, _theme.red.g, _theme.red.b, 0.6)
                    : Qt.rgba(_theme.mauve.r, _theme.mauve.g, _theme.mauve.b, 0.4)
                opacity: 1 - Math.abs(x) / card.width

                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowBlur: 1.0
                    shadowOpacity: 0.45
                    shadowVerticalOffset: 8
                }

                Behavior on x {
                    enabled: !swipeArea.drag.active
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 12

                    Rectangle {
                        id: iconContainer
                        width: 48; height: 48; radius: 12
                        color: _theme.surface0
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: appIconImage
                            anchors.fill: parent; anchors.margins: 4
                            source: card.modelData.appIcon.length > 0 ? "image://icon/" + card.modelData.appIcon : ""
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
                            visible: appIconImage.status !== Image.Ready
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
                            text: card.modelData.appName || "System"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: _theme.overlay1
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: card.modelData.summary
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: _theme.text
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                        Text {
                            width: parent.width
                            text: card.modelData.body
                            font.pixelSize: 12
                            color: _theme.subtext0
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            visible: text.length > 0
                        }
                    }
                }

                MouseArea {
                    id: swipeArea
                    anchors.fill: parent
                    drag.target: cardBg
                    drag.axis: Drag.XAxis
                    enabled: !card.dismissing
                    onReleased: {
                        if (Math.abs(cardBg.x) > card.width * 0.3) {
                            card.dismissing = true
                            dismissAnim.targetX = cardBg.x > 0 ? card.width : -card.width
                            dismissAnim.start()
                        } else {
                            cardBg.x = 0
                        }
                    }
                }

                SequentialAnimation {
                    id: dismissAnim
                    property real targetX: 0
                    NumberAnimation {
                        target: cardBg
                        property: "x"
                        to: dismissAnim.targetX
                        duration: 150
                        easing.type: Easing.InCubic
                    }
                    ScriptAction {
                        script: Notifications.timeoutNotification(card.modelData.notificationId)
                    }
                }
            }
        }
    }

    Text {
        anchors.right: parent.right
        text: Translation.tr("+%1 more").arg(root.hiddenCount)
        font.pixelSize: 11
        font.weight: Font.Medium
        color: _theme.overlay1
        visible: root.hiddenCount > 0
    }
}
