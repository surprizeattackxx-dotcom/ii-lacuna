import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

MouseArea {
    id: root
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    // Disk + GPU usage come from the ResourceUsage singleton (polled once for the
    // whole shell) instead of each bar spawning its own df/nvidia-smi per monitor.

    RowLayout {
        id: rowLayout
        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            shown: true
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
        }

        Resource {
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: true
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.swapWarningThreshold
        }

        Resource {
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: true
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.cpuWarningThreshold
        }

        Resource {
            iconName: "display_settings"
            percentage: ResourceUsage.gpuUsage
            shown: true
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: 90
        }

        Resource {
            iconName: "hard_drive"
            percentage: ResourceUsage.diskUsedPercentage
            shown: true
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.diskWarningThreshold ?? 90
        }
    }

    Loader {
        active: true
        asynchronous: true
        sourceComponent: Config.options.bar.tooltips.compactPopups ? resourcesPopupCompact : resourcesPopupFull
    }
    Component {
        id: resourcesPopupFull
        ResourcesPopup { hoverTarget: root }
    }
    Component {
        id: resourcesPopupCompact
        ResourcesPopupCompact { hoverTarget: root }
    }
}
