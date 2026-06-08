import qs.modules.common
import qs.modules.common.widgets
import "./cards"
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12

        HeroCard {
            icon: "battery_android_full"
            title: Battery.percent + "%"
            subtitle: {
                if (Battery.chargeState == 4)
                    return Translation.tr("Fully charged");
                else if (Battery.chargeState == 1)
                    return Translation.tr("Charging");
                else
                    return Translation.tr("Discharging");
            }

            compactMode: true
            adaptiveWidth: true

            function formatTime(seconds) {
                var h = Math.floor(seconds / 3600);
                var m = Math.floor((seconds % 3600) / 60);
                if (h > 0) return h + "h, " + m + "m";
                else return m + "m";
            }

            readonly property var timeLeft: Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty
            readonly property var power: Battery.energyRate

            pillText: (Battery.chargeState !== 4 && timeLeft > 0 && power > 0.01) ? formatTime(timeLeft) : ""
            pillIcon: (Battery.chargeState !== 4 && timeLeft > 0 && power > 0.01) ? "schedule" : ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            InfoPill {
                visible: {
                    let timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                    let power = Battery.energyRate;
                    return !(Battery.chargeState == 4 || timeValue <= 0 || power <= 0.01);
                }
                icon: "schedule"
                text: {
                    function formatTime(seconds) {
                        var h = Math.floor(seconds / 3600);
                        var m = Math.floor((seconds % 3600) / 60);
                        if (h > 0) return h + "h, " + m + "m";
                        else return m + "m";
                    }
                    var timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                    if (Battery.isCharging)
                        return Translation.tr("Time to full: ") + formatTime(timeValue);
                    else
                        return Translation.tr("Time to empty: ") + formatTime(timeValue);
                }
                containerColor: Appearance.colors.colPrimaryContainer
                shapeColor: Appearance.colors.colPrimary
                symbolColor: Appearance.colors.colOnPrimary
                textColor: Appearance.colors.colOnPrimaryContainer
            }

            InfoPill {
                visible: !(Battery.chargeState != 4 && Battery.energyRate == 0)
                icon: "bolt"
                text: {
                    if (Battery.chargeState == 4)
                        return Translation.tr("Fully charged");
                    else if (Battery.chargeState == 1)
                        return Translation.tr("Charging: ") + Battery.energyRate.toFixed(2) + "W";
                    else
                        return Translation.tr("Discharging: ") + Battery.energyRate.toFixed(2) + "W";
                }
                containerColor: Appearance.colors.colSecondaryContainer
                shapeColor: Appearance.colors.colSecondary
                symbolColor: Appearance.colors.colOnSecondary
                textColor: Appearance.colors.colOnSecondaryContainer
            }

            InfoPill {
                icon: "heart_check"
                text: Translation.tr("Health: ") + Battery.health.toFixed(1) + "%"
                containerColor: Appearance.colors.colTertiaryContainer
                shapeColor: Appearance.colors.colTertiary
                symbolColor: Appearance.colors.colOnTertiary
                textColor: Appearance.colors.colOnTertiaryContainer
            }
        }
    }
}
