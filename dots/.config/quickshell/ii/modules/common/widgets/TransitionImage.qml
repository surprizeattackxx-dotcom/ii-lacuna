import QtQuick
import Qt5Compat.GraphicalEffects
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

    property string transitionType: Config.options.background.transitionType ?? "radial"

    property int animationDuration: transitionType === "radial" ? 1100 : 1000
    property var fillMode: Image.PreserveAspectCrop
    property bool animated: true
    property bool imgAIsBack: true

    property var sourceSize: Qt.size(0, 0)
    property bool cache: false
    property bool antialiasing: true
    property bool asynchronous: true
    property bool smooth: true
    property bool mipmap: true

    property bool transitionActive: false
    property bool ready: false

    property bool imgAIsBack: true
    property Item backImg: imgAIsBack ? imgA : imgB
    property Item frontImg: imgAIsBack ? imgB : imgA

    property int status: (imgA.status === Image.Ready || imgB.status === Image.Ready) ? Image.Ready : frontImg.status

    Component.onCompleted: ready = true

    onImageSourceChanged: fadeTo(imageSource)

    property string currentWallpaper: ""

    function fadeTo(newSrc) {
        if (!newSrc || newSrc === currentWallpaper) return

        let hasWallpaper = (currentWallpaper !== "")

        front.source  = newSrc
        front.z       = 1
        back.z        = 0
        front.opacity = 0
        // Don't start the animation yet — onStatusChanged on the front image
        // will trigger it once the image is actually ready to display.
        // This prevents a crossfade over a blank/loading image, and keeps the
        // container opaque (back image visible) during the load.
    }

    function startTransition() {
        if (effectLoader.item && typeof effectLoader.item.start === "function") {
            effectLoader.item.start()
        } else {
            cleanupTransition()
        }
    }

    function cleanupTransition() {
        root.transitionActive = false
        if (effectLoader.item && typeof effectLoader.item.cleanup === "function") {
            effectLoader.item.cleanup()
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
