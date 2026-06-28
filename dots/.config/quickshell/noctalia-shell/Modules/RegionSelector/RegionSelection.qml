pragma ComponentBehavior: Bound
import qs.Commons
import qs.Services.System
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Native region selector overlay (ported from illogical-impulse).
// Freezes the screen with ScreencopyView, lets the user drag a rectangle,
// click a detected window/layer/content region, or freehand a circle, then
// routes the crop to copy / annotate / reverse-search / OCR / record via
// ScreenshotService.getCommand.
PanelWindow {
    id: root
    visible: false
    color: "transparent"
    WlrLayershell.namespace: "noctalia:regionSelector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    enum SelectionMode { RectCorners, Circle }
    enum Phase { Select, Post }
    // action is a ScreenshotService.Action value.
    property int action: ScreenshotService.Action.Copy
    property int selectionMode: RegionSelection.SelectionMode.RectCorners
    property int phase: RegionSelection.Phase.Select
    signal dismiss()

    // Styles
    property string screenshotDir: ScreenshotService.tempDir
    property color overlayColor: Qt.rgba(0, 0, 0, 0.4)
    property color brightText: Color.mOnSurface
    property color brightSecondary: Color.mPrimary
    property color brightTertiary: Qt.lighter(Color.mPrimary)
    property color selectionBorderColor: Qt.tint(brightText, Qt.rgba(brightSecondary.r, brightSecondary.g, brightSecondary.b, 0.5))
    property color selectionFillColor: "#33ffffff"
    property color windowBorderColor: brightSecondary
    property color windowFillColor: Qt.rgba(windowBorderColor.r, windowBorderColor.g, windowBorderColor.b, 0.15)
    property color imageBorderColor: brightTertiary
    property color imageFillColor: Qt.rgba(imageBorderColor.r, imageBorderColor.g, imageBorderColor.b, 0.15)
    property int windowRounding: Style.radiusS

    property real targetRegionOpacity: Settings.data.regionSelector?.targetRegions?.opacity ?? 0.3
    property real contentRegionOpacity: Settings.data.regionSelector?.targetRegions?.contentRegionOpacity ?? 0.8

    // Screen & interaction vars
    readonly property HyprlandMonitor hyprlandMonitor: Hyprland.monitorFor(screen)
    readonly property real monitorScale: hyprlandMonitor ? hyprlandMonitor.scale : 1
    readonly property real monitorOffsetX: hyprlandMonitor ? hyprlandMonitor.x : 0
    readonly property real monitorOffsetY: hyprlandMonitor ? hyprlandMonitor.y : 0
    property int activeWorkspaceId: hyprlandMonitor && hyprlandMonitor.activeWorkspace ? hyprlandMonitor.activeWorkspace.id : 0
    property string screenshotPath: `${root.screenshotDir}/screenshot-${screen.name}.png`
    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property real dragDiffX: 0
    property real dragDiffY: 0
    property bool draggedAway: (dragDiffX !== 0 || dragDiffY !== 0)
    property bool dragging: false
    property list<point> points: []
    property var mouseButton: null
    property var imageRegions: []
    readonly property real falsePositivePreventionRatio: 0.5

    // Config flags
    property bool isCircleSelection: (root.selectionMode === RegionSelection.SelectionMode.Circle)
    property bool enableWindowRegions: (Settings.data.regionSelector?.targetRegions?.windows ?? true) && !isCircleSelection
    property bool enableLayerRegions: (Settings.data.regionSelector?.targetRegions?.layers ?? false) && !isCircleSelection
    property bool enableContentRegions: (Settings.data.regionSelector?.targetRegions?.content ?? true) && !isCircleSelection
    property bool showLabel: Settings.data.regionSelector?.targetRegions?.showLabel ?? false

    // ─── Window / layer data (replaces ii's HyprlandData) ───
    property var rawWindows: []
    property var rawLayers: ({})

    readonly property list<var> layerRegions: {
        const layersOfThisMonitor = root.rawLayers[root.hyprlandMonitor ? root.hyprlandMonitor.name : ""]
        const topLayers = layersOfThisMonitor?.levels?.["2"]
        if (!topLayers) return [];
        return topLayers
            .filter(layer => !(layer.namespace.includes(":bar") || layer.namespace.includes("bar-") || layer.namespace.includes("dock") || layer.namespace.includes("regionSelector")))
            .map(layer => ({
                at: [layer.x - root.monitorOffsetX, layer.y - root.monitorOffsetY],
                size: [layer.w, layer.h],
                namespace: layer.namespace,
            }));
    }
    readonly property list<var> windowRegions: {
        const onThisWorkspace = root.rawWindows.filter(w => w.workspace && w.workspace.id === root.activeWorkspaceId);
        const sorted = [...onThisWorkspace].sort((a, b) => (a.floating === b.floating) ? 0 : (a.floating ? -1 : 1));
        const filtered = RegionFunctions.filterWindowRegionsByLayers(
            sorted.map(w => ({ at: w.at, size: w.size, class: w.class, title: w.title })),
            root.layerRegions.map(l => ({ at: [l.at[0] + root.monitorOffsetX, l.at[1] + root.monitorOffsetY], size: l.size }))
        );
        return filtered.map(w => ({
            at: [w.at[0] - root.monitorOffsetX, w.at[1] - root.monitorOffsetY],
            size: [w.size[0], w.size[1]],
            class: w.class,
            title: w.title,
        }));
    }

    Process {
        id: clientsProc
        running: true
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                try { root.rawWindows = JSON.parse(clientsCollector.text); } catch (e) {}
            }
        }
    }
    Process {
        id: layersProc
        running: true
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                try { root.rawLayers = JSON.parse(layersCollector.text); } catch (e) {}
            }
        }
    }

    // Target region
    property real targetedRegionX: -1
    property real targetedRegionY: -1
    property real targetedRegionWidth: 0
    property real targetedRegionHeight: 0
    function targetedRegionValid() {
        return (root.targetedRegionX >= 0 && root.targetedRegionY >= 0)
    }
    function setRegionToTargeted() {
        const padding = Settings.data.regionSelector?.targetRegions?.selectionPadding ?? 5;
        root.dragStartX = root.targetedRegionX - padding;
        root.dragStartY = root.targetedRegionY - padding;
        root.draggingX = root.targetedRegionX + root.targetedRegionWidth + padding;
        root.draggingY = root.targetedRegionY + root.targetedRegionHeight + padding;
    }

    function updateTargetedRegion(x, y) {
        const hit = (region) => region.at[0] <= x && x <= region.at[0] + region.size[0] && region.at[1] <= y && y <= region.at[1] + region.size[1];
        const apply = (r) => {
            root.targetedRegionX = r.at[0];
            root.targetedRegionY = r.at[1];
            root.targetedRegionWidth = r.size[0];
            root.targetedRegionHeight = r.size[1];
        };
        const clickedRegion = root.imageRegions.find(hit);
        if (clickedRegion) { apply(clickedRegion); return; }
        const clickedLayer = root.layerRegions.find(hit);
        if (clickedLayer) { apply(clickedLayer); return; }
        const clickedWindow = root.windowRegions.find(hit);
        if (clickedWindow) { apply(clickedWindow); return; }
        root.targetedRegionX = -1;
        root.targetedRegionY = -1;
        root.targetedRegionWidth = 0;
        root.targetedRegionHeight = 0;
    }

    property real regionWidth: Math.abs(draggingX - dragStartX)
    property real regionHeight: Math.abs(draggingY - dragStartY)
    property real regionX: Math.min(dragStartX, draggingX)
    property real regionY: Math.min(dragStartY, draggingY)

    // ─── Screenshot freeze (grim to a temp PNG used by magick crop) ───
    Process {
        id: screenshotProc
        running: true
        command: ["bash", "-c", `mkdir -p ${ScreenshotService.shellEscape(root.screenshotDir)} && grim -o ${ScreenshotService.shellEscape(screen.name)} ${ScreenshotService.shellEscape(root.screenshotPath)}`]
        onExited: (exitCode, exitStatus) => {
            if (root.enableContentRegions) imageDetectionProcess.running = true;
            root.preparationDone = !checkRecordingProc.running;
        }
    }
    property bool isRecording: root.action === ScreenshotService.Action.Record || root.action === ScreenshotService.Action.RecordWithSound
    property bool recordingShouldStop: false
    Process {
        id: checkRecordingProc
        running: root.isRecording
        command: ["pidof", "wf-recorder"]
        onExited: (exitCode, exitStatus) => {
            root.preparationDone = !screenshotProc.running
            root.recordingShouldStop = (exitCode === 0);
        }
    }
    property bool preparationDone: false
    onPreparationDoneChanged: {
        if (!preparationDone) return;
        // Already recording -> this invocation just stops it.
        if (root.isRecording && root.recordingShouldStop) {
            Quickshell.execDetached([ScreenshotService.recordScriptPath]);
            root.dismiss();
            return;
        }
        root.visible = true;
    }

    // ─── Content (image) region detection (best-effort; opencv venv) ───
    Process {
        id: imageDetectionProcess
        command: ["bash", "-c", `${Quickshell.shellPath("Scripts/bash/find-regions.sh")} `
            + `--hyprctl `
            + `--image ${ScreenshotService.shellEscape(root.screenshotPath)} `
            + `--max-width ${Math.round(root.screen.width * root.falsePositivePreventionRatio)} `
            + `--max-height ${Math.round(root.screen.height * root.falsePositivePreventionRatio)}`]
        stdout: StdioCollector {
            id: imageDimensionCollector
            onStreamFinished: {
                try {
                    root.imageRegions = RegionFunctions.filterImageRegions(
                        JSON.parse(imageDimensionCollector.text),
                        root.windowRegions
                    );
                } catch (e) { root.imageRegions = []; }
            }
        }
    }

    // Execution after selection
    function snip() {
        if (root.regionWidth <= 0 || root.regionHeight <= 0) {
            root.dismiss();
            return;
        }
        // Clamp to screen bounds
        var rX = Math.max(0, Math.min(root.regionX, root.screen.width - root.regionWidth));
        var rY = Math.max(0, Math.min(root.regionY, root.screen.height - root.regionHeight));
        var rW = Math.max(0, Math.min(root.regionWidth, root.screen.width - rX));
        var rH = Math.max(0, Math.min(root.regionHeight, root.screen.height - rY));

        // Copy with RMB -> annotate
        var act = root.action;
        if (act === ScreenshotService.Action.Copy || act === ScreenshotService.Action.Edit) {
            act = root.mouseButton === Qt.RightButton ? ScreenshotService.Action.Edit : ScreenshotService.Action.Copy;
        }

        const saveDir = Settings.data.regionSelector?.screenshotSaveDir ?? "";
        const command = ScreenshotService.getCommand(
            rX * root.monitorScale,
            rY * root.monitorScale,
            rW * root.monitorScale,
            rH * root.monitorScale,
            root.screenshotPath,
            act,
            saveDir
        );
        if (command && command.length > 0) Quickshell.execDetached(command);
        root.dismiss();
    }

    ScreencopyView { // For freezing
        anchors.fill: parent
        live: false
        captureSource: root.screen
        visible: root.phase === RegionSelection.Phase.Select

        focus: root.visible
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) root.dismiss();
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true

        onPressed: (mouse) => {
            root.dragStartX = mouse.x;
            root.dragStartY = mouse.y;
            root.draggingX = mouse.x;
            root.draggingY = mouse.y;
            root.dragging = true;
            root.mouseButton = mouse.button;
        }
        onReleased: (mouse) => {
            // Click (no drag) -> select targeted region
            if (root.draggingX === root.dragStartX && root.draggingY === root.dragStartY) {
                if (root.targetedRegionValid()) {
                    root.setRegionToTargeted();
                }
            } else if (root.selectionMode === RegionSelection.SelectionMode.Circle) {
                const padding = (Settings.data.regionSelector?.circle?.padding ?? 10) + (Settings.data.regionSelector?.circle?.strokeWidth ?? 6) / 2;
                const dragPoints = (root.points.length > 0) ? root.points : [{ x: mouseArea.mouseX, y: mouseArea.mouseY }];
                const maxX = Math.max(...dragPoints.map(p => p.x));
                const minX = Math.min(...dragPoints.map(p => p.x));
                const maxY = Math.max(...dragPoints.map(p => p.y));
                const minY = Math.min(...dragPoints.map(p => p.y));
                root.dragStartX = minX - padding;
                root.dragStartY = minY - padding;
                root.draggingX = maxX + padding;
                root.draggingY = maxY + padding;
            }
            root.snip();
        }
        onPositionChanged: (mouse) => {
            root.updateTargetedRegion(mouse.x, mouse.y);
            if (!root.dragging) return;
            root.draggingX = mouse.x;
            root.draggingY = mouse.y;
            root.dragDiffX = mouse.x - root.dragStartX;
            root.dragDiffY = mouse.y - root.dragStartY;
            root.points.push({ x: mouse.x, y: mouse.y });
        }

        Loader {
            z: 2
            anchors.fill: parent
            active: root.selectionMode === RegionSelection.SelectionMode.RectCorners
            sourceComponent: RectCornersSelectionDetails {
                regionX: root.regionX
                regionY: root.regionY
                regionWidth: root.regionWidth
                regionHeight: root.regionHeight
                mouseX: mouseArea.mouseX
                mouseY: mouseArea.mouseY
                color: root.selectionBorderColor
                overlayColor: root.overlayColor
                breathingBorderOnly: root.phase === RegionSelection.Phase.Post
            }
        }

        Loader {
            z: 2
            anchors.fill: parent
            active: root.selectionMode === RegionSelection.SelectionMode.Circle
            sourceComponent: CircleSelectionDetails {
                color: root.selectionBorderColor
                overlayColor: root.overlayColor
                points: root.points
            }
        }

        CursorGuide {
            z: 9999
            visible: root.phase === RegionSelection.Phase.Select
            x: root.dragging ? root.regionX + root.regionWidth : mouseArea.mouseX
            y: root.dragging ? root.regionY + root.regionHeight : mouseArea.mouseY
            action: root.action
            selectionMode: root.selectionMode
        }

        // Window regions
        Repeater {
            model: ScriptModel {
                values: (root.phase === RegionSelection.Phase.Select && root.enableWindowRegions) ? root.windowRegions : []
            }
            delegate: TargetRegion {
                z: 2
                required property var modelData
                clientDimensions: modelData
                showIcon: true
                showLabel: root.showLabel
                targeted: !root.draggedAway &&
                    (root.targetedRegionX === modelData.at[0]
                    && root.targetedRegionY === modelData.at[1]
                    && root.targetedRegionWidth === modelData.size[0]
                    && root.targetedRegionHeight === modelData.size[1])
                opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                borderColor: root.windowBorderColor
                fillColor: targeted ? root.windowFillColor : "transparent"
                text: `${modelData.class}`
                radius: root.windowRounding
            }
        }

        // Layer regions
        Repeater {
            model: ScriptModel {
                values: (root.phase === RegionSelection.Phase.Select && root.enableLayerRegions) ? root.layerRegions : []
            }
            delegate: TargetRegion {
                z: 3
                required property var modelData
                clientDimensions: modelData
                showLabel: root.showLabel
                targeted: !root.draggedAway &&
                    (root.targetedRegionX === modelData.at[0]
                    && root.targetedRegionY === modelData.at[1]
                    && root.targetedRegionWidth === modelData.size[0]
                    && root.targetedRegionHeight === modelData.size[1])
                opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                borderColor: root.windowBorderColor
                fillColor: targeted ? root.windowFillColor : "transparent"
                text: `${modelData.namespace}`
                radius: root.windowRounding
            }
        }

        // Content regions
        Repeater {
            model: ScriptModel {
                values: (root.phase === RegionSelection.Phase.Select && root.enableContentRegions) ? root.imageRegions : []
            }
            delegate: TargetRegion {
                z: 4
                required property var modelData
                clientDimensions: modelData
                showLabel: root.showLabel
                targeted: !root.draggedAway &&
                    (root.targetedRegionX === modelData.at[0]
                    && root.targetedRegionY === modelData.at[1]
                    && root.targetedRegionWidth === modelData.size[0]
                    && root.targetedRegionHeight === modelData.size[1])
                opacity: root.draggedAway ? 0 : root.contentRegionOpacity
                borderColor: root.imageBorderColor
                fillColor: targeted ? root.imageFillColor : "transparent"
                text: "Content region"
            }
        }

        // Controls
        Row {
            id: regionSelectionControls
            z: 10
            visible: root.phase === RegionSelection.Phase.Select
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 8
            }
            opacity: root.visible ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            spacing: 6

            OptionsToolbar {
                id: optionsToolbar
                action: root.action
                Component.onCompleted: selectionMode = root.selectionMode
                onSelectionModeChanged: root.selectionMode = selectionMode
                onDismiss: root.dismiss()
                Connections {
                    target: root
                    function onSelectionModeChanged() { optionsToolbar.selectionMode = root.selectionMode; }
                }
            }
        }
    }
}
