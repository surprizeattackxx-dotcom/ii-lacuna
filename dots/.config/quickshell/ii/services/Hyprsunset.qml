pragma Singleton

import QtQuick
import qs.modules.common
import qs.services
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Material shell theme sync when Persistent.states.followNightLight is enabled

/**
 * Simple hyprsunset service with automatic mode.
 * In theory we don't need this because hyprsunset has a config file, but it somehow doesn't work.
 * It should also be possible to control it via hyprctl, but it doesn't work consistently either so we're just killing and launching.
 */
Singleton {
    id: root
    signal gammaChangeAttempt()

    readonly property real gammaLowerLimit: 25

    property string from: Config.options?.light?.night?.from ?? "19:00"
    property string to: Config.options?.light?.night?.to ?? "06:30"
    property bool automatic: Config.options?.light?.night?.automatic && (Config?.ready ?? true)
    property int colorTemperature: Config.options?.light?.night?.colorTemperature ?? 5000
    property int defaultColorTemperature: 6000
    property int gamma: 100
    property bool shouldBeOn
    property bool firstEvaluation: true
    property bool temperatureActive: false

    property int fromHour: Number(from.split(":")[0])
    property int fromMinute: Number(from.split(":")[1])
    property int toHour: Number(to.split(":")[0])
    property int toMinute: Number(to.split(":")[1])

    property int clockHour: DateTime.clock.hours
    property int clockMinute: DateTime.clock.minutes

    property var manualActive
    property int manualActiveHour
    property int manualActiveMinute

    onClockMinuteChanged: reEvaluate()
    onAutomaticChanged: {
        root.manualActive = undefined;
        root.firstEvaluation = true;
        reEvaluate();
    }

    function inBetween(t, from, to) {
        if (from < to) {
            return (t >= from && t <= to);
        } else {
            // Wrapped around midnight
            return (t >= from || t <= to);
        }
    }

    function reEvaluate() {
        const t = clockHour * 60 + clockMinute;
        const from = fromHour * 60 + fromMinute;
        const to = toHour * 60 + toMinute;

        root.shouldBeOn = inBetween(t, from, to);
        if (firstEvaluation) {
            firstEvaluation = false;
            root.ensureState();
        }
    }

    onShouldBeOnChanged: ensureState()
    function ensureState() {
        // console.log("[Hyprsunset] Ensuring state:", root.shouldBeOn, "Automatic mode:", root.automatic);
        if (!root.automatic || root.manualActive !== undefined)
            return;
        if (root.shouldBeOn) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    function killHyprsunset() {
        Quickshell.execDetached(["bash", "-c", "pkill hyprsunset 2>/dev/null || true"]);
    }

    function startHyprsunsetWithArgs(args) {
        root.killHyprsunset();
        Quickshell.execDetached(["bash", "-c", `sleep 0.1 && hyprsunset ${args}`]);
    }

    // Detect running state on startup (before first evaluation settles)
    Process {
        id: startupStateProc
        running: true
        command: ["bash", "-c", "pidof hyprsunset >/dev/null 2>&1 && echo running || echo stopped"]
        stdout: StdioCollector {
            id: startupCollector
            onStreamFinished: {
                if (root.firstEvaluation) {
                    root.temperatureActive = startupCollector.text.trim() === "running";
                }
            }
        }
    }

    function load() {
        root.ensureState();
    }

    Timer {
        id: updateHyprsunset
        interval: 100
        repeat: false
        onTriggered: {
            root.ensureState();
        }
    }

    function enableTemperature() {
        root.temperatureActive = true;
        root.startHyprsunsetWithArgs(`-t ${root.colorTemperature} -g ${root.gamma}`);
    }

    function disableTemperature() {
        root.temperatureActive = false;
        root.killHyprsunset();
    }

    function setGamma(gamma) {
        root.gamma = Math.max(root.gammaLowerLimit, Math.min(100, gamma));
        root.gammaChangeAttempt();
        if (root.temperatureActive) {
            root.startHyprsunsetWithArgs(`-t ${root.colorTemperature} -g ${root.gamma}`);
        }
    }

    function toggleTemperature(active = undefined) {
        if (root.manualActive === undefined) {
            root.manualActive = root.temperatureActive;
            root.manualActiveHour = root.clockHour;
            root.manualActiveMinute = root.clockMinute;
        }

        root.manualActive = active !== undefined ? active : !root.manualActive;
        if (root.manualActive) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    // Change temp
    Connections {
        target: Config.options.light.night
        function onColorTemperatureChanged() {
            if (!root.temperatureActive) return;
            root.startHyprsunsetWithArgs(`-t ${Config.options.light.night.colorTemperature} -g ${root.gamma}`);
        }
    }

    // Sync bar / sidebars / notification popups with Night Light (toggle_darkmode.sh → colors.json → Appearance)
    Process {
        id: nightLightThemeProc
        command: []
        onExited: () => MaterialThemeLoader.reloadAfterExternalColorChange()
    }

    function runNightLightThemeSync() {
        if (!Persistent.ready || !Persistent.states.followNightLight)
            return;
        // Wait for Config before syncing — colorMode may not be resolved yet.
        if (!Config.ready) {
            nightLightThemeDebounce.restart();
            return;
        }
        // Ensure time-of-day evaluation has settled so temperatureActive
        // reflects the correct state, not stale fetchProc results from before reload.
        root.reEvaluate();
        root.ensureState();
        // Night light on (warm filter) → dark shell; off → light.
        const wantDark = root.temperatureActive;
        if (wantDark === Appearance.m3colors.darkmode) {
            MaterialThemeLoader.reloadAfterExternalColorChange();
            return;
        }
        nightLightThemeProc.command = ["bash", Directories.darkModeToggleScriptPath, wantDark ? "dark" : "light"];
        nightLightThemeProc.running = true;
    }

    Timer {
        id: nightLightThemeDebounce
        interval: 220
        repeat: false
        onTriggered: root.runNightLightThemeSync()
    }

    Connections {
        target: root
        function onTemperatureActiveChanged() {
            if (Persistent.ready && Persistent.states.followNightLight)
                nightLightThemeDebounce.restart();
        }
    }

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (Persistent.ready && Persistent.states.followNightLight)
                nightLightThemeDebounce.restart();
        }
    }

    Connections {
        target: Persistent.states
        function onFollowNightLightChanged() {
            if (!Persistent.ready)
                return;
            if (Persistent.states.followNightLight)
                nightLightThemeDebounce.restart();
        }
    }
}
