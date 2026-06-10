import QtQuick
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property string imageSource

    property string transitionType: Config.options.background.transitionType ?? "radial"

    // "random" rolls a new shape from the pool on every wallpaper change
    readonly property var randomPool: ["crossfade", "radial", "outer", "wipe", "slash", "diamond", "wave", "split", "blinds", "checker", "clock", "star", "heart"]
    property string randomChoice: "radial"
    readonly property string effectiveType: transitionType === "random" ? randomChoice : transitionType

    property int animationDuration: effectiveType === "radial" ? 1100 : 1000
    property var fillMode: Image.PreserveAspectCrop
    property bool animated: Config.options.background.animateWallpaperChanges

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

    // Ready if EITHER image is loaded — keeps the container opaque during a
    // wallpaper change, so the swww layer underneath never flashes through.
    readonly property int status: (backImg.status === Image.Ready || frontImg.status === Image.Ready)
        ? Image.Ready
        : frontImg.status

    Component.onCompleted: ready = true

    onImageSourceChanged: fadeTo(imageSource)

    function fadeTo(newSrc) {
        if (!newSrc || newSrc === backImg.source) return

        if (root.transitionType === "random") {
            root.randomChoice = randomPool[Math.floor(Math.random() * randomPool.length)]
        }

        if (root.animated && ready && root.width > 0 && root.height > 0) {
            cleanupTransition()

            // Flip AT THE START so frontImg is ALWAYS the new image with z=1
            root.imgAIsBack = !root.imgAIsBack

            root.transitionActive = true
            frontImg.source = newSrc

            let wait = effectLoader.item ? effectLoader.item.waitForReady !== false : true

            if (!wait || frontImg.status === Image.Ready) {
                startTransition()
            }
        } else {
            cleanupTransition()
            root.imgAIsBack = !root.imgAIsBack
            frontImg.source = newSrc
            root.transitionActive = false
        }
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

    AnimatedImage {
        id: imgA
        anchors.fill: parent
        visible: root.imgAIsBack || (!root.transitionActive || !effectLoader.item || effectLoader.item.hideFront === false)
        layer.enabled: !visible && root.transitionActive
        z: root.imgAIsBack ? 0 : 1

        fillMode: root.fillMode
        sourceSize: root.sourceSize
        cache: root.cache; antialiasing: root.antialiasing; asynchronous: root.asynchronous; smooth: root.smooth; mipmap: root.mipmap
        playing: visible

        onStatusChanged: {
            let wait = effectLoader.item ? effectLoader.item.waitForReady !== false : true
            if (wait) {
                if (status === Image.Ready && root.transitionActive && !root.imgAIsBack) {
                    root.startTransition()
                } else if (status === Image.Error && root.transitionActive && !root.imgAIsBack) {
                    root.cleanupTransition()
                }
            }
        }
    }

    AnimatedImage {
        id: imgB
        anchors.fill: parent
        visible: !root.imgAIsBack || (!root.transitionActive || !effectLoader.item || effectLoader.item.hideFront === false)
        layer.enabled: !visible && root.transitionActive
        z: !root.imgAIsBack ? 0 : 1

        fillMode: root.fillMode
        sourceSize: root.sourceSize
        cache: root.cache; antialiasing: root.antialiasing; asynchronous: root.asynchronous; smooth: root.smooth; mipmap: root.mipmap
        playing: visible

        onStatusChanged: {
            let wait = effectLoader.item ? effectLoader.item.waitForReady !== false : true
            if (wait) {
                if (status === Image.Ready && root.transitionActive && root.imgAIsBack) {
                    root.startTransition()
                } else if (status === Image.Error && root.transitionActive && root.imgAIsBack) {
                    root.cleanupTransition()
                }
            }
        }
    }

    Loader {
        id: effectLoader
        anchors.fill: parent
        source: "transitions/" + (root.effectiveType.charAt(0).toUpperCase() + root.effectiveType.slice(1)) + ".qml"

        onLoaded: {
            item.frontImg = Qt.binding(function() { return root.frontImg })
            item.backImg = Qt.binding(function() { return root.backImg })
            item.duration = Qt.binding(function() { return root.animationDuration })
        }

        Connections {
            target: effectLoader.item
            function onFinished() {
                root.cleanupTransition()
            }
        }
    }
}
