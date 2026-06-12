import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property bool vertical: false
    property bool islandStyle: false
    readonly property bool islandHovered: islandStyle && hoverHandler.hovered
    property real padding: 5
    implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight
    default property alias items: gridLayout.children
    property var startRadius // left - top
    property var endRadius // right - bottom

    property color colBackground: Appearance.m3colors.m3surfaceContainerLow
    property real backgroundAlpha: 0.45

    // Pill position in monitor coordinates so the glass samples the right slice
    property real _sceneX: 0
    property real _sceneY: 0
    function _updateScenePos() {
        const p = background.mapToItem(null, 0, 0);
        _sceneX = p.x + Appearance.sizes.hyprlandGapsOut;
        _sceneY = Config.options.bar.bottom
            ? ((root.QsWindow.window?.screen?.height ?? 0) - (root.QsWindow.window?.height ?? 0) + p.y)
            : p.y;
    }
    Component.onCompleted: _updateScenePos()
    onXChanged: _updateScenePos()
    onWidthChanged: _updateScenePos()

    HoverHandler {
        id: hoverHandler
        enabled: root.islandStyle
    }

    // Floating-island drop shadow (ActivSpot style) — blurred dark slab behind the pill
    Rectangle {
        visible: root.islandStyle
        anchors.fill: background
        anchors.margins: -4
        anchors.topMargin: 2
        topLeftRadius: (background.topLeftRadius ?? 0) + 4
        bottomLeftRadius: (background.bottomLeftRadius ?? 0) + 4
        topRightRadius: (background.topRightRadius ?? 0) + 4
        bottomRightRadius: (background.bottomRightRadius ?? 0) + 4
        color: Qt.rgba(0, 0, 0, root.islandHovered ? 0.34 : 0.26)
        Behavior on color { ColorAnimation { duration: 300 } }
        layer.enabled: root.islandStyle
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 20
        }
    }

    GlassPanel {
        anchors.fill: background
        screen: root.QsWindow.window?.screen
        topLeftRadius: background.topLeftRadius ?? 0
        topRightRadius: background.topRightRadius ?? 0
        bottomLeftRadius: background.bottomLeftRadius ?? 0
        bottomRightRadius: background.bottomRightRadius ?? 0
        screenX: root._sceneX
        screenY: root._sceneY
        tint: "transparent"
    }

    Rectangle {
        id: background
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        color: {
            if (root.islandStyle) {
                const base = Appearance.m3colors.m3background;
                // Light themes read as a glaring slab at high alpha; dark can afford more fill
                const a = Appearance.m3colors.darkmode
                    ? (root.islandHovered ? 0.95 : 0.78)
                    : (root.islandHovered ? 0.82 : 0.66);
                return Qt.rgba(base.r, base.g, base.b, a);
            }
            return Qt.rgba(root.colBackground.r, root.colBackground.g, root.colBackground.b, root.backgroundAlpha);
        }
        border.width: 1
        border.color: root.islandStyle
            ? Qt.rgba(Appearance.colors.colOnLayer0.r, Appearance.colors.colOnLayer0.g, Appearance.colors.colOnLayer0.b, root.islandHovered ? 0.15 : 0.06)
            : Appearance.colors.colLayer0Border
        Behavior on border.color { ColorAnimation { duration: 300 } }
        topLeftRadius: startRadius
        bottomLeftRadius: root.vertical ? endRadius: startRadius
        topRightRadius: root.vertical ? startRadius: endRadius
        bottomRightRadius: endRadius

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors {
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            left: root.vertical ? undefined : parent.left
            right: root.vertical ? undefined : parent.right
            top: root.vertical ? parent.top : undefined
            bottom: root.vertical ? parent.bottom : undefined
            margins: root.padding
        }
        columnSpacing: 4
        rowSpacing: 12
    }
}