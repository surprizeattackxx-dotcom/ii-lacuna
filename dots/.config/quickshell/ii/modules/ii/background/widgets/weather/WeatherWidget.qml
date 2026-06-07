import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "weather"

    implicitHeight: backgroundShape.implicitHeight
    implicitWidth: backgroundShape.implicitWidth

    readonly property bool isDay: {
        DateTime.time
        const sr = Weather.data?.sunrise, ss = Weather.data?.sunset
        if (!sr || !ss) return true
        const p = s => { const a = s.split(":"); return parseInt(a[0]) * 60 + parseInt(a[1]) }
        const now = new Date()
        const cur = now.getHours() * 60 + now.getMinutes()
        return cur >= p(sr) && cur < p(ss)
    }

    StyledDropShadow {
        target: backgroundShape
    }

    MaterialShape {
        id: backgroundShape
        anchors.fill: parent
        shape: MaterialShape.Shape.Pill
        color: Appearance.colors.colPrimaryContainer
        implicitSize: 200

        Rectangle {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            clip: true
            color: "transparent"
            WeatherEffects {
                wCode: Weather.data?.wCode ?? 0
                isDay: root.isDay
                active: false
            }
        }

        StyledText {
            font {
                pixelSize: 80
                family: Appearance.font.family.expressive
                weight: Font.Medium
            }
            color: Appearance.colors.colPrimary
            text: Weather.data?.temp.substring(0,Weather.data?.temp.length - 1) ?? "--°"
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: 16
                topMargin: 20
            }
        }

        MaterialSymbol {
            iconSize: 80
            color: Appearance.colors.colOnPrimaryContainer
            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
            anchors {
                left: parent.left
                bottom: parent.bottom

                leftMargin: 16
                bottomMargin: 20
            }
        }
    }
}
