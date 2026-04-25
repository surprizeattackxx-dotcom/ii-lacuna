import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "./cards"

StyledPopup {
    id: root

    contentItem: HeroCard {
        anchors.centerIn: parent
        adaptiveWidth: true
        margins: 20
        iconSize: 100
        icon: "memory"
        title: Math.round(ResourceUsage.cpuUsage * 100) + "%"
        subtitle: "CPU · RAM " + Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
    }
}
