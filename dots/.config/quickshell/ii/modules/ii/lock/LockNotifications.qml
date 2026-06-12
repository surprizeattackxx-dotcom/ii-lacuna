import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick

Column {
    id: root
    readonly property int maxShown: 5
    readonly property var shownNotifs: Notifications.popupList.slice(0, maxShown)
    readonly property int hiddenCount: Notifications.popupList.length - shownNotifs.length

    width: 380
    spacing: 8

    move: Transition {
        NumberAnimation { property: "y"; duration: 250; easing.type: Easing.OutCubic }
    }

    Repeater {
        model: root.shownNotifs

        delegate: Item {
            id: card
            required property var modelData
            width: root.width
            height: cardBg.height
            property bool dismissing: false

            Rectangle {
                id: cardBg
                width: card.width
                height: contentRow.implicitHeight + 24
                radius: Appearance.rounding.normal
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.1)
                border.width: 1
                border.color: card.modelData.urgency === "critical"
                    ? Appearance.colors.colError
                    : Appearance.colors.colLayer0Border
                opacity: 1 - Math.abs(x) / card.width

                Behavior on x {
                    enabled: !swipeArea.drag.active
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                Row {
                    id: contentRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 12

                    Rectangle {
                        id: iconContainer
                        anchors.verticalCenter: parent.verticalCenter
                        width: 42
                        height: 42
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1

                        Image {
                            id: appIconImage
                            anchors.fill: parent
                            anchors.margins: 4
                            source: card.modelData.appIcon.length > 0 ? "image://icon/" + card.modelData.appIcon : ""
                            sourceSize { width: 36; height: 36 }
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "notifications"
                            iconSize: 24
                            color: Appearance.colors.colOnLayer1
                            visible: appIconImage.status !== Image.Ready
                        }
                    }

                    Column {
                        width: contentRow.width - iconContainer.width - contentRow.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            width: parent.width
                            text: card.modelData.appName
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                        StyledText {
                            width: parent.width
                            text: card.modelData.summary
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                        StyledText {
                            width: parent.width
                            text: card.modelData.body
                            textFormat: Text.StyledText
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 3
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

    StyledText {
        anchors.right: parent.right
        text: Translation.tr("+%1 more").arg(root.hiddenCount)
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: ColorUtils.transparentize("#ffffff", 0.3)
        style: Text.Raised
        styleColor: ColorUtils.transparentize("#000000", 0.6)
        visible: root.hiddenCount > 0
    }
}
