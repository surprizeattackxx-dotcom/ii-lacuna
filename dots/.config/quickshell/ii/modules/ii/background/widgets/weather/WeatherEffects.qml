import QtQuick
import qs.modules.common

Item {
    id: root
    anchors.fill: parent

    property int wCode: 0
    property bool isDay: true
    property bool active: true

    readonly property color tintLight: Appearance.colors.colOnPrimaryContainer
    readonly property color tintStrong: Appearance.colors.colPrimary

    readonly property string category: {
        const c = String(wCode)
        const rain = ["176","179","182","185","263","266","281","284","293","296","299","305","311","314","317","350","353","356","362","365","374","377"]
        const snow = ["227","230","320","323","326","329","332","335","338","368","371","395"]
        const hail = ["302","308","359"]
        const thunder = ["200","386","389","392"]
        const cloud = ["119","122","143","248","260"]
        const partly = ["116"]
        if (thunder.indexOf(c) >= 0) return "thunder"
        if (snow.indexOf(c) >= 0) return "snow"
        if (hail.indexOf(c) >= 0) return "hail"
        if (rain.indexOf(c) >= 0) return "rain"
        if (cloud.indexOf(c) >= 0) return "cloud"
        if (partly.indexOf(c) >= 0) return "partly"
        return "clear"
    }

    function rand(i, salt) {
        const x = Math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453
        return x - Math.floor(x)
    }

    component Precip: Item {
        anchors.fill: parent
        property string mode: "rain" // rain | snow | hail
        Repeater {
            model: mode === "snow" ? 14 : 18
            delegate: Rectangle {
                required property int index
                readonly property real s1: root.rand(index, 1)
                readonly property real s2: root.rand(index, 2)
                readonly property bool round: parent.mode !== "rain"
                width: parent.mode === "rain" ? 2
                     : (parent.mode === "hail" ? 4 : 4 + s1 * 2)
                height: parent.mode === "rain" ? (8 + s1 * 8) : width
                radius: round ? width / 2 : 1
                rotation: parent.mode === "rain" ? 14 : 0
                color: parent.mode === "snow" ? root.tintLight : root.tintStrong
                opacity: 0
                property real baseX: s1 * (parent.width - width)
                property real sway: 0
                x: baseX + sway
                Component.onCompleted: opacity = parent.mode === "snow" ? 0.85 : 0.5
                Behavior on opacity { NumberAnimation { duration: 500 } }
                NumberAnimation on y {
                    from: -height - 12
                    to: root.height + 12
                    duration: (parent.mode === "snow" ? 5000
                             : (parent.mode === "hail" ? 650 : 1000)) * (0.7 + s2 * 0.6)
                    loops: Animation.Infinite
                    running: root.active
                }
                SequentialAnimation on sway {
                    running: root.active && parent.mode === "snow"
                    loops: Animation.Infinite
                    NumberAnimation { from: -9; to: 9; duration: 1400 + s1 * 1200; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 9; to: -9; duration: 1400 + s1 * 1200; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // Rain
    Loader {
        anchors.fill: parent
        active: root.category === "rain"
        sourceComponent: Precip { mode: "rain" }
    }

    // Snow
    Loader {
        anchors.fill: parent
        active: root.category === "snow"
        sourceComponent: Precip { mode: "snow" }
    }

    // Hail
    Loader {
        anchors.fill: parent
        active: root.category === "hail"
        sourceComponent: Precip { mode: "hail" }
    }

    // Thunderstorm: rain + lightning flashes
    Loader {
        anchors.fill: parent
        active: root.category === "thunder"
        sourceComponent: Item {
            anchors.fill: parent
            Precip { mode: "rain" }
            Rectangle {
                id: flash
                anchors.fill: parent
                color: root.tintStrong
                opacity: 0
                Timer {
                    interval: 2200 + Math.random() * 3500
                    running: root.active
                    repeat: true
                    onTriggered: { interval = 2200 + Math.random() * 3500; bolt.restart() }
                }
                SequentialAnimation {
                    id: bolt
                    NumberAnimation { target: flash; property: "opacity"; to: 0.45; duration: 50 }
                    NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 80 }
                    NumberAnimation { target: flash; property: "opacity"; to: 0.35; duration: 50 }
                    NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 280 }
                }
            }
        }
    }

    // Clouds / fog: drifting soft bands
    Loader {
        anchors.fill: parent
        active: root.category === "cloud" || root.category === "partly"
        sourceComponent: Item {
            anchors.fill: parent
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    readonly property real s1: root.rand(index, 5)
                    height: 16
                    width: 70 + s1 * 34
                    radius: height / 2
                    color: root.tintLight
                    opacity: 0.10 + s1 * 0.07
                    y: 36 + index * 46
                    NumberAnimation on x {
                        from: -width
                        to: root.width
                        duration: 9000 + s1 * 7000
                        loops: Animation.Infinite
                        running: root.active
                    }
                }
            }
        }
    }

    // Clear day: pulsing sun glow + slow rotating rays
    Loader {
        anchors.fill: parent
        active: root.category === "clear" && root.isDay
        sourceComponent: Item {
            anchors.centerIn: parent
            Item {
                anchors.centerIn: parent
                Repeater {
                    model: 12
                    delegate: Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        width: 3
                        height: 150
                        radius: 1.5
                        color: root.tintStrong
                        opacity: 0.10
                        rotation: index * 30
                    }
                }
                RotationAnimation on rotation {
                    from: 0; to: 360; duration: 70000
                    loops: Animation.Infinite; running: root.active
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 96; height: 96; radius: 48
                color: root.tintStrong
                opacity: 0.16
                SequentialAnimation on scale {
                    running: root.active
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.9; to: 1.12; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.12; to: 0.9; duration: 2200; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // Clear night: twinkling stars
    Loader {
        anchors.fill: parent
        active: root.category === "clear" && !root.isDay
        sourceComponent: Item {
            anchors.fill: parent
            Repeater {
                model: 16
                delegate: Rectangle {
                    required property int index
                    width: 2 + root.rand(index, 7) * 1.5
                    height: width
                    radius: width / 2
                    color: root.tintLight
                    x: root.rand(index, 8) * parent.width
                    y: root.rand(index, 9) * parent.height
                    opacity: 0.2
                    SequentialAnimation on opacity {
                        running: root.active
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.2; to: 0.9; duration: 700 + root.rand(index, 10) * 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.9; to: 0.2; duration: 700 + root.rand(index, 11) * 1400; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }
}
