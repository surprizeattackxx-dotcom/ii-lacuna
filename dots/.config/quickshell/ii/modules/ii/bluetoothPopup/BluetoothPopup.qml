import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.bar as Bar

PanelWindow {
    id: root
    anchors { top: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.namespace: "qs-popups"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    Bar.MatugenColors { id: theme }

    readonly property real cardWidth: 360
    readonly property real cardHeight: 96
    implicitWidth: cardWidth + 48
    implicitHeight: cardHeight + 48

    property var currentDevice: null
    property bool shown: false

    readonly property bool batteryAvailable: currentDevice?.batteryAvailable ?? false
    readonly property real battery: currentDevice?.battery ?? 0
    readonly property string deviceName: currentDevice?.name ?? Translation.tr("Bluetooth device")
    readonly property string deviceSymbol: Icons.getBluetoothDeviceMaterialSymbol(currentDevice?.icon ?? "", currentDevice?.name ?? "")

    function batteryColor(v) {
        if (v <= 0.15) return theme.red;
        if (v <= 0.35) return theme.yellow;
        return theme.green;
    }

    function show(device) {
        if (!device) return;
        currentDevice = device;
        shown = true;
        hideTimer.restart();
    }

    function dismiss() {
        shown = false;
        hideTimer.stop();
    }

    Timer { id: hideTimer; interval: 5000; onTriggered: root.dismiss() }

    // --- connection detection ---
    property bool ready: false
    property var knownConnected: []
    property var connList: BluetoothStatus.connectedDevices

    Component.onCompleted: knownConnected = connList.map(d => d.address)
    Timer { interval: 2500; running: true; onTriggered: root.ready = true }

    onConnListChanged: {
        const cur = connList.map(d => d.address);
        if (!ready) { knownConnected = cur; return; }
        const added = cur.filter(a => knownConnected.indexOf(a) === -1);
        knownConnected = cur;
        if (added.length > 0) {
            const dev = BluetoothStatus.deviceForAddress(added[added.length - 1]);
            if (dev) show(dev);
        }
    }

    IpcHandler {
        target: "bluetoothPopup"
        function show(): void {
            const dev = BluetoothStatus.firstActiveDevice ?? BluetoothStatus.connectedDevices[0] ?? null;
            if (dev) root.show(dev);
        }
        function demo(): void {
            root.currentDevice = demoDevice;
            root.shown = true;
            hideTimer.restart();
        }
        function hide(): void { root.dismiss() }
    }

    QtObject {
        id: demoDevice
        readonly property string name: "Pixel Buds Pro"
        readonly property string icon: "audio-headphones"
        readonly property bool batteryAvailable: true
        readonly property real battery: 0.82
        readonly property bool connected: true
        readonly property string address: "demo"
    }

    Item {
        id: cardWrapper
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 48
        width: root.cardWidth
        height: root.cardHeight

        opacity: root.shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

        transform: Translate {
            y: root.shown ? 0 : -28
            Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 1, 0.3, 1] } }
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.97)
            border.width: 1
            border.color: Qt.rgba(theme.mauve.r, theme.mauve.g, theme.mauve.b, 0.4)

            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowBlur: 1.0
                shadowOpacity: 0.45
                shadowVerticalOffset: 8
            }

            Item {
                anchors.fill: parent
                anchors.margins: 16

                Rectangle {
                    id: iconContainer
                    width: 56; height: 56; radius: 16
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(theme.mauve.r, theme.mauve.g, theme.mauve.b, 0.18)

                    Text {
                        anchors.centerIn: parent
                        text: root.deviceSymbol
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 30
                        color: theme.mauve
                    }
                }

                Column {
                    anchors.left: iconContainer.right
                    anchors.leftMargin: 14
                    anchors.right: batteryRing.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: root.deviceName
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: theme.text
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.batteryAvailable
                            ? Translation.tr("Connected • %1%").arg(Math.round(root.battery * 100))
                            : Translation.tr("Connected")
                        font.pixelSize: 13
                        color: theme.subtext0
                        elide: Text.ElideRight
                    }
                }

                CircularProgress {
                    id: batteryRing
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.batteryAvailable
                    implicitSize: 52
                    lineWidth: 5
                    value: root.battery
                    colPrimary: root.batteryColor(root.battery)
                    colSecondary: Qt.rgba(theme.overlay0.r, theme.overlay0.g, theme.overlay0.b, 0.35)

                    Text {
                        anchors.centerIn: parent
                        text: Math.round(root.battery * 100)
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: theme.text
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.dismiss()
                hoverEnabled: true
                onEntered: hideTimer.stop()
                onExited: if (root.shown) hideTimer.restart()
            }
        }
    }
}
