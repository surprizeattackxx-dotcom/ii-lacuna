import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "./cards"

StyledPopup {
    id: root

    property bool alarmsActive: false
    open: alarmsActive || popupHovered
    signal closeRequested

    readonly property var nextAlarm: {
        const active = AlarmService.alarms.filter(a => !a.fired)
        return active.sort((a, b) => a.time - b.time)[0] ?? null
    }

    contentItem: HeroCard {
        anchors.centerIn: parent
        adaptiveWidth: true
        margins: 20
        iconSize: 100
        icon: "alarm"
        title: root.nextAlarm
            ? Qt.formatDateTime(new Date(root.nextAlarm.time), "hh:mm")
            : AlarmService.alarms.length.toString()
        subtitle: root.nextAlarm
            ? root.nextAlarm.label
            : Translation.tr("No alarms")
    }
}
