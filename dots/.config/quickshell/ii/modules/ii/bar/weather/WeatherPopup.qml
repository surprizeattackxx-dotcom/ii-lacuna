import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../cards"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.ii.bar

StyledPopup {
    id: root
    property bool compact: false

    Item {
        id: content
        implicitWidth:  300
        implicitHeight: mainLayout.implicitHeight
        property int tab: 0

        Connections {
            target: root
            function onOpenChanged() { if (!root.open) content.tab = 0; }
        }

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            spacing: 8

            // ── Alert banners ─────────────────────────────────────────────────
            Repeater {
                model: Weather.alerts
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    radius: Appearance.rounding.small
                    color:  Qt.rgba(1, 0.25, 0.15, 0.12)
                    border.width: 1; border.color: Qt.rgba(1, 0.4, 0.2, 0.35)
                    implicitHeight: alertRow.implicitHeight + 12
                    RowLayout {
                        id: alertRow
                        anchors { fill: parent; margins: 6 }
                        spacing: 6
                        MaterialSymbol { text: "warning"; fill: 1; iconSize: Appearance.font.pixelSize.normal; color: "#ff6b4a" }
                        StyledText {
                            text: modelData.event
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium; color: "#ff6b4a"
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // ── Tab switcher ──────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                component Seg: Rectangle {
                    property string label: ""
                    property int idx: 0
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: Appearance.rounding.small
                    color: content.tab === idx ? Appearance.colors.colPrimaryContainer : Appearance.m3colors.m3surfaceContainerHigh
                    border.width: 1
                    border.color: Qt.rgba(Appearance.colors.colPrimary.r,
                                          Appearance.colors.colPrimary.g,
                                          Appearance.colors.colPrimary.b, content.tab === idx ? 0.35 : 0.15)
                    StyledText {
                        anchors.centerIn: parent
                        text: label
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: content.tab === idx ? Font.Bold : Font.Medium
                        color: content.tab === idx ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: content.tab = idx }
                }

                Seg { label: Translation.tr("Today"); idx: 0 }
                Seg { label: Translation.tr("5-Day"); idx: 1 }
            }

            // ── Header ────────────────────────────────────────────────────────
            HeroCard {
                visible: content.tab === 0
                icon: Icons.getWeatherIcon(Weather.data.wCode) ?? "partly_cloudy_day"
                title: Weather.data.temp
                subtitle: Weather.data.description + " · " + Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike)
                compactMode: true
                adaptiveWidth: true
                pillText: Weather.data.city || "--"
                pillIcon: "location_on"
            }

            // ── Hourly strip ──────────────────────────────────────────────────
            Column {
                Layout.fillWidth: true; spacing: 4
                visible: content.tab === 0 && Weather.hourly.length > 0

                RowLayout {
                    width: parent.width; spacing: 6
                    Rectangle { width: 12; height: 1; color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.4) }
                    StyledText {
                        text: Translation.tr("Hourly")
                        font { pixelSize: 9; weight: Font.Bold; capitalization: Font.AllUppercase }
                        color: Appearance.colors.colSubtext
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.4) }
                }

                ListView {
                    width: parent.width
                    height: 92
                    orientation: ListView.Horizontal
                    spacing: 4
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Weather.hourly

                    delegate: Rectangle {
                        required property var modelData
                        width: 46; height: ListView.view.height
                        radius: Appearance.rounding.small
                        color: modelData.isNow ? Appearance.colors.colPrimaryContainer : Appearance.m3colors.m3surfaceContainerHigh
                        border.width: 1
                        border.color: Qt.rgba(Appearance.colors.colPrimary.r,
                                              Appearance.colors.colPrimary.g,
                                              Appearance.colors.colPrimary.b, modelData.isNow ? 0.35 : 0.15)

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.hourLabel
                                font.pixelSize: 9
                                font.weight: modelData.isNow ? Font.Bold : Font.Normal
                                color: modelData.isNow ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                            }
                            MaterialSymbol {
                                anchors.horizontalCenter: parent.horizontalCenter
                                fill: 0
                                text: Icons.getWeatherIcon(modelData.wCode) ?? "cloud"
                                iconSize: Appearance.font.pixelSize.larger
                                color: modelData.isNow ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.temp
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: modelData.isNow ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 1
                                visible: (modelData.precipProb ?? 0) >= 10
                                MaterialSymbol { fill: 1; text: "water_drop"; iconSize: 9; color: modelData.isNow ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary; opacity: 0.7 }
                                StyledText { text: (modelData.precipProb ?? 0) + "%"; font.pixelSize: 8; color: modelData.isNow ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary; opacity: 0.85 }
                            }
                        }
                    }
                }
            }

            // ── Metrics grid ──────────────────────────────────────────────────
            GridLayout {
                visible: content.tab === 0
                Layout.fillWidth: true
                columns: 2; rowSpacing: 5; columnSpacing: 5
                uniformCellWidths: true

                component WeatherTile: Rectangle {
                    property string symbol: ""; property string title: ""; property string value: ""
                    Layout.fillWidth: true
                    implicitHeight: tileRow.implicitHeight + 12
                    radius: Appearance.rounding.small
                    color:  Appearance.m3colors.m3surfaceContainerHigh
                    border.width: 1
                    border.color: Qt.rgba(Appearance.colors.colPrimary.r,
                                          Appearance.colors.colPrimary.g,
                                          Appearance.colors.colPrimary.b, 0.18)
                    RowLayout {
                        id: tileRow
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6
                        Rectangle {
                            implicitWidth: 26; implicitHeight: 26; radius: 8
                            color: Qt.rgba(Appearance.colors.colPrimary.r,
                                           Appearance.colors.colPrimary.g,
                                           Appearance.colors.colPrimary.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(Appearance.colors.colPrimary.r,
                                                  Appearance.colors.colPrimary.g,
                                                  Appearance.colors.colPrimary.b, 0.30)
                            MaterialSymbol { anchors.centerIn: parent; text: symbol; iconSize: 13; color: Appearance.colors.colPrimary }
                        }
                        Column {
                            Layout.fillWidth: true; spacing: 1
                            StyledText { text: title; font.pixelSize: 9; color: Appearance.colors.colSubtext }
                            StyledText {
                                text: value
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium; color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight; width: parent.width
                            }
                        }
                    }
                }

                WeatherTile { title: Translation.tr("UV Index");      symbol: "wb_sunny";          value: Weather.data.uv }
                WeatherTile { title: Translation.tr("Wind");          symbol: "air";               value: `(${Weather.data.windDir}) ${Weather.data.wind}` }
                WeatherTile { title: Translation.tr("Precipitation"); symbol: "rainy_light";       value: Weather.data.precip }
                WeatherTile { title: Translation.tr("Humidity");      symbol: "humidity_low";      value: Weather.data.humidity }
                WeatherTile { title: Translation.tr("Visibility");    symbol: "visibility";        value: Weather.data.visib }
                WeatherTile { title: Translation.tr("Pressure");      symbol: "readiness_score";   value: Weather.data.press }
                WeatherTile { title: Translation.tr("Sunrise");       symbol: "wb_twilight";       value: Weather.data.sunrise }
                WeatherTile { title: Translation.tr("Sunset");        symbol: "bedtime";           value: Weather.data.sunset }
                WeatherTile { title: Translation.tr("Low / High");    symbol: "thermometer";       value: Weather.data.tempMin + " / " + Weather.data.tempMax }
                WeatherTile { title: Translation.tr("Dew Point");     symbol: "dew_point";         value: Weather.data.dewPoint }
                WeatherTile { title: Translation.tr("Cloud Cover");   symbol: "cloud";             value: Weather.data.cloudCover }
                WeatherTile { title: Translation.tr("Conditions");    symbol: "partly_cloudy_day"; value: Weather.data.description }
            }

            // ── 5-day forecast ────────────────────────────────────────────────
            Column {
                Layout.fillWidth: true; spacing: 4
                visible: content.tab === 1 && Weather.forecast.length > 0

                HeroCard {
                    width: parent.width
                    icon: "calendar_month"
                    title: Translation.tr("5-Day Forecast")
                    subtitle: Weather.data.city
                    compactMode: true
                    adaptiveWidth: true
                }

                Repeater {
                    model: Weather.forecast
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; implicitHeight: fcRow.implicitHeight + 10
                        radius: Appearance.rounding.small
                        color:  Appearance.m3colors.m3surfaceContainerHigh
                        border.width: 1
                        border.color: Qt.rgba(Appearance.colors.colPrimary.r,
                                              Appearance.colors.colPrimary.g,
                                              Appearance.colors.colPrimary.b, 0.15)
                        RowLayout {
                            id: fcRow
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8
                            StyledText { text: modelData.dayLabel; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Medium; color: Appearance.colors.colOnSurfaceVariant; Layout.minimumWidth: 32 }
                            MaterialSymbol { fill: 0; text: Icons.getWeatherIcon(modelData.wCode) ?? "cloud"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colPrimary }
                            RowLayout {
                                spacing: 2
                                visible: (modelData.precipProb ?? 0) >= 10
                                MaterialSymbol { fill: 1; text: "water_drop"; iconSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colPrimary; opacity: 0.7 }
                                StyledText { text: (modelData.precipProb ?? 0) + "%"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colPrimary; opacity: 0.8 }
                            }
                            Item { Layout.fillWidth: true }
                            StyledText { text: modelData.tempMin; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnSurfaceVariant; opacity: 0.6 }
                            StyledText { text: "/"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnSurfaceVariant; opacity: 0.3 }
                            StyledText { text: modelData.tempMax; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Medium; color: Appearance.colors.colOnLayer1 }
                        }
                    }
                }
            }

            // ── Footer ────────────────────────────────────────────────────────
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh)
                font { weight: Font.Medium; pixelSize: Appearance.font.pixelSize.smaller }
                color: Appearance.colors.colSubtext; opacity: 0.7
            }
        }
    }
}
