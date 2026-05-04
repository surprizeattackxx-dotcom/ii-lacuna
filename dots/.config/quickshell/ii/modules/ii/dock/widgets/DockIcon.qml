import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick.Effects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    property string appId: ""
    property bool isRunning: true
    property real iconOpacity: isRunning ? 1.0 : (Config.options.dock.dimInactiveIcons ? 0.55 : 1.0)
    
    IconImage {
        id: baseIcon
        anchors.fill: parent
        source: Quickshell.iconPath(TaskbarApps.getCachedIcon(root.appId), "image-missing")
        visible: !Config.options.dock.monochromeIcons
        opacity: root.iconOpacity
        
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: baseIcon
        saturation: -0.8
        visible: !root.isRunning && !Config.options.dock.monochromeIcons && Config.options.dock.dimInactiveIcons
        opacity: baseIcon.opacity
    }

    Loader {
        active: Config.options.dock.monochromeIcons
        anchors.fill: parent
        sourceComponent: MultiEffect {
            source: baseIcon
            anchors.fill: parent
            saturation: -0.8
            colorization: 0.1
            colorizationColor: Appearance.colors.colPrimary
        }
    }
}
