import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root
    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    property real contentMargin: 10

    property bool open: (hoverTarget?.containsMouse ?? false) || popupHovered
    property bool popupHovered: false

    active: true

    component: PanelWindow {
        id: popupWindow
        color: "transparent"
        visible: root.open

        readonly property real screenWidth: screen?.width ?? 0
        readonly property real screenHeight: screen?.height ?? 0

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        mask: Region { item: popupBackground }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                if (!Config.options.bar.vertical) {
                    if (!root.hoverTarget || !root.QsWindow) return 0;
                    var targetPos = root.QsWindow.mapFromItem(root.hoverTarget, 0, 0);
                    var centeredX = targetPos.x + (root.hoverTarget.width - popupWindow.implicitWidth) / 2;
                    return Math.max(0, Math.min(screenWidth - popupWindow.implicitWidth, centeredX));
                }
                return Appearance.sizes.verticalBarWidth;
            }
            top: {
                if (!Config.options.bar.vertical) return Appearance.sizes.barHeight;
                if (!root.hoverTarget || !root.QsWindow) return 0;
                var targetPos = root.QsWindow.mapFromItem(root.hoverTarget, 0, 0);
                var centeredY = targetPos.y + (root.hoverTarget.height - popupWindow.implicitHeight) / 2;
                return Math.max(0, Math.min(screenHeight - popupWindow.implicitHeight, centeredY));
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow { target: popupBackground }

        HoverHandler {
            target: popupBackground
            onHoveredChanged: root.popupHovered = hovered
        }

        Rectangle {
            id: popupBackground

            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }

            implicitWidth: (root.contentItem?.implicitWidth ?? 0) + root.contentMargin * 2
            implicitHeight: (root.contentItem?.implicitHeight ?? 0) + root.contentMargin * 2

            color: Appearance.m3colors.base
            radius: Appearance.rounding.large
            border.width: 1
            border.color: Appearance.m3colors.overlay1
            clip: true

            property real orbitAngle: 0
            NumberAnimation on orbitAngle {
                from: 0; to: Math.PI * 2; duration: 25000; loops: Animation.Infinite; running: true
            }

            Rectangle {
                width: (parent?.width ?? 0) * 0.7; height: width; radius: width / 2
                x: ((parent?.width ?? 0) / 2 - width / 2) + Math.cos((parent?.orbitAngle ?? 0) * 2) * 60
                y: ((parent?.height ?? 0) / 2 - height / 2) + Math.sin((parent?.orbitAngle ?? 0) * 2) * 30
                color: Appearance.m3colors.mauve
                opacity: 0.08
            }

            Rectangle {
                width: (parent?.width ?? 0) * 0.5; height: width; radius: width / 2
                x: ((parent?.width ?? 0) / 2 - width / 2) + Math.sin((parent?.orbitAngle ?? 0) * 1.5) * -50
                y: ((parent?.height ?? 0) / 2 - height / 2) + Math.cos((parent?.orbitAngle ?? 0) * 1.5) * -40
                color: Appearance.m3colors.blue
                opacity: 0.06
            }

            Component.onCompleted: {
                if (root.contentItem) {
                    root.contentItem.parent = popupBackground
                    root.contentItem.anchors.fill = popupBackground
                    root.contentItem.anchors.margins = root.contentMargin
                }
            }
        }
    }
}
