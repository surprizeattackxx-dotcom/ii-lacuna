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
        icon: Battery.chargeState === 4 ? "battery_full" :
              Battery.isCharging ? "battery_charging_full" :
              Battery.percentage < 0.2 ? "battery_low" : "battery_android_full"
        title: Math.round(Battery.percentage * 100) + "%"
        subtitle: {
            if (Battery.chargeState === 4) return Translation.tr("Fully charged")
            function formatTime(s) {
                const h = Math.floor(s / 3600)
                const m = Math.floor((s % 3600) / 60)
                return h > 0 ? h + "h " + m + "m" : m + "m"
            }
            if (Battery.isCharging && Battery.timeToFull > 0)
                return Translation.tr("Charging · ") + formatTime(Battery.timeToFull)
            if (!Battery.isCharging && Battery.timeToEmpty > 0)
                return formatTime(Battery.timeToEmpty) + Translation.tr(" remaining")
            return Battery.isCharging ? Translation.tr("Charging") : Translation.tr("Discharging")
        }
    }
}
