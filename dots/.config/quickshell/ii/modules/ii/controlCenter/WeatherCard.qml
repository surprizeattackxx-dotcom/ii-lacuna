import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    implicitHeight: 64
    radius: Appearance.rounding.medium
    color: Appearance.m3colors.m3surfaceContainer

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: Appearance.colors.colTertiaryContainer

            MaterialSymbol {
                anchors.centerIn: parent
                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "weather_mix"
                iconSize: 22
                color: Appearance.colors.colOnTertiaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    text: Weather.data.temp || "--°"
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    color: Appearance.m3colors.m3onSurface
                }

                StyledText {
                    text: Weather.data.description || ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.m3colors.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: Weather.data.city || ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.m3colors.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                spacing: 12

                StyledText {
                    text: "H:" + (Weather.data.tempMax || "--") + " L:" + (Weather.data.tempMin || "--")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.m3colors.m3onSurfaceVariant
                }

                StyledText {
                    visible: Weather.data.humidity
                    text: Translation.tr("Humidity: ") + Weather.data.humidity + "%"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.m3colors.m3onSurfaceVariant
                }

                StyledText {
                    visible: Weather.data.wind
                    text: Translation.tr("Wind: ") + Weather.data.wind
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.m3colors.m3onSurfaceVariant
                }
            }
        }
    }
}
