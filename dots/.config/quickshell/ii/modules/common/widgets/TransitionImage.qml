import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    // Ready if EITHER image is loaded — prevents the container going transparent
    // during a wallpaper change (which would expose the swww layer and cause a
    // double-transition visual artefact).
    readonly property int status: (imgA.status === Image.Ready || imgB.status === Image.Ready)
        ? Image.Ready
        : (imgAIsBack ? imgB.status : imgA.status)
    required property string imageSource

    property int animationDuration: 1000
    property var fillMode: Image.PreserveAspectCrop
    property bool animated: true
    property bool imgAIsBack: true

    property var sourceSize: Qt.size(0, 0)
    property bool cache: false
    property bool antialiasing: true
    property bool asynchronous: true
    property bool smooth: true
    property bool mipmap: true

    onImageSourceChanged: fadeTo(imageSource)
    Component.onCompleted: imgA.source = imageSource

    function fadeTo(newSrc) {
        var back  = imgAIsBack ? imgA : imgB
        var front = imgAIsBack ? imgB : imgA

        if (newSrc === back.source) return

        front.source  = newSrc
        front.z       = 1
        back.z        = 0
        front.opacity = 0
        // Don't start the animation yet — onStatusChanged on the front image
        // will trigger it once the image is actually ready to display.
        // This prevents a crossfade over a blank/loading image, and keeps the
        // container opaque (back image visible) during the load.
    }

    NumberAnimation {
        id: fadeAnim
        property: "opacity"
        from: 0; to: 1
        duration: root.animationDuration
        easing.type: Easing.InOutQuad

        onFinished: {
            root.imgAIsBack = !root.imgAIsBack
        }
    }

    Image {
        id: imgA
        anchors.fill: parent
        fillMode: root.fillMode
        sourceSize: root.sourceSize
        cache: root.cache; antialiasing: root.antialiasing; asynchronous: root.asynchronous; smooth: root.smooth; mipmap: root.mipmap
        onStatusChanged: {
            if (status !== Image.Ready) return
            // imgA is "front" when imgAIsBack is false
            if (!root.imgAIsBack && imgA.opacity === 0) {
                if (root.animated) {
                    fadeAnim.target = imgA
                    fadeAnim.restart()
                } else {
                    imgA.opacity = 1
                    root.imgAIsBack = !root.imgAIsBack
                }
            }
        }
    }

    Image {
        id: imgB
        anchors.fill: parent
        opacity: 0
        fillMode: root.fillMode
        sourceSize: root.sourceSize
        cache: root.cache; antialiasing: root.antialiasing; asynchronous: root.asynchronous; smooth: root.smooth; mipmap: root.mipmap
        onStatusChanged: {
            if (status !== Image.Ready) return
            // imgB is "front" when imgAIsBack is true
            if (root.imgAIsBack && imgB.opacity === 0) {
                if (root.animated) {
                    fadeAnim.target = imgB
                    fadeAnim.restart()
                } else {
                    imgB.opacity = 1
                    root.imgAIsBack = !root.imgAIsBack
                }
            }
        }
    }
}
