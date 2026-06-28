import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.controlCenter

// System monitor card: four vertically-stacked circular arc gauges
// (CPU usage, CPU temperature, RAM, Disk), mirroring noctalia's
// SystemMonitorCard which uses one NCircleStat gauge per metric.
CCBox {
    id: root
    implicitWidth: 140
    implicitHeight: 260

    // A single gauge cluster: thin arc ring + centered value + icon below,
    // matching noctalia's NCircleStat.
    component MetricGauge: Item {
        id: gauge

        property real ratio: 0          // 0..1, drives the ring fill
        property string valueText: ""   // e.g. "23%" or "39°C"
        property string iconName: ""
        property bool warning: false

        CCGauge {
            anchors.centerIn: parent
            gaugeSize: Math.min(parent.height - 2, 56)
            ratio: gauge.ratio
            valueText: gauge.valueText
            iconName: gauge.iconName
            fillColor: gauge.warning ? Appearance.colors.colError : Appearance.m3colors.m3onSecondaryContainer
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 6

        // CPU usage (cpuUsage is 0..1)
        MetricGauge {
            width: parent.width
            height: parent.height / 4
            ratio: ResourceUsage.cpuUsage
            valueText: Math.round(ResourceUsage.cpuUsage * 100) + "%"
            iconName: "speed"
            warning: ResourceUsage.cpuUsage >= 0.9
        }

        // CPU temperature (cpuTemp is °C; ring is fraction of 100 °C)
        MetricGauge {
            width: parent.width
            height: parent.height / 4
            ratio: ResourceUsage.cpuTemp / 100
            valueText: Math.round(ResourceUsage.cpuTemp) + "°C"
            iconName: "thermostat"
            warning: ResourceUsage.cpuTemp >= 85
        }

        // RAM usage (memoryUsedPercentage is 0..1)
        MetricGauge {
            width: parent.width
            height: parent.height / 4
            ratio: ResourceUsage.memoryUsedPercentage
            valueText: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
            iconName: "memory"
            warning: ResourceUsage.memoryUsedPercentage >= 0.9
        }

        // Disk usage (diskUsedPercentage is 0..1)
        MetricGauge {
            width: parent.width
            height: parent.height / 4
            ratio: ResourceUsage.diskUsedPercentage
            valueText: Math.round(ResourceUsage.diskUsedPercentage * 100) + "%"
            iconName: "storage"
            warning: ResourceUsage.diskUsedPercentage >= 0.9
        }
    }
}
