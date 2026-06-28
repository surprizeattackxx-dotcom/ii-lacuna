import QtQuick
import qs.modules.common

// Shared rounded card container for the control center — ii equivalent of
// noctalia's NBox (rounded group using the variant surface color).
Rectangle {
    id: root
    color: Appearance.m3colors.m3surfaceContainer
    radius: Appearance.rounding.medium
    border.width: Config.options.appearance.sharpMode ? 0 : 1
    border.color: Appearance.m3colors.m3outlineVariant
}
