pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Services.System

// Region selector controller (ported from illogical-impulse).
// Holds the reactive open-state + current action/mode; the actual per-screen
// overlay is instantiated by RegionSelectorHost (loaded from shell.qml).
Singleton {
    id: root

    // Reactive — the host's Loader binds its `active` to this.
    property bool open: false
    property int action: ScreenshotService.Action.Copy
    property int selectionMode: 0 // 0: RectCorners, 1: Circle

    function dismiss() {
        root.open = false;
    }

    function setOpen(open, newAction, newSelectionMode) {
        if (open) {
            root.action = newAction;
            root.selectionMode = newSelectionMode;
        }
        root.open = open;
    }

    function screenshot() {
        root.setOpen(true, ScreenshotService.Action.Copy, 0);
    }

    function search() {
        let useCircle = Settings.data.regionSelector?.imageSearch?.useCircleSelection ?? false;
        root.setOpen(true, ScreenshotService.Action.Search, useCircle ? 1 : 0);
    }

    function ocr() {
        root.setOpen(true, ScreenshotService.Action.CharRecognition, 0);
    }

    // Record toggles: if the overlay is already up, re-trigger so the overlay's
    // "is wf-recorder running?" check stops an in-progress recording.
    function record() {
        root.action = ScreenshotService.Action.Record;
        root.selectionMode = 0;
        root.open = !root.open;
        if (!root.open)
            root.open = true;
    }

    function recordWithSound() {
        root.action = ScreenshotService.Action.RecordWithSound;
        root.selectionMode = 0;
        root.open = !root.open;
        if (!root.open)
            root.open = true;
    }

    IpcHandler {
        target: "region"

        function screenshot() {
            root.screenshot();
        }
        function search() {
            root.search();
        }
        function ocr() {
            root.ocr();
        }
        function record() {
            root.record();
        }
        function recordWithSound() {
            root.recordWithSound();
        }
    }

    GlobalShortcut {
        name: "regionScreenshot"
        description: "Takes a screenshot of the selected region"
        onPressed: root.screenshot()
    }
    GlobalShortcut {
        name: "regionSearch"
        description: "Searches the selected region"
        onPressed: root.search()
    }
    GlobalShortcut {
        name: "regionOcr"
        description: "Recognizes text in the selected region"
        onPressed: root.ocr()
    }
    GlobalShortcut {
        name: "regionRecord"
        description: "Records the selected region"
        onPressed: root.record()
    }
    GlobalShortcut {
        name: "regionRecordWithSound"
        description: "Records the selected region with sound"
        onPressed: root.recordWithSound()
    }
}
