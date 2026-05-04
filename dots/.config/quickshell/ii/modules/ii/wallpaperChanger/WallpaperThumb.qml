import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell

Item {
    id: root

    required property string thumbPath
    required property int thumbIndex
    property bool selected: false
    property bool revealing: false
    property bool isWpe: false
    // If set, load this path directly (used for WPE preview.jpg) instead of ThumbnailImage
    property string directThumbPath: ""

    signal clicked()
    signal doubleClicked()

    Rectangle {
        id: container
        anchors.fill: parent
        anchors.margins: 2
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        clip: true

        border.color: root.selected ? Appearance.colors.colAccent : "transparent"
        border.width: 2
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Base thumbnail
        Loader {
            id: baseLoader
            anchors.fill: parent
            sourceComponent: root.directThumbPath.length > 0 ? directImg : thumbnailImg
        }
        Component {
            id: thumbnailImg
            ThumbnailImage {
                sourcePath: root.thumbPath
                fillMode: Image.PreserveAspectCrop
            }
        }
        Component {
            id: directImg
            Image {
                id: wpeBaseImg
                property int fallbackIdx: 0
                property var tryList: {
                    const base = root.directThumbPath.replace(/\/[^/]*$/, "")
                    return [root.directThumbPath, base + "/preview.png", base + "/preview.gif"]
                }
                source: tryList[fallbackIdx] ? ("file://" + tryList[fallbackIdx]) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                onStatusChanged: {
                    if (status === Image.Error && fallbackIdx < tryList.length - 1)
                        fallbackIdx++
                }
            }
        }

        // Circle-out reveal layer
        Item {
            id: revealLayer
            anchors.fill: parent
            visible: false

            Loader {
                id: revealLoader
                anchors.fill: parent
                sourceComponent: root.directThumbPath.length > 0 ? revealDirectImg : revealThumbnailImg
                layer.enabled: revealLayer.visible
                layer.effect: OpacityMask {
                    maskSource: Item {
                        width: revealLoader.width
                        height: revealLoader.height
                        Rectangle {
                            id: circleMask
                            property real cr: 0
                            anchors.centerIn: parent
                            width: cr * 2
                            height: cr * 2
                            radius: cr
                            color: "white"
                        }
                    }
                }
            }
            Component {
                id: revealThumbnailImg
                ThumbnailImage {
                    sourcePath: root.thumbPath
                    fillMode: Image.PreserveAspectCrop
                }
            }
            Component {
                id: revealDirectImg
                Image {
                    id: wpeRevealImg
                    property int fallbackIdx: 0
                    property var tryList: {
                        const base = root.directThumbPath.replace(/\/[^/]*$/, "")
                        return [root.directThumbPath, base + "/preview.png", base + "/preview.gif"]
                    }
                    source: tryList[fallbackIdx] ? ("file://" + tryList[fallbackIdx]) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    onStatusChanged: {
                        if (status === Image.Error && fallbackIdx < tryList.length - 1)
                            fallbackIdx++
                    }
                }
            }
        }

        // Hover highlight
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: root.clicked()
            onDoubleClicked: root.doubleClicked()

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(1, 1, 1, mouseArea.containsMouse ? 0.07 : 0)
                radius: container.radius
                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }

        // WPE badge
        Rectangle {
            visible: root.isWpe
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 5
            anchors.leftMargin: 5
            width: wpeLabel.implicitWidth + 8
            height: wpeLabel.implicitHeight + 4
            radius: 4
            color: Qt.rgba(0.1, 0.1, 0.6, 0.85)

            StyledText {
                id: wpeLabel
                anchors.centerIn: parent
                text: "WPE"
                font.pixelSize: Appearance.font.pixelSize.small - 1
                font.weight: Font.Bold
                color: "white"
            }
        }

        // Selected dot
        Rectangle {
            visible: root.selected
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 6
            width: 8; height: 8; radius: 4
            color: Appearance.colors.colAccent
        }
    }

    onRevealingChanged: {
        if (revealing) {
            circleMask.cr = 0
            revealLayer.visible = true
            circleAnim.restart()
        }
    }

    NumberAnimation {
        id: circleAnim
        target: circleMask
        property: "cr"
        from: 0
        to: {
            const w = container.width
            const h = container.height
            return Math.sqrt(w * w + h * h) / 2 + 2
        }
        duration: 480
        easing.type: Easing.OutCubic
        onFinished: revealLayer.visible = false
    }
}
