import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.modules.ii.bar
import qs.modules.common
import QtQuick.Controls

Item {
    id: window
    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    // Helper function scoped to the root Item
    function s(val) {
        return scaler.s(val);
    }

    function sliderColor(pct) {
        if (pct < 0.33) return window.blue;
        if (pct < 0.66) return window.teal;
        return window.yellow;
    }

    // -------------------------------------------------------------------------
    // COLORS (Dynamic Matugen Palette)
    // -------------------------------------------------------------------------
    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2

    readonly property color mauve: _theme.mauve
    readonly property color blue: _theme.blue
    readonly property color pink: _theme.pink
    readonly property color teal: _theme.teal
    readonly property color yellow: _theme.yellow
    readonly property color peach: _theme.peach
    readonly property color green: _theme.green
    readonly property color red: _theme.red
    readonly property color sapphire: _theme.sapphire

    // -------------------------------------------------------------------------
    // STATE & MATH
    // -------------------------------------------------------------------------
    property int activeEditIndex: 0
    // Virtual mapping scale (1920px -> 192 virtual units)
    property real uiScale: 0.10

    // Wayland Absolute Anchor tracking
    property int originalLayoutOriginX: 0
    property int originalLayoutOriginY: 0

    ListModel {
        id: monitorsModel
    }

    // activeEditIndex can lag behind the model during its clear/repopulate cycle,
    // so bounds-check before get() — an out-of-range get() returns undefined.
    readonly property var activeMon: (activeEditIndex >= 0 && activeEditIndex < monitorsModel.count)
        ? monitorsModel.get(activeEditIndex)
        : null

    property color selectedResAccent: window.mauve
    property color selectedRateAccent: window.blue

    readonly property real sdrValue: activeMon ? activeMon.sdrBrightness : 1.0
    readonly property real satValue: activeMon ? activeMon.sdrSaturation : 1.0

    property real currentSimW: monitorsModel.count > 0 ? monitorsModel.get(0).resW : 1920
    property real currentSimH: monitorsModel.count > 0 ? monitorsModel.get(0).resH : 1080

    // -------------------------------------------------------------------------
    // FLUID STARTUP ANIMATIONS
    // -------------------------------------------------------------------------
    property real introProgress: 0.0
    property real monitorScale: 0.85
    property real uiYOffset: window.s(25)

    ParallelAnimation {
        id: menuTransitionAnim
        NumberAnimation { target: window; property: "introProgress"; from: 0.0; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: startupAnim.start()

    ParallelAnimation {
        id: startupAnim
        NumberAnimation { target: window; property: "introProgress"; from: 0.0; to: 1.0; duration: 900; easing.type: Easing.OutQuint }
        NumberAnimation { target: window; property: "monitorScale"; from: 0.85; to: 1.0; duration: 1200; easing.type: Easing.OutQuint }
        NumberAnimation { target: window; property: "uiYOffset"; from: window.s(25); to: 0; duration: 1800; easing.type: Easing.OutQuint }
    }
    property bool applyHovered: false
    property bool applyPressed: false

    onActiveEditIndexChanged: {
        menuTransitionAnim.restart();
    }

    // -------------------------------------------------------------------------
    // MATHEMATICAL PERIMETER GLUE (Virtual Coordinates - Do not scale)
    // -------------------------------------------------------------------------
    function isOverlapping(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
    }

    function isOverlappingAny(x, y, w, h, skipIdx) {
        for (let i = 0; i < monitorsModel.count; i++) {
            if (i === skipIdx) continue;
            let m = monitorsModel.get(i);
            let mW = (m.resW / m.sysScale) * window.uiScale;
            let mH = (m.resH / m.sysScale) * window.uiScale;
            if (isOverlapping(x, y, w, h, m.uiX, m.uiY, mW, mH)) return true;
        }
        return false;
    }

    function getPerimeterSnap(pX, pY, sX, sY, sW, sH, mW, mH, snapT) {
        let edges = [
            { x1: sX - mW, x2: sX + sW, y1: sY - mH, y2: sY - mH }, // Top Edge
            { x1: sX - mW, x2: sX + sW, y1: sY + sH, y2: sY + sH }, // Bottom Edge
            { x1: sX - mW, x2: sX - mW, y1: sY - mH, y2: sY + sH }, // Left Edge
            { x1: sX + sW, x2: sX + sW, y1: sY - mH, y2: sY + sH }  // Right Edge
        ];

        let bestX = pX;
        let bestY = pY;
        let minDist = 999999;

        for (let i = 0; i < 4; i++) {
            let e = edges[i];

            let cx = Math.max(e.x1, Math.min(pX, e.x2));
            let cy = Math.max(e.y1, Math.min(pY, e.y2));

            if (Math.abs(cx - sX) < snapT) cx = sX;
            if (Math.abs(cx - (sX + sW - mW)) < snapT) cx = sX + sW - mW;
            if (Math.abs(cx - (sX + sW/2 - mW/2)) < snapT) cx = sX + sW/2 - mW/2;

            if (Math.abs(cy - sY) < snapT) cy = sY;
            if (Math.abs(cy - (sY + sH - mH)) < snapT) cy = sY + sH - mH;
            if (Math.abs(cy - (sY + sH/2 - mH/2)) < snapT) cy = sY + sH/2 - mH/2;

            let dist = Math.hypot(pX - cx, pY - cy);
            if (dist < minDist) {
                minDist = dist;
                bestX = cx;
                bestY = cy;
            }
        }
        return { x: bestX, y: bestY };
    }

    function forceLayoutUpdate() {
        if (monitorsModel.count < 2) return;

        let mIdx = window.activeEditIndex;
        let mModel = monitorsModel.get(mIdx);
        let mW = (mModel.resW / mModel.sysScale) * window.uiScale;
        let mH = (mModel.resH / mModel.sysScale) * window.uiScale;

        let bestX = mModel.uiX;
        let bestY = mModel.uiY;
        let bestDist = 999999;

        // Loop through ALL other monitors to find the closest valid snap
        for (let i = 0; i < monitorsModel.count; i++) {
            if (i === mIdx) continue;
            let sModel = monitorsModel.get(i);
            let sW = (sModel.resW / sModel.sysScale) * window.uiScale;
            let sH = (sModel.resH / sModel.sysScale) * window.uiScale;

            let snapped = window.getPerimeterSnap(
                mModel.uiX, mModel.uiY,
                sModel.uiX, sModel.uiY,
                sW, sH, mW, mH, 20
            );

            let dist = Math.hypot(snapped.x - mModel.uiX, snapped.y - mModel.uiY);
            if (dist < bestDist) {
                bestDist = dist;
                bestX = snapped.x;
                bestY = snapped.y;
            }
        }

        monitorsModel.setProperty(mIdx, "uiX", bestX);
        monitorsModel.setProperty(mIdx, "uiY", bestY);
    }

    property var cachedLuaMonitors: ({})
    property var cachedDisabledMonitors: ([])
    readonly property string disabledFilePath: Directories.state + "/user/generated/wallpaper/monitors_disabled.txt"

    function mergeDisabledFile(content) {
        let disabled = [];
        let lines = content.trim().split('\n');
        for (let i = 0; i < lines.length; i++) {
            let name = lines[i].trim();
            if (name) disabled.push(name);
        }
        window.cachedDisabledMonitors = disabled;
        for (let i = 0; i < monitorsModel.count; i++) {
            let m = monitorsModel.get(i);
            if (disabled.indexOf(m.name) >= 0) {
                monitorsModel.setProperty(i, "disabled", true);
            }
        }
    }

    function mergeLuaSettings(content) {
        let monitors = {};
        let regex = /hl\.monitor\(\{([\s\S]*?)\}\)/g;
        let match;
        while ((match = regex.exec(content)) !== null) {
            let block = match[1];
            let mon = {};
            let lines = block.split('\n');
            for (let line of lines) {
                line = line.trim();
                if (!line || line === '}' || line === '),') continue;
                let eqIdx = line.indexOf('=');
                if (eqIdx < 0) continue;
                let key = line.substring(0, eqIdx).trim();
                let val = line.substring(eqIdx + 1).trim().replace(/,$/, '');
                if (val.startsWith('"') && val.endsWith('"')) {
                    val = val.slice(1, -1);
                } else if (val === 'true') {
                    val = true;
                } else if (val === 'false') {
                    val = false;
                } else if (val.indexOf('.') >= 0) {
                    val = parseFloat(val);
                } else if (val.startsWith('{') && val.endsWith('}')) {
                    continue;
                } else {
                    let n = parseInt(val);
                    if (!isNaN(n)) val = n;
                }
                mon[key] = val;
            }
            if (mon.output) monitors[mon.output] = mon;
        }
        return monitors;
    }

    function readAndMergeMonitorConfig() {
        for (let i = 0; i < monitorsModel.count; i++) {
            let m = monitorsModel.get(i);
            let lua = window.cachedLuaMonitors[m.name];
            if (!lua) continue;
            if (lua.cm !== undefined) monitorsModel.setProperty(i, "cm", lua.cm);
            if (lua.bitdepth !== undefined) monitorsModel.setProperty(i, "bitdepth", lua.bitdepth);
            if (lua.sdrbrightness !== undefined) monitorsModel.setProperty(i, "sdrBrightness", lua.sdrbrightness);
            if (lua.sdrsaturation !== undefined) monitorsModel.setProperty(i, "sdrSaturation", lua.sdrsaturation);
        }
        // monitors_disabled.txt is the authoritative source for disabled state
        let disabled = window.cachedDisabledMonitors;
        for (let i = 0; i < monitorsModel.count; i++) {
            let m = monitorsModel.get(i);
            monitorsModel.setProperty(i, "disabled", disabled.indexOf(m.name) >= 0);
        }
    }

    Process {
        id: luaFileReader
        command: ["bash", "-c", "cat ~/.config/hypr/monitors.lua 2>/dev/null || echo ''"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim()) {
                    window.cachedLuaMonitors = window.mergeLuaSettings(this.text);
                    window.readAndMergeMonitorConfig();
                }
            }
        }
    }

    Process {
        id: disabledFileReader
        command: ["bash", "-c", "cat " + window.disabledFilePath + " 2>/dev/null || echo ''"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim()) {
                    window.mergeDisabledFile(this.text);
                }
                window.readAndMergeMonitorConfig();
                displayPoller.running = false;
                displayPoller.running = true;
            }
        }
    }

    Timer {
        id: delayedLayoutUpdate
        interval: 10
        running: false
        repeat: false
        onTriggered: window.forceLayoutUpdate()
    }

    // -------------------------------------------------------------------------
    // NATIVE SYSTEM PROCESSES
    // -------------------------------------------------------------------------
    Process {
        id: displayPoller
        command: ["hyprctl", "monitors", "all", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    monitorsModel.clear();

                    let minX = 999999, minY = 999999;

                    for (let i = 0; i < data.length; i++) {
                        if (data[i].x < minX) minX = data[i].x;
                        if (data[i].y < minY) minY = data[i].y;
                    }

                    window.originalLayoutOriginX = minX !== 999999 ? minX : 0;
                    window.originalLayoutOriginY = minY !== 999999 ? minY : 0;

                    for (let i = 0; i < data.length; i++) {
                        let scl = data[i].scale !== undefined ? data[i].scale : 1.0;
                        let normalizedX = (data[i].x - minX) * window.uiScale;
                        let normalizedY = (data[i].y - minY) * window.uiScale;

                        monitorsModel.append({
                            name: data[i].name,
                            resW: data[i].width,
                            resH: data[i].height,
                            sysScale: scl,
                            rate: Math.round(data[i].refreshRate).toString(),
                            uiX: normalizedX,
                            uiY: normalizedY,
                            vrr: 0,
                            bitdepth: 8,
                            cm: "auto",
                            hdrBrightness: -1,
                            sdrBrightness: 1.0,
                            sdrSaturation: 1.0,
                            disabled: data[i].disabled || false
                        });

                        if (data[i].focused) window.activeEditIndex = i;
                    }

                    // Re-add disabled monitors that are no longer reported by hyprctl
                    let activeNames = [];
                    for (let i = 0; i < monitorsModel.count; i++) {
                        activeNames.push(monitorsModel.get(i).name);
                    }
                    for (let d = 0; d < window.cachedDisabledMonitors.length; d++) {
                        let disabledName = window.cachedDisabledMonitors[d];
                        if (activeNames.indexOf(disabledName) < 0) {
                            monitorsModel.append({
                                name: disabledName,
                                resW: 1920,
                                resH: 1080,
                                sysScale: 1.0,
                                rate: "60",
                                uiX: 0,
                                uiY: 0,
                                vrr: 0,
                                bitdepth: 8,
                                cm: "auto",
                                hdrBrightness: -1,
                                sdrBrightness: 1.0,
                                sdrSaturation: 1.0,
                                disabled: true
                            });
                            activeNames.push(disabledName);
                        }
                    }

                    window.forceLayoutUpdate();
                    window.readAndMergeMonitorConfig();
                } catch(e) {}
            }
        }
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * window.introProgress)
        opacity: window.introProgress
        clip: true

        // ==========================================
        // INTERACTIVE SELECTION AREA
        // ==========================================
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: window.s(20) + window.s(380) + window.s(10)
            anchors.rightMargin: window.s(30)
            height: parent.height - window.s(60)

            opacity: window.introProgress
            transform: Translate { y: window.uiYOffset }

            Flickable {
                anchors.fill: parent
                contentHeight: rightSideContainer.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: rightSideContainer
                    width: parent.width
                    spacing: window.s(12)

                    // --- RESOLUTION CARDS SECTION (VERTICAL) ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: window.s(10)

                        Text {
                            text: "RESOLUTION"
                            color: window.subtext0
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(12)
                        }

                        Repeater {
                            model: [
                                { resW: 3840, resH: 2160, label: "4K",   accent: window.pink },
                                { resW: 2560, resH: 1440, label: "QHD",  accent: window.mauve },
                                { resW: 1920, resH: 1080, label: "FHD",  accent: window.blue },
                                { resW: 1600, resH: 900,  label: "HD+",  accent: window.teal }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: window.s(48)
                                radius: window.s(12)

                                property bool isSel: {
                                    if (!window.activeMon) return false;
                                    return window.activeMon.resW === modelData.resW && window.activeMon.resH === modelData.resH;
                                }
                                property color accentColor: modelData.accent

                                color: isSel ? Qt.alpha(accentColor, 0.15) : (resMa.containsMouse ? window.surface0 : window.mantle)
                                border.color: isSel ? accentColor : (resMa.containsMouse ? window.surface1 : "transparent")
                                border.width: isSel ? 2 : 1

                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: window.s(12)
                                    spacing: window.s(8)

                                    Text {
                                        font.family: "JetBrains Mono"
                                        font.weight: isSel ? Font.Black : Font.Bold
                                        font.pixelSize: window.s(16)
                                        color: isSel ? accentColor : window.text
                                        text: modelData.label
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: window.s(12)
                                        color: isSel ? window.text : window.overlay0
                                        text: modelData.resW + "x" + modelData.resH
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }

                                scale: resMa.pressed ? 0.96 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutSine } }

                                MouseArea {
                                    id: resMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (monitorsModel.count > 0) {
                                            window.selectedResAccent = accentColor;
                                            monitorsModel.setProperty(window.activeEditIndex, "resW", modelData.resW);
                                            monitorsModel.setProperty(window.activeEditIndex, "resH", modelData.resH);
                                            delayedLayoutUpdate.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: window.s(15) }

                    // --- REFRESH RATE SLIDER SECTION ---
                    Item {
                        id: sliderContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(50)
                        Layout.leftMargin: window.s(10)
                        Layout.rightMargin: window.s(10)

                        property var rates: [60, 75, 100, 120, 144, 165, 180, 240, 360]
                        property var rateColors: [window.red, window.mauve, window.blue, window.sapphire, window.teal, window.pink, window.yellow, window.green, window.peach]

                        property int currentIndex: {
                            if (!window.activeMon) return 0;
                            let currentVal = parseInt(window.activeMon.rate) || 60;
                            let closestIdx = 0;
                            let minDiff = 9999;
                            for (let i = 0; i < rates.length; i++) {
                                let diff = Math.abs(rates[i] - currentVal);
                                if (diff < minDiff) {
                                    minDiff = diff;
                                    closestIdx = i;
                                }
                            }
                            return closestIdx;
                        }

                        property real visualPct: currentIndex / (rates.length - 1)

                        onCurrentIndexChanged: {
                            if (!sliderMa.pressed) visualPct = currentIndex / (rates.length - 1);
                        }

                        Rectangle {
                            id: track
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: window.s(-10)
                            height: window.s(12)
                            radius: window.s(6)
        color: window.mantle
                            border.color: window.crust
                            border.width: 1

                            Rectangle {
                                width: Math.max(knob.width, knob.x + knob.width / 2)
                                height: parent.height
                                radius: parent.radius
                                color: window.selectedRateAccent
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        Repeater {
                            model: sliderContainer.rates.length
                            Item {
                                x: (index / (sliderContainer.rates.length - 1)) * track.width
                                y: track.y + window.s(20)

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: sliderContainer.rates[index]
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window.s(13)
                                    font.weight: sliderContainer.currentIndex === index ? Font.Bold : Font.Normal
                                    color: sliderContainer.currentIndex === index ? window.selectedRateAccent : window.overlay0
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }

                        Rectangle {
                            id: knob
                            width: window.s(24)
                            height: window.s(24)
                            radius: window.s(12)
                            color: sliderMa.containsPress ? window.selectedRateAccent : window.text
                            anchors.verticalCenter: track.verticalCenter
                            x: (sliderContainer.visualPct * track.width) - width / 2

                            Behavior on x {
                                enabled: !sliderMa.pressed
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            border.width: sliderMa.containsMouse ? 4 : 0
                            border.color: Qt.alpha(window.selectedRateAccent, 0.3)
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: sliderMa
                            anchors.fill: parent
                            anchors.margins: window.s(-15)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function updateSelection(mouseX, snapToGrid) {
                                if (monitorsModel.count === 0) return;
                                let pct = (mouseX - track.x) / track.width;
                                pct = Math.max(0, Math.min(1, pct));
                                let idx = Math.round(pct * (sliderContainer.rates.length - 1));

                                if (snapToGrid) {
                                    sliderContainer.visualPct = idx / (sliderContainer.rates.length - 1);
                                } else {
                                    sliderContainer.visualPct = pct;
                                }

                                monitorsModel.setProperty(window.activeEditIndex, "rate", sliderContainer.rates[idx].toString());
                                window.selectedRateAccent = sliderContainer.rateColors[idx];
                            }

                            onPressed: (mouse) => updateSelection(mouse.x, false)
                            onPositionChanged: (mouse) => { if (pressed) updateSelection(mouse.x, false) }
                            onReleased: (mouse) => updateSelection(mouse.x, true)
                            onCanceled: () => sliderContainer.visualPct = sliderContainer.currentIndex / (sliderContainer.rates.length - 1)
                        }
                    }


                    // --- HDR / SDR BRIGHTNESS ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: window.s(14)

                        ColumnLayout {
                            Layout.fillWidth: true

                        // --- Brightness ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: window.s(6)

                            Text {
                                text: "SDR Brightness"
                                color: window.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(11)
                            }

                            Slider {
                                id: sdrSlider
                                Layout.fillWidth: true
                                from: 0.0
                                to: 3.0
                                stepSize: 0.01
                                value: window.sdrValue

                                onMoved: {
                                    monitorsModel.setProperty(
                                        window.activeEditIndex,
                                        "sdrBrightness",
                                        value
                                    )
                                }
                            }

                            Text {
                                text: sdrSlider.value.toFixed(2) + "x"
                                color: window.sliderColor(sdrSlider.position)
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(11)
                                font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: window.s(6)

                            Text {
                                text: "SDR Saturation"
                                color: window.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(11)
                            }

                            Slider {
                                id: satSlider
                                Layout.fillWidth: true
                                from: 0.0
                                to: 1.0
                                stepSize: 0.01
                                value: window.satValue

                                onMoved: {
                                    monitorsModel.setProperty(
                                        window.activeEditIndex,
                                        "sdrSaturation",
                                        value
                                    )
                                }
                            }

                            Text {
                                text: satSlider.value.toFixed(2)
                                color: window.sliderColor(satSlider.position)
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(11)
                                font.weight: Font.Bold
                            }
                        }
                    }
                    }

                    // --- ADVANCED: VRR / BIT DEPTH / COLOR MODE ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: window.s(8)

                        Text {
                            text: "ADVANCED"
                            color: window.subtext0
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(12)
                        }

                        // Monitor Enable/Disable
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: window.s(4)
                            Text {
                                text: "Monitor State"
                                color: window.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(11)
                            }
                            Row {
                                spacing: window.s(6)
                                Repeater {
                                    model: [
                                        { label: "Enabled",  val: false, accent: window.green },
                                        { label: "Disabled", val: true,  accent: window.red }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        property bool isSel: window.activeMon ? window.activeMon.disabled === modelData.val : false
                                        width: stateLbl.implicitWidth + window.s(16)
                                        height: window.s(28)
                                        radius: window.s(8)
                                        color: isSel ? Qt.alpha(modelData.accent, 0.18) : (stateMa.containsMouse ? window.surface0 : window.mantle)
                                        border.color: isSel ? modelData.accent : "transparent"
                                        border.width: isSel ? 2 : 1
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            id: stateLbl
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: isSel ? modelData.accent : window.subtext0
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: window.s(11)
                                            font.weight: isSel ? Font.Bold : Font.Normal
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        MouseArea {
                                            id: stateMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (monitorsModel.count > 0) {
                                                    monitorsModel.setProperty(window.activeEditIndex, "disabled", modelData.val)
                                                    let activeMonitors = [];
                                                    let disabledMonitors = [];
                                                    for (let i = 0; i < monitorsModel.count; i++) {
                                                        let m = monitorsModel.get(i);
                                                        if (m.disabled) {
                                                            disabledMonitors.push('    "' + m.name + '"');
                                                        } else {
                                                            activeMonitors.push('    "' + m.name + '"');
                                                        }
                                                    }
                                                    let stateContent = "return {\n  active = {\n" + activeMonitors.join(",\n") + "\n  },\n  disabled = {\n" + disabledMonitors.join(",\n") + "\n  },\n  moved = {\n  }\n}\n";
                                                    let stateFilePath = "${XDG_STATE_HOME:-$HOME/.local/state}/hypr/monitor-state.lua";
                                                    let stateEncoded = Qt.btoa(stateContent);
                                                    let disabledVal = modelData.val;
                                                    let targetMon = monitorsModel.get(window.activeEditIndex).name;
                                                    Quickshell.execDetached(["bash", "-c", "echo " + stateEncoded + " | base64 -d > " + stateFilePath + " && hyprctl eval 'hl.monitor({ output = \"" + targetMon + "\", disabled = " + (disabledVal ? "true" : "false") + " })'"]);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // VRR
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: window.s(4)
                            Text {
                                text: "Variable Refresh Rate"
                                color: window.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(11)
                            }
                            Row {
                                spacing: window.s(6)
                                Repeater {
                                    model: [
                                        { label: "Off",        val: 0, accent: window.overlay0 },
                                        { label: "Always",     val: 1, accent: window.green },
                                        { label: "Fullscreen", val: 2, accent: window.teal }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        property bool isSel: window.activeMon ? window.activeMon.vrr === modelData.val : false
                                        width: vrrLbl.implicitWidth + window.s(16)
                                        height: window.s(28)
                                        radius: window.s(8)
                                        color: isSel ? Qt.alpha(modelData.accent, 0.18) : (vrrMa.containsMouse ? window.surface0 : window.mantle)
                                        border.color: isSel ? modelData.accent : "transparent"
                                        border.width: isSel ? 2 : 1
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            id: vrrLbl
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: isSel ? modelData.accent : window.subtext0
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: window.s(11)
                                            font.weight: isSel ? Font.Bold : Font.Normal
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        MouseArea {
                                            id: vrrMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { if (monitorsModel.count > 0) monitorsModel.setProperty(window.activeEditIndex, "vrr", modelData.val) }
                                        }
                                    }
                                }
                            }
                        }

                        // Bit Depth
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: window.s(4)
                            Text {
                                text: "Bit Depth"
                                color: window.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(11)
                            }
                            Row {
                                spacing: window.s(6)
                                Repeater {
                                    model: [
                                        { label: "8-bit",  val: 8,  accent: window.blue },
                                        { label: "10-bit", val: 10, accent: window.mauve }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        property bool isSel: window.activeMon ? window.activeMon.bitdepth === modelData.val : false
                                        width: bdLbl.implicitWidth + window.s(16)
                                        height: window.s(28)
                                        radius: window.s(8)
                                        color: isSel ? Qt.alpha(modelData.accent, 0.18) : (bdMa.containsMouse ? window.surface0 : window.mantle)
                                        border.color: isSel ? modelData.accent : "transparent"
                                        border.width: isSel ? 2 : 1
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            id: bdLbl
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: isSel ? modelData.accent : window.subtext0
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: window.s(11)
                                            font.weight: isSel ? Font.Bold : Font.Normal
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        MouseArea {
                                            id: bdMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { if (monitorsModel.count > 0) monitorsModel.setProperty(window.activeEditIndex, "bitdepth", modelData.val) }
                                        }
                                    }
                                }
                            }
                        }

                        // Color Mode
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: window.s(4)
                            Text {
                                text: "Color Mode"
                                color: window.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(11)
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: window.s(6)
                                Repeater {
                                    model: [
                                        { label: "Auto",     val: "auto",    accent: window.subtext0 },
                                        { label: "sRGB",     val: "srgb",    accent: window.blue },
                                        { label: "DCI P3",   val: "dcip3",   accent: window.mauve },
                                        { label: "DP3",      val: "dp3",     accent: window.pink },
                                        { label: "Adobe RGB", val: "adobe",  accent: window.peach },
                                        { label: "Wide",     val: "wide",    accent: window.teal },
                                        { label: "EDID",     val: "edid",    accent: window.surface2 },
                                        { label: "HDR",      val: "hdr",     accent: window.yellow },
                                        { label: "HDR EDID", val: "hdredid", accent: window.peach }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        property bool isSel: window.activeMon ? window.activeMon.cm === modelData.val : false
                                        width: cmLbl.implicitWidth + window.s(16)
                                        height: window.s(28)
                                        radius: window.s(8)
                                        color: isSel ? Qt.alpha(modelData.accent, 0.18) : (cmMa.containsMouse ? window.surface0 : window.mantle)
                                        border.color: isSel ? modelData.accent : "transparent"
                                        border.width: isSel ? 2 : 1
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            id: cmLbl
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: isSel ? modelData.accent : window.subtext0
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: window.s(11)
                                            font.weight: isSel ? Font.Bold : Font.Normal
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        MouseArea {
                                            id: cmMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { if (monitorsModel.count > 0) monitorsModel.setProperty(window.activeEditIndex, "cm", modelData.val) }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { height: window.s(8) }
                }
            } // Flickable
        }

        // ==========================================
        // FLOATING APPLY BUTTON
        // ==========================================
        Item {
            id: applyButtonContainer
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: window.s(30)
            width: window.s(170)
            height: window.s(50)

            opacity: window.introProgress
            transform: Translate { y: window.uiYOffset }

            MultiEffect {
                source: applyBtn
                anchors.fill: applyBtn
                shadowEnabled: true
                shadowColor: window.selectedRateAccent
                shadowBlur: window.applyHovered ? 1.2 : 0.6
                shadowOpacity: window.applyHovered ? 0.6 : 0.2
                shadowVerticalOffset: window.s(4)
                z: -1
                Behavior on shadowBlur { NumberAnimation { duration: 300 } }
                Behavior on shadowOpacity { NumberAnimation { duration: 300 } }
                Behavior on shadowColor { ColorAnimation { duration: 400 } }
            }

            Rectangle {
                id: applyBtn
                anchors.fill: parent
                radius: window.s(25)

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: window.selectedResAccent
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                    GradientStop {
                        position: 1.0
                        color: window.selectedRateAccent
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                }

                scale: window.applyPressed ? 0.94 : (window.applyHovered ? 1.04 : 1.0)
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                Rectangle {
                    id: flashRect
                    anchors.fill: parent
                    radius: window.s(25)
                    color: window.text
                    opacity: 0.0
                    PropertyAnimation on opacity {
                        id: applyFlashAnim
                        to: 0.0
                        duration: 400
                        easing.type: Easing.OutExpo
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: window.s(8)

                    Text {
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(20)
                        color: window.crust
                        text: "󰸵"
                    }

                    Text {
                        font.family: "JetBrains Mono"
                        font.weight: Font.Black
                        font.pixelSize: window.s(14)
                        color: window.crust
                        text: monitorsModel.count > 1 ? "Apply All" : "Apply"
                    }
                }
            }

            MouseArea {
                id: applyMa
                anchors.fill: parent
                z: 10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: window.applyHovered = true
                onExited: window.applyHovered = false
                onPressed: window.applyPressed = true
                onReleased: window.applyPressed = false
                onCanceled: window.applyPressed = false

                onClicked: {
                    flashRect.opacity = 0.8;
                    applyFlashAnim.start();

                    if (monitorsModel.count === 0) return;

                    let rects = [];
                    for (let i = 0; i < monitorsModel.count; i++) {
                        let m = monitorsModel.get(i);
                        let layoutW = Math.round(m.resW / m.sysScale);
                        let layoutH = Math.round(m.resH / m.sysScale);
                        let rawX = m.uiX / window.uiScale;
                        let rawY = m.uiY / window.uiScale;
                        rects.push({
                            x: rawX, y: rawY, w: layoutW, h: layoutH,
                            resW: m.resW, resH: m.resH, name: m.name,
                            rate: m.rate, sysScale: m.sysScale,
                            vrr: m.vrr, bitdepth: m.bitdepth, cm: m.cm,
                            hdrBrightness: m.hdrBrightness,
                            sdrBrightness: m.sdrBrightness,
                            sdrSaturation: m.sdrSaturation,
                            disabled: m.disabled
                        });
                    }

                    // Tight Snap Pass
                    function getTightSnap(pX, pY, sX, sY, sW, sH, mW, mH, t) {
                        let cx = pX; let cy = pY;
                        if (Math.abs(cx - (sX - mW)) < t) cx = sX - mW;
                        else if (Math.abs(cx - (sX + sW)) < t) cx = sX + sW;
                        else if (Math.abs(cx - sX) < t) cx = sX;
                        else if (Math.abs(cx - (sX + sW - mW)) < t) cx = sX + sW - mW;
                        else if (Math.abs(cx - (sX + sW/2 - mW/2)) < t) cx = sX + sW/2 - mW/2;

                        if (Math.abs(cy - (sY - mH)) < t) cy = sY - mH;
                        else if (Math.abs(cy - (sY + sH)) < t) cy = sY + sH;
                        else if (Math.abs(cy - sY) < t) cy = sY;
                        else if (Math.abs(cy - (sY + sH - mH)) < t) cy = sY + sH - mH;
                        else if (Math.abs(cy - (sY + sH/2 - mH/2)) < t) cy = sY + sH/2 - mH/2;

                        return {x: cx, y: cy};
                    }

                    for (let i = 1; i < rects.length; i++) {
                        let bestX = rects[i].x;
                        let bestY = rects[i].y;
                        let bestDist = 999999;
                        for (let j = 0; j < i; j++) {
                            let r0 = rects[j];
                            let snapped = getTightSnap(
                                rects[i].x, rects[i].y,
                                r0.x, r0.y,
                                r0.w, r0.h, rects[i].w, rects[i].h, 25
                            );
                            let dist = Math.hypot(rects[i].x - snapped.x, rects[i].y - snapped.y);
                            if (dist < bestDist) {
                                bestDist = dist;
                                bestX = Math.round(snapped.x);
                                bestY = Math.round(snapped.y);
                            }
                        }
                        rects[i].x = bestX;
                        rects[i].y = bestY;
                    }

                    let finalMinX = 999999;
                    let finalMinY = 999999;
                    for (let i = 0; i < rects.length; i++) {
                        if (rects[i].x < finalMinX) finalMinX = rects[i].x;
                        if (rects[i].y < finalMinY) finalMinY = rects[i].y;
                    }

                    let summaryString = "";
                    let luaMonitorBlocks = ["-- Hyprland Monitor Configuration", "-- Auto-generated by MonitorPopup", ""];

                    for (let i = 0; i < rects.length; i++) {
                        let r = rects[i];

                        r.x = Math.round(r.x - finalMinX);
                        r.y = Math.round(r.y - finalMinY);
                        summaryString += r.name + " ";

                        luaMonitorBlocks.push("hl.monitor({");
                        luaMonitorBlocks.push("    output = \"" + r.name + "\",");
                        luaMonitorBlocks.push("    mode = \"" + r.resW + "x" + r.resH + "@" + r.rate + "\",");
                        luaMonitorBlocks.push("    position = \"" + r.x + "x" + r.y + "\",");
                        luaMonitorBlocks.push("    scale = " + r.sysScale + ",");
                        luaMonitorBlocks.push("    bitdepth = " + r.bitdepth + ",");
                        luaMonitorBlocks.push("    cm = \"" + r.cm + "\",");
                        luaMonitorBlocks.push("    sdrbrightness = " + r.sdrBrightness.toFixed(2) + ",");
                        luaMonitorBlocks.push("    sdrsaturation = " + r.sdrSaturation.toFixed(2) + ",");
                        luaMonitorBlocks.push("    disabled = " + (r.disabled ? "true" : "false") + "");
                        luaMonitorBlocks.push("})");
                        luaMonitorBlocks.push("");
                    }

                    // Hyprland 0.55+ with Lua config: hyprctl keyword no longer accepts
                    // legacy hyprlang syntax. Writing the file is the correct live path —
                    // Hyprland watches monitors.lua and auto-reloads it on change.
                    let luaContent = luaMonitorBlocks.join("\n");
                    let monitorsFilePath = "~/.config/hypr/monitors.lua";
                    let encoded = Qt.btoa(luaContent);
                    // Build monitor-state.lua
                    let activeMonitors = [];
                    let disabledMonitors = [];
                    for (let i = 0; i < rects.length; i++) {
                        if (rects[i].disabled) {
                            disabledMonitors.push('    "' + rects[i].name + '"');
                        } else {
                            activeMonitors.push('    "' + rects[i].name + '"');
                        }
                    }
                    let stateContent = "return {\n";
                    stateContent += "  active = {\n" + activeMonitors.join(",\n") + "\n  },\n";
                    stateContent += "  disabled = {\n" + disabledMonitors.join(",\n") + "\n  },\n";
                    stateContent += "  moved = {\n  }\n";
                    stateContent += "}\n";
                    let stateFilePath = "${XDG_STATE_HOME:-$HOME/.local/state}/hypr/monitor-state.lua";
                    let stateEncoded = Qt.btoa(stateContent);

                    // Build monitors_disabled.txt — one monitor name per line
                    let disabledNames = [];
                    for (let i = 0; i < rects.length; i++) {
                        if (rects[i].disabled) {
                            disabledNames.push(rects[i].name);
                        }
                    }
                    let disabledContent = disabledNames.join("\n") + "\n";
                    let disabledEncoded = Qt.btoa(disabledContent);

                    // Write files and apply immediately via hyprctl eval — no reload needed.
                    let evalScript = "#!/bin/bash\n";
                    evalScript += "echo " + encoded + " | base64 -d > " + monitorsFilePath + "\n";
                    evalScript += "echo " + stateEncoded + " | base64 -d > " + stateFilePath + "\n";
                    evalScript += "echo " + disabledEncoded + " | base64 -d > " + window.disabledFilePath + "\n";
                    for (let j = 0; j < rects.length; j++) {
                        let r = rects[j];
                        evalScript += "hyprctl eval 'hl.monitor({ output = \"" + r.name + "\", mode = \"" + r.resW + "x" + r.resH + "@" + r.rate + "\", position = \"" + r.x + "x" + r.y + "\", scale = " + r.sysScale + ", bitdepth = " + r.bitdepth + ", cm = \"" + r.cm + "\", sdrbrightness = " + r.sdrBrightness.toFixed(2) + ", sdrsaturation = " + r.sdrSaturation.toFixed(2) + ", disabled = " + (r.disabled ? "true" : "false") + " })'\n";
                    }
                    let scriptEncoded = Qt.btoa(evalScript);
                    Quickshell.execDetached(["bash", "-c", "echo " + scriptEncoded + " | base64 -d | bash"]);

                    Quickshell.execDetached(["notify-send", "Display Update", "Applied & Saved layout for: " + summaryString]);
                }
            }
        }
        // ==========================================
        // LEFT SIDE VISUAL AREA (MONITORS)
        // ==========================================
        Item {
            id: leftVisualArea
            z: 1
            x: window.s(20)
            y: parent.height / 2 - height / 2
            width: window.s(380)
            height: window.s(300)

            // --------------------------------------------------
            // MODE 1: SINGLE MONITOR
            // --------------------------------------------------
            Item {
                anchors.fill: parent
                visible: monitorsModel.count === 1

                Item {
                    id: singleMonitorZoom
                    anchors.fill: parent

                    property real baseScale: Math.min(1.0, 2200 / window.currentSimW)
                    scale: baseScale * window.monitorScale
                    opacity: window.introProgress
                    Behavior on baseScale { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

                        Rectangle {
                            id: screenBezel
                            width: window.s(140) + (window.s(180) * (window.currentSimW / 1920))
                            height: window.s(90) + (window.s(90) * (window.currentSimH / 1080))
                            anchors.centerIn: parent
                            radius: window.s(12)
                            color: monitorsModel.count > 0 && monitorsModel.get(0).disabled ? Qt.alpha(window.crust, 0.6) : window.crust
                            border.color: monitorsModel.count > 0 && monitorsModel.get(0).disabled ? window.red : window.surface2
                            border.width: window.s(2)
                            opacity: monitorsModel.count > 0 && monitorsModel.get(0).disabled ? 0.5 : 1.0

                        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }
                        Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: window.s(10)
                            radius: window.s(6)
                            color: window.surface0
                            clip: true

                            Item {
                                anchors.centerIn: parent
                                scale: 1.0 / singleMonitorZoom.scale

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: window.s(4)
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: window.s(38)
                                            color: window.selectedResAccent
                                            text: "󰍹"
                                            Behavior on color { ColorAnimation { duration: 400 } }
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Bold
                                            font.pixelSize: window.s(16)
                                            color: window.text
                                            text: monitorsModel.count > 0 ? monitorsModel.get(0).name : "Unknown"
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: window.s(12)
                                            color: window.subtext0
                                            text: monitorsModel.count > 0 && monitorsModel.get(0).disabled ? "DISABLED" : (window.currentSimW + "x" + window.currentSimH + " @ " + (monitorsModel.count > 0 ? monitorsModel.get(0).rate : "60") + "Hz")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --------------------------------------------------
            // MODE 2: MULTI-MONITOR (3+ Supported)
            // --------------------------------------------------
            Item {
                anchors.fill: parent
                visible: monitorsModel.count > 1

                Item {
                    id: multiMonitorView
                    anchors.fill: parent
                    clip: true

                    // Target Scale computes virtual bounds -> Maps to scaled physical layout
                    property real targetScale: {
                        if (monitorsModel.count < 2) return 1.0;
                        let minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;

                        for (let i = 0; i < monitorsModel.count; i++) {
                            let m = monitorsModel.get(i);
                            let w = (m.resW / m.sysScale) * window.uiScale;
                            let h = (m.resH / m.sysScale) * window.uiScale;

                            minX = Math.min(minX, m.uiX);
                            minY = Math.min(minY, m.uiY);
                            maxX = Math.max(maxX, m.uiX + w);
                            maxY = Math.max(maxY, m.uiY + h);
                        }

                        let requiredW = (maxX - minX) + 80;
                        let requiredH = (maxY - minY) + 80;

                        return Math.min(1.8 * scaler.baseScale, Math.min(window.s(340) / requiredW, window.s(240) / requiredH));
                    }

                    property real offsetX: {
                        if (monitorsModel.count < 2) return window.s(10);
                        let minX = 999999;

                        for (let i = 0; i < monitorsModel.count; i++) {
                            let m = monitorsModel.get(i);
                            let w = (m.resW / m.sysScale) * window.uiScale;
                            minX = Math.min(minX, m.uiX);
                        }

                        return window.s(10) - (minX * targetScale);
                    }

                    property real offsetY: {
                        if (monitorsModel.count < 2) return 0;
                        let minY = 999999, maxY = -999999;

                        for (let i = 0; i < monitorsModel.count; i++) {
                            let m = monitorsModel.get(i);
                            let h = (m.resH / m.sysScale) * window.uiScale;
                            minY = Math.min(minY, m.uiY);
                            maxY = Math.max(maxY, m.uiY + h);
                        }

                        let centerY = (minY + maxY) / 2;
                        return parent.height / 2 - (centerY * targetScale);
                    }

                    Item {
                        id: transformNode
                        x: multiMonitorView.offsetX
                        y: multiMonitorView.offsetY
                        scale: multiMonitorView.targetScale
                        transformOrigin: Item.TopLeft

                        Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                        Repeater {
                            id: monitorRepeater
                            model: monitorsModel

                            // NOTE: The items inside the transform node remain strictly virtual
                            Item {
                                property bool isActive: window.activeEditIndex === index

                                // THE VISIBLE SNAPPED MONITOR CARD
                                Rectangle {
                                    id: monitorCard
                                    x: model.uiX
                                    y: model.uiY

                                    width: (model.resW / model.sysScale) * window.uiScale
                                    height: (model.resH / model.sysScale) * window.uiScale

                                    radius: 8
                                    color: model.disabled ? Qt.alpha(window.surface0, 0.4) : (isActive ? window.surface1 : window.surface0)
                                    border.color: model.disabled ? window.red : (isActive ? window.selectedResAccent : window.surface2)
                                    border.width: isActive ? 2 : 1
                                    opacity: model.disabled ? 0.5 : 1.0
                                    z: isActive ? 5 : 0

                                    Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                    Behavior on border.color { ColorAnimation { duration: 300 } }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                    Item {
                                        anchors.centerIn: parent
                                        width: 110
                                        height: 80

                                        property real idealScale: Math.min(1.2, parent.width / 110, parent.height / 80) / transformNode.scale
                                        property real maxPhysicalScale: Math.min((parent.width * 0.9) / width, (parent.height * 0.9) / height)
                                        scale: Math.min(idealScale, maxPhysicalScale)

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: 32
                                                color: isActive ? window.selectedResAccent : window.text
                                                text: "󰍹"
                                                Behavior on color { ColorAnimation { duration: 300 } }
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Black
                                                font.pixelSize: 13
                                                color: window.text
                                                text: model.name
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 10
                                                color: window.subtext0
                                                text: model.disabled ? "DISABLED" : (model.resW + "x" + model.resH + " @ " + model.rate + "Hz")
                                            }
                                        }
                                    }
                                }

                                // THE INVISIBLE GHOST DRAGGER
                                Item {
                                    id: ghostDrag
                                    x: model.uiX
                                    y: model.uiY
                                    width: monitorCard.width
                                    height: monitorCard.height
                                    z: isActive ? 10 : 1

                                    MouseArea {
                                        id: ghostMa
                                        anchors.fill: parent
                                        drag.target: ghostDrag
                                        drag.axis: Drag.XAndYAxis

                                        onPressed: {
                                            window.activeEditIndex = index;
                                            ghostDrag.x = model.uiX;
                                            ghostDrag.y = model.uiY;
                                        }

                                        onPositionChanged: {
                                            if (drag.active && monitorsModel.count >= 2) {
                                                let mW = monitorCard.width;
                                                let mH = monitorCard.height;

                                                // Compute boundary limits dynamically against ALL other monitors
                                                let padding = 40;
                                                let boundMinX = 999999, boundMinY = 999999;
                                                let boundMaxX = -999999, boundMaxY = -999999;

                                                for (let j = 0; j < monitorsModel.count; j++) {
                                                    if (j === index) continue;
                                                    let sModel = monitorsModel.get(j);
                                                    let sW = (sModel.resW / sModel.sysScale) * window.uiScale;
                                                    let sH = (sModel.resH / sModel.sysScale) * window.uiScale;

                                                    boundMinX = Math.min(boundMinX, sModel.uiX - mW - padding);
                                                    boundMinY = Math.min(boundMinY, sModel.uiY - mH - padding);
                                                    boundMaxX = Math.max(boundMaxX, sModel.uiX + sW + padding);
                                                    boundMaxY = Math.max(boundMaxY, sModel.uiY + sH + padding);
                                                }

                                                ghostDrag.x = Math.max(boundMinX, Math.min(ghostDrag.x, boundMaxX));
                                                ghostDrag.y = Math.max(boundMinY, Math.min(ghostDrag.y, boundMaxY));

                                                // Snap to the nearest perimeter of ANY other monitor
                                                let bestX = ghostDrag.x;
                                                let bestY = ghostDrag.y;
                                                let bestDist = 999999;

                                                for (let j = 0; j < monitorsModel.count; j++) {
                                                    if (j === index) continue;
                                                    let sModel = monitorsModel.get(j);
                                                    let sW = (sModel.resW / sModel.sysScale) * window.uiScale;
                                                    let sH = (sModel.resH / sModel.sysScale) * window.uiScale;

                                                    let snapped = window.getPerimeterSnap(
                                                        ghostDrag.x, ghostDrag.y,
                                                        sModel.uiX, sModel.uiY,
                                                        sW, sH, mW, mH, 20
                                                    );

                                                    let dist = Math.hypot(ghostDrag.x - snapped.x, ghostDrag.y - snapped.y);
                                                    if (dist < bestDist) {
                                                        bestDist = dist;
                                                        bestX = snapped.x;
                                                        bestY = snapped.y;
                                                    }
                                                }

                                                if (!window.isOverlappingAny(bestX, bestY, mW, mH, index)) {
                                                    monitorsModel.setProperty(index, "uiX", bestX);
                                                    monitorsModel.setProperty(index, "uiY", bestY);
                                                }
                                            }
                                        }

                                        onReleased: {
                                            ghostDrag.x = model.uiX;
                                            ghostDrag.y = model.uiY;
                                        }
                                    }
                                }
                            }
                        }
                }
            }
        }
    }
}
