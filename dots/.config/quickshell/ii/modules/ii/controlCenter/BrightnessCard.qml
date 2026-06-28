import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    implicitHeight: 70
    radius: Appearance.rounding.medium
    color: Appearance.m3colors.m3surfaceContainer

    readonly property var brightnessMonitor: {
        let screens = Quickshell.screens
        if (screens.length > 0) return Brightness.getMonitorForScreen(screens[0])
        return null
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        StyledText {
            text: Translation.tr("Display")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: Appearance.m3colors.m3onSurfaceVariant
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "brightness_high"
                iconSize: 20
                color: Appearance.m3colors.m3onSurfaceVariant
            }

            StyledSlider {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: (root.brightnessMonitor?.brightness ?? 0.5) * 100
                onMoved: root.brightnessMonitor?.setBrightness(value / 100)
            }

            StyledText {
                text: Math.round((root.brightnessMonitor?.brightness ?? 0.5) * 100) + "%"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.m3colors.m3onSurfaceVariant
                Layout.preferredWidth: 36
            }
        }
    }
}
