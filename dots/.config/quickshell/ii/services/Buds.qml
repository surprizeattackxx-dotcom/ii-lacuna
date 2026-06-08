pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/ii/scripts/buds/buds.py"

    readonly property var device: BluetoothStatus.connectedDevices.find(d => /buds|galaxy/i.test(d.name)) ?? null
    readonly property bool available: device !== null
    readonly property string deviceName: device?.name ?? "Galaxy Buds"

    property bool loading: false
    property bool parsed: false
    property int batteryLeft: 0
    property int batteryRight: 0
    property int batteryCase: 0
    property string noise: "off"
    property string equalizer: "normal"
    property bool touchLocked: false
    property bool wearingLeft: false
    property bool wearingRight: false

    onAvailableChanged: if (available) refresh()

    function refresh() {
        if (!available) return;
        loading = true;
        statusProc.running = false;
        statusProc.running = true;
    }

    function setNoise(mode) {
        Quickshell.execDetached(["python3", script, "noise", mode]);
        noise = mode;
        refreshTimer.restart();
    }
    function setEqualizer(preset) {
        Quickshell.execDetached(["python3", script, "eq", preset]);
        equalizer = preset;
        refreshTimer.restart();
    }
    function setLock(locked) {
        Quickshell.execDetached(["python3", script, "lock", locked ? "on" : "off"]);
        touchLocked = locked;
        refreshTimer.restart();
    }
    property bool finding: false
    function toggleFind() {
        finding = !finding;
        Quickshell.execDetached(["python3", script, "find", finding ? "on" : "off"]);
    }

    Timer { id: refreshTimer; interval: 1400; onTriggered: root.refresh() }

    Process {
        id: statusProc
        command: ["python3", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const d = JSON.parse(text);
                    root.parsed = d.parsed ?? false;
                    if (!root.parsed) return;
                    root.batteryLeft = d.battery_left;
                    root.batteryRight = d.battery_right;
                    root.batteryCase = d.battery_case;
                    root.noise = d.noise;
                    root.equalizer = d.equalizer;
                    root.touchLocked = d.touch_locked;
                    root.wearingLeft = d.wearing_left;
                    root.wearingRight = d.wearing_right;
                } catch (e) {}
            }
        }
    }
}
