import qs.services
import qs.modules.common
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    property string appId: ""
    property bool isRunning: true

    readonly property real _dimOpacity: isRunning ? 1.0 : (Config.options.dock.dimInactiveIcons ? 0.55 : 1.0)

    IconImage {
        id: baseIcon
        anchors.fill: parent
        source: Quickshell.iconPath(TaskbarApps.getCachedIcon(root.appId), "image-missing")
        opacity: root._dimOpacity

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: baseIcon
        saturation: -0.8
        visible: !root.isRunning && Config.options.dock.dimInactiveIcons
        opacity: baseIcon.opacity
    }
}
