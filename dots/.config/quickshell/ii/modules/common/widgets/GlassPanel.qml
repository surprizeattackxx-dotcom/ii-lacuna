import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions

// Liquid-glass panel background: blurred slice of the monitor's wallpaper
// under a translucent tint. Compositor layer blur doesn't reach quickshell
// layers on this Hyprland build, so the frosting is done shell-side.
// Static image → the blur renders once and stays cached.
Item {
    id: root

    property var screen
    property real cornerRadius: 0
    property real topLeftRadius: cornerRadius
    property real topRightRadius: cornerRadius
    property real bottomLeftRadius: cornerRadius
    property real bottomRightRadius: cornerRadius
    // Panel's top-left corner in monitor coordinates — alignment only needs
    // to be approximate, heavy blur hides small offsets
    property real screenX: 0
    property real screenY: 0
    property real blurRadius: 56
    property color tint: Appearance.colors.colLayer0

    readonly property real screenW: screen?.width ?? 1920
    readonly property real screenH: screen?.height ?? 1080

    readonly property string statePath: {
        const stateDir = FileUtils.trimFileProtocol(Directories.state).replace(/\/$/, "");
        return `${stateDir}/user/generated/wallpaper/monitors/${screen?.name ?? ""}.json`;
    }
    property string _stateText: ""
    FileView {
        path: screen?.name ? root.statePath : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._stateText = text() ?? ""
        onLoadFailed: root._stateText = ""
    }
    readonly property string wallpaperPath: {
        let p = "";
        try {
            p = JSON.parse(root._stateText)?.path ?? "";
        } catch (e) {}
        if (p === "")
            p = Config.options.background.wallpaperPath;
        const isVideo = /\.(mp4|webm|mkv|avi|mov)$/i.test(p);
        return isVideo ? Config.options.background.thumbnailPath : p;
    }

    Item {
        id: sample
        anchors.fill: parent
        visible: false
        clip: true
        Image {
            x: -root.screenX
            y: -root.screenY
            width: root.screenW
            height: root.screenH
            source: root.wallpaperPath !== "" ? Qt.resolvedUrl(FileUtils.trimFileProtocol(root.wallpaperPath).startsWith("/") ? "file://" + FileUtils.trimFileProtocol(root.wallpaperPath) : root.wallpaperPath) : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.round(root.screenW / 4)
            sourceSize.height: Math.round(root.screenH / 4)
            asynchronous: true
        }
    }

    FastBlur {
        anchors.fill: parent
        source: sample
        radius: root.blurRadius
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: root.width
                height: root.height
                topLeftRadius: root.topLeftRadius
                topRightRadius: root.topRightRadius
                bottomLeftRadius: root.bottomLeftRadius
                bottomRightRadius: root.bottomRightRadius
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: root.tint
    }
}
