import qs.services
import qs.modules.common
import qs.modules.common.widgets
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

        // Live weather animation driven by Weather.data.wCode. Every driver is
        // gated on `playing` (= popup open) so nothing renders when it's shut.
        component WeatherScene: Item {
            id: scene
            property int wcode: 122
            property string sunriseStr: ""
            property string sunsetStr: ""
            property string windStr: ""
            property bool playing: false
            clip: true

            readonly property string cat: {
                const c = scene.wcode;
                if (c === 389 || c === 392 || c === 395) return "thunder";
                if (c === 323 || c === 329 || c === 338 || c === 335 || c === 368 || c === 371) return "snow";
                if (c === 266 || c === 281 || c === 296 || c === 302 || c === 308 || c === 311 || c === 353 || c === 356 || c === 359) return "rain";
                if (c === 143) return "fog";
                if (c === 119 || c === 122) return "cloudy";
                return "clear";
            }
            readonly property bool hasClouds: cat === "cloudy" || cat === "fog" || cat === "rain" || cat === "snow" || cat === "thunder"
            readonly property real windAmt: Math.min((parseFloat(scene.windStr) || 0) / 40, 1)

            property bool day: true
            function recomputeDay() {
                const now = new Date();
                const nm = now.getHours() * 60 + now.getMinutes();
                const parse = s => { const p = (s || "").split(":"); return p.length === 2 ? (+p[0]) * 60 + (+p[1]) : -1; };
                const sr = parse(scene.sunriseStr), ss = parse(scene.sunsetStr);
                if (sr < 0 || ss < 0) { scene.day = now.getHours() >= 7 && now.getHours() < 19; return; }
                scene.day = nm >= sr && nm < ss;
            }
            onPlayingChanged: if (playing) recomputeDay()
            onSunriseStrChanged: recomputeDay()
            Component.onCompleted: recomputeDay()
            Timer { running: scene.playing; interval: 60000; repeat: true; onTriggered: scene.recomputeDay() }

            readonly property color skyTop: {
                if (cat === "clear")   return scene.day ? Qt.rgba(0.29, 0.56, 0.89, 0.33) : Qt.rgba(0.05, 0.06, 0.16, 0.46);
                if (cat === "thunder") return Qt.rgba(0.12, 0.13, 0.20, 0.50);
                if (cat === "snow")    return Qt.rgba(0.55, 0.62, 0.72, 0.33);
                if (cat === "rain")    return Qt.rgba(0.28, 0.34, 0.45, 0.42);
                return Qt.rgba(0.45, 0.50, 0.60, 0.33);
            }
            readonly property color skyBottom: {
                if (cat === "clear")   return scene.day ? Qt.rgba(0.66, 0.83, 1.00, 0.30) : Qt.rgba(0.15, 0.19, 0.36, 0.42);
                if (cat === "thunder") return Qt.rgba(0.20, 0.22, 0.30, 0.42);
                if (cat === "snow")    return Qt.rgba(0.78, 0.83, 0.90, 0.30);
                if (cat === "rain")    return Qt.rgba(0.40, 0.46, 0.56, 0.36);
                return Qt.rgba(0.60, 0.65, 0.73, 0.30);
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: scene.skyTop }
                    GradientStop { position: 1.0; color: scene.skyBottom }
                }
            }

            // Sun (clear, day)
            Item {
                anchors.fill: parent
                visible: scene.cat === "clear" && scene.day
                Rectangle {
                    width: 74; height: 74; radius: 37
                    x: parent.width - 56; y: -16
                    color: "#ffe39a"; opacity: 0.28
                    transformOrigin: Item.Center
                    SequentialAnimation on scale {
                        running: scene.playing && scene.cat === "clear" && scene.day; loops: Animation.Infinite
                        NumberAnimation { from: 0.9; to: 1.18; duration: 2200; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.18; to: 0.9; duration: 2200; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle { width: 34; height: 34; radius: 17; x: parent.width - 38; y: 4; color: "#ffd166"; opacity: 0.92 }
            }

            // Moon + stars (clear, night)
            Item {
                anchors.fill: parent
                visible: scene.cat === "clear" && !scene.day
                Rectangle { width: 30; height: 30; radius: 15; x: parent.width - 42; y: 8; color: "#dfe6ff"; opacity: 0.85 }
                Repeater {
                    model: 16
                    delegate: Rectangle {
                        property real sz: Math.random() < 0.3 ? 2 : 1.4
                        width: sz; height: sz; radius: sz / 2; color: "white"
                        x: Math.random() * scene.width; y: Math.random() * scene.height * 0.7
                        SequentialAnimation on opacity {
                            running: scene.playing && scene.cat === "clear" && !scene.day; loops: Animation.Infinite
                            NumberAnimation { from: 0.2; to: 0.95; duration: 700 + Math.random() * 1200 }
                            NumberAnimation { from: 0.95; to: 0.2; duration: 700 + Math.random() * 1200 }
                        }
                    }
                }
            }

            // Drifting clouds
            Item {
                id: cloudLayer
                anchors.fill: parent
                visible: scene.hasClouds
                property real drift: 0
                NumberAnimation on drift {
                    running: scene.playing && cloudLayer.visible; from: 0; to: 1; duration: 22000; loops: Animation.Infinite
                }
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        property real cw: scene.width * (0.55 + index * 0.12)
                        width: cw; height: cw * 0.36; radius: height / 2
                        y: scene.height * (0.10 + index * 0.24)
                        color: (scene.cat === "thunder" || scene.cat === "rain") ? "#5b6472" : "#cfd6e0"
                        opacity: scene.cat === "fog" ? 0.14 : 0.22
                        x: ((cloudLayer.drift * (0.7 + index * 0.2) + index / 3) % 1.0) * (scene.width + cw) - cw
                    }
                }
            }

            // Rain
            Item {
                id: rainLayer
                anchors.fill: parent
                visible: scene.cat === "rain" || scene.cat === "thunder"
                property real phase: 0
                NumberAnimation on phase {
                    running: scene.playing && rainLayer.visible; from: 0; to: 1; duration: 850; loops: Animation.Infinite
                }
                Repeater {
                    model: 34
                    delegate: Rectangle {
                        property real off: Math.random()
                        property real spd: 0.8 + Math.random() * 0.7
                        property real lane: Math.random()
                        property real yp: ((rainLayer.phase * spd + off) % 1.0)
                        width: 1.6; height: 9; radius: 1; antialiasing: true
                        color: Qt.rgba(0.72, 0.84, 1.0, 0.55)
                        rotation: scene.windAmt * 16
                        x: lane * scene.width - scene.windAmt * 24 * yp
                        y: yp * (scene.height + height) - height
                    }
                }
            }

            // Snow
            Item {
                id: snowLayer
                anchors.fill: parent
                visible: scene.cat === "snow"
                property real phase: 0
                NumberAnimation on phase {
                    running: scene.playing && snowLayer.visible; from: 0; to: 1; duration: 6000; loops: Animation.Infinite
                }
                Repeater {
                    model: 24
                    delegate: Rectangle {
                        property real off: Math.random()
                        property real spd: 0.6 + Math.random() * 0.5
                        property real lane: Math.random()
                        property real sway: Math.random() * 6.283
                        property real yp: ((snowLayer.phase * spd + off) % 1.0)
                        property real sz: 3 + Math.random() * 2
                        width: sz; height: sz; radius: sz / 2; color: "white"; opacity: 0.85
                        x: lane * scene.width + Math.sin(yp * 6.283 + sway) * 8 + scene.windAmt * 22 * yp
                        y: yp * (scene.height + height) - height
                    }
                }
            }

            // Fog bands
            Item {
                id: fogLayer
                anchors.fill: parent
                visible: scene.cat === "fog"
                property real drift: 0
                NumberAnimation on drift {
                    running: scene.playing && fogLayer.visible; from: 0; to: 1; duration: 9000; loops: Animation.Infinite
                }
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        width: scene.width * 1.4; height: 10; radius: 5; color: "#e6ebf2"; opacity: 0.10
                        y: scene.height * (0.18 + index * 0.2)
                        x: ((fogLayer.drift + index * 0.25) % 1.0) * scene.width - scene.width * 0.2
                    }
                }
            }

            // Lightning flash
            Rectangle {
                id: flash
                anchors.fill: parent
                visible: scene.cat === "thunder"
                color: "white"; opacity: 0
                SequentialAnimation {
                    id: strike
                    NumberAnimation { target: flash; property: "opacity"; from: 0; to: 0.6; duration: 60 }
                    NumberAnimation { target: flash; property: "opacity"; to: 0.0; duration: 90 }
                    NumberAnimation { target: flash; property: "opacity"; to: 0.5; duration: 60 }
                    NumberAnimation { target: flash; property: "opacity"; to: 0.0; duration: 240 }
                }
                Timer {
                    running: scene.playing && scene.cat === "thunder"; interval: 2600; repeat: true
                    onTriggered: if (Math.random() < 0.6) strike.start()
                }
            }
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
            StyledPopupHeaderRow {
                visible: content.tab === 0
                Layout.fillWidth: true
                icon: "partly_cloudy_day"
                label: Weather.data.city
            }

            // ── Temp hero card ────────────────────────────────────────────────
            Rectangle {
                visible: content.tab === 0
                Layout.fillWidth: true
                implicitHeight: Math.max(tempCol.implicitHeight + 18, 104)
                radius: Appearance.rounding.normal
                color:  Appearance.m3colors.m3surfaceContainerHigh
                border.width: 1
                border.color: Qt.rgba(Appearance.colors.colPrimary.r,
                                      Appearance.colors.colPrimary.g,
                                      Appearance.colors.colPrimary.b, 0.25)
                clip: true

                WeatherScene {
                    anchors.fill: parent
                    wcode:      Weather.data.wCode
                    sunriseStr: Weather.data.sunrise
                    sunsetStr:  Weather.data.sunset
                    windStr:    Weather.data.wind
                    playing:    root.open
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Appearance.m3colors.base.r, Appearance.m3colors.base.g, Appearance.m3colors.base.b, 0.0) }
                        GradientStop { position: 1.0; color: Qt.rgba(Appearance.m3colors.base.r, Appearance.m3colors.base.g, Appearance.m3colors.base.b, 0.30) }
                    }
                }

                Column {
                    id: tempCol; anchors.centerIn: parent; spacing: 2
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.data.temp
                        font { pixelSize: 26; weight: Font.Bold }
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.data.description
                        font { pixelSize: Appearance.font.pixelSize.smaller; capitalization: Font.Capitalize }
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
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

                StyledPopupHeaderRow {
                    width: parent.width
                    icon: "calendar_month"
                    label: Weather.data.city
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
