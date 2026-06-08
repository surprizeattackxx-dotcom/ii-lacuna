import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common

Item {
    id: window
    focus: true

    signal closeRequested()

    implicitWidth: Screen.width
    implicitHeight: Screen.height

    function s(val) { return val }

    readonly property color base:     Appearance.m3colors.m3surface
    readonly property color mantle:   Appearance.m3colors.m3surfaceContainer
    readonly property color crust:    Appearance.m3colors.m3surfaceContainerLowest
    readonly property color surface0:  Appearance.m3colors.m3surfaceContainerHigh
    readonly property color surface1:  Appearance.m3colors.m3surfaceContainerHighest
    readonly property color surface2:  Appearance.m3colors.m3outline
    readonly property color text:      Appearance.m3colors.m3onSurface
    readonly property color subtext0:  Appearance.m3colors.m3onSurfaceVariant
    readonly property color blue:      Appearance.m3colors.m3primary
    readonly property color mauve:     Appearance.m3colors.m3primary
    readonly property color teal:      Appearance.m3colors.m3tertiary
    readonly property color overlay0:  Appearance.m3colors.m3outline
    readonly property color peach:     Appearance.m3colors.m3secondary
    readonly property color yellow:    Appearance.m3colors.m3tertiary
    readonly property color sapphire:  Appearance.m3colors.m3primary

    readonly property real _s2:   window.s(2)
    readonly property real _s3:   window.s(3)
    readonly property real _s4:   window.s(4)
    readonly property real _s5:   window.s(5)
    readonly property real _s8:   window.s(8)
    readonly property real _s11:  window.s(11)
    readonly property real _s12:  window.s(12)
    readonly property real _s15:  window.s(15)
    readonly property real _s16:  window.s(16)
    readonly property real _s18:  window.s(18)
    readonly property real _s20:  window.s(20)
    readonly property real _s28:  window.s(28)
    readonly property real _s40:  window.s(40)
    readonly property real _s50:  window.s(50)
    readonly property real _s55:  window.s(55)
    readonly property real _s56:  window.s(56)
    readonly property real _s63:  window.s(63)
    readonly property real _s74:  window.s(74)
    readonly property real _s104: window.s(104)

    // Satellite-specific pre-scaled constants (all ~20% smaller than original)
    readonly property real _sat_hullW:     window.s(216)
    readonly property real _sat_hullH:     window.s(148)
    readonly property real _sat_panelW:    window.s(64)
    readonly property real _sat_panelH:    window.s(51)
    readonly property real _sat_strutW:    window.s(10)
    readonly property real _sat_strutH:    window.s(4)
    readonly property real _sat_antennaH:  window.s(16)
    readonly property real _sat_thrusterH: window.s(11)
    readonly property real _sat_radius12:  window.s(10)
    readonly property real _sat_radius8:   window.s(7)
    readonly property real _sat_radius4:   window.s(3)
    readonly property real _sat_antBall:   window.s(6)
    readonly property real _sat_antStick:  window.s(2)
    readonly property real _sat_antOffX:   window.s(14)
    readonly property real _sat_screenM:   window.s(8)
    readonly property real _sat_innerM:    window.s(10)
    readonly property real _sat_iconSz:    window.s(40)
    readonly property real _sat_fontSize:  window.s(10)
    readonly property real _sat_thrBase:   window.s(16)
    readonly property real _sat_spacing:   window.s(5)

    property real baseSphereRadius: window.s(368)
    property real sphereZoom: 1.0
    Behavior on sphereZoom { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    // Manual scroll-wheel zoom, stacks under the search zoom.
    property real userZoom: 1.0
    Behavior on userZoom { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    property real sphereRadius: baseSphereRadius * userZoom

    property real rotX: -0.2
    property real rotY: 0

    NumberAnimation { id: searchRotXAnim; target: window; property: "rotX"; duration: 700; easing.type: Easing.OutCubic }
    NumberAnimation { id: searchRotYAnim; target: window; property: "rotY"; duration: 700; easing.type: Easing.OutCubic }

    property var projCache: []
    property bool projDirty: true

    // Unit-sphere Fibonacci positions — constant per app set, so compute the
    // sqrt/sin/cos once here instead of every rotation frame.
    property var baseSpherePoints: []
    function rebuildBasePoints() {
        let phi   = Math.PI * (3 - Math.sqrt(5));
        let total = appModel.count;
        let arr = new Array(total);
        for (let i = 0; i < total; i++) {
            let b_y      = 1.0 - (i / Math.max(1, total - 1)) * 2.0;
            let b_radius = Math.sqrt(1.0 - b_y * b_y);
            let b_theta  = phi * i;
            arr[i] = { x: Math.cos(b_theta) * b_radius, y: b_y, z: Math.sin(b_theta) * b_radius };
        }
        window.baseSpherePoints = arr;
    }

    function rebuildProjCache() {
        if (!projDirty) return;
        projDirty = false;

        let base  = window.baseSpherePoints;
        let total = base.length;
        let cosRx = Math.cos(window.rotX), sinRx = Math.sin(window.rotX);
        let cosRy = Math.cos(window.rotY), sinRy = Math.sin(window.rotY);

        let arr = new Array(total);
        for (let i = 0; i < total; i++) {
            let p = base[i];
            let y1 = p.y * cosRx - p.z * sinRx;
            let z1 = p.y * sinRx + p.z * cosRx;
            arr[i] = { x: p.x * cosRy + z1 * sinRy, y: y1, z: -p.x * sinRy + z1 * cosRy };
        }
        window.projCache = arr;
    }

    onRotXChanged: { projDirty = true; rebuildProjCache(); }
    onRotYChanged: { projDirty = true; rebuildProjCache(); }

    Timer {
        interval: 16
        // Idle spin — but hold still while dragging, snapping, or zoomed on a
        // searched app (otherwise it drifts off the app you just centered).
        running: !sceneMouse.pressed && !searchRotXAnim.running && !searchRotYAnim.running
                 && window.selectedAppIndex < 0
        repeat: true
        onTriggered: window.rotY -= 0.002
    }

    function centerOnApp(index) {
        if (index < 0 || index >= window.baseSpherePoints.length) return;

        let p   = window.baseSpherePoints[index];
        let b_x = p.x, b_y = p.y, b_z = p.z;

        let targetRotX = Math.atan2(b_y, b_z);
        let z1         = Math.sqrt(b_y * b_y + b_z * b_z);
        let targetRotY = Math.atan2(-b_x, z1);

        let currentRotYMod = ((window.rotY % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
        let targetRotYNorm = ((targetRotY % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);

        let diff = targetRotYNorm - currentRotYMod;
        if (diff >  Math.PI) diff -= Math.PI * 2;
        if (diff < -Math.PI) diff += Math.PI * 2;

        searchRotXAnim.to = Math.max(-1.45, Math.min(1.45, targetRotX));
        searchRotYAnim.to = window.rotY + diff;

        searchRotXAnim.restart();
        searchRotYAnim.restart();
    }

    property real introPhase: 0.0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0.0; to: 1.0; duration: 800; easing.type: Easing.OutExpo; running: true
    }

    Component.onCompleted: {
        rebuildApps();
        searchInput.forceActiveFocus();
    }

    Shortcut {
        sequence: "Escape"
        onActivated: closeSequence.start()
    }

    SequentialAnimation {
        id: closeSequence
        NumberAnimation { target: window; property: "introPhase"; to: 0.0; duration: 400; easing.type: Easing.OutQuint }
        ScriptAction { script: window.closeRequested() }
    }

    property string searchQuery: ""
    property int    selectedAppIndex: -1

    property string selectedAppName: ""
    property string selectedAppIcon: ""

    // appModel index -> { score, indices } for the current query
    property var matchInfo: ({})

    property var entries: []

    // Re-resolve icons in place when the shared index lands/refreshes mid-session
    // (no model rebuild, so the sphere doesn't reshuffle).
    Connections {
        target: AppIconIndex
        function onIndexChanged() {
            for (let i = 0; i < appModel.count && i < window.entries.length; i++)
                appModel.setProperty(i, "icon", window.appIcon(window.entries[i]));
        }
    }

    // Resolve a desktop entry's icon: absolute path → Qt theme (+ guessIcon
    // variations) → shared filesystem index → cog fallback. See AppIconIndex.
    function appIcon(entry) {
        const raw = entry.icon || "";
        if (raw.startsWith("/")) return "file://" + raw;
        if (raw.length > 0 && Quickshell.iconPath(raw, true).length > 0)
            return Quickshell.iconPath(raw);
        const guessed = AppSearch.guessIcon(raw.length > 0 ? raw : entry.id);
        if (Quickshell.iconPath(guessed, true).length > 0)
            return Quickshell.iconPath(guessed);
        const fromIndex = AppIconIndex.resolve(raw.length > 0 ? raw : entry.id, entry.name);
        if (fromIndex) return "file://" + fromIndex;
        return Quickshell.iconPath(AppSearch.guessIcon(entry.name), "application-x-executable");
    }

    function rebuildApps() {
        const seen = new Set();
        const list = DesktopEntries.applications.values.filter(a => {
            if (!a.name || a.name.length === 0) return false;
            if (seen.has(a.id)) return false;
            if (window.hiddenApps[a.id]) return false;   // user-hidden via right-click
            seen.add(a.id); return true;
        }).sort((a, b) => {
            // Frequently/recently used apps cluster near the start of the spiral.
            const df = window.frecencyScore(b.id) - window.frecencyScore(a.id);
            if (df !== 0) return df;
            return a.name.localeCompare(b.name);
        });

        window.entries = list;
        appModel.clear();
        for (const a of list) {
            appModel.append({ name: a.name, appId: a.id, icon: window.appIcon(a) });
        }
        window.rebuildBasePoints();
        window.projDirty = true;
        window.rebuildProjCache();
    }

    ListModel { id: appModel }

    // ── Frecency (launch count + recency), persisted across sessions ──────────
    FileView {
        id: frecencyFile
        path: `${Directories.state}/user/sphereLauncher.json`
        blockLoading: true
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) frecencyFile.writeAdapter();
        }
        adapter: JsonAdapter {
            id: frecency
            property var apps: ({})    // { [appId]: { count, last } }
            property var hidden: ({})  // { [appId]: true } — right-click hidden
        }
    }

    readonly property var hiddenApps: frecency.hidden || ({})
    property bool hiddenPanelOpen: false

    function hideApp(appId) {
        if (!appId) return;
        const h = Object.assign({}, frecency.hidden || {});
        h[appId] = true;
        frecency.hidden = h;   // new object ref so hiddenApps binding updates
        frecencyFile.writeAdapter();
        window.rebuildApps();
    }

    function unhideApp(appId) {
        const h = Object.assign({}, frecency.hidden || {});
        delete h[appId];
        frecency.hidden = h;
        frecencyFile.writeAdapter();
        if (Object.keys(h).length === 0) window.hiddenPanelOpen = false;
        window.rebuildApps();
    }

    // [{ appId, name, icon }] for the hidden-apps panel.
    function hiddenAppList() {
        const out = [];
        for (const id in window.hiddenApps) {
            const e = DesktopEntries.byId(id);
            out.push({ appId: id, name: e ? e.name : id, icon: e ? window.appIcon(e) : "" });
        }
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }

    function frecencyScore(appId) {
        const e = frecency.apps ? frecency.apps[appId] : undefined;
        if (!e) return 0;
        const ageDays = (Date.now() - (e.last || 0)) / 86400000;
        return (e.count || 0) / (1 + ageDays);   // recency-decayed frequency
    }

    function bumpFrecency(appId) {
        if (!appId) return;
        const apps = frecency.apps || {};
        const e = apps[appId] || { count: 0, last: 0 };
        e.count = (e.count || 0) + 1;
        e.last  = Date.now();
        apps[appId] = e;
        frecency.apps = apps;        // reassign so the JsonAdapter serialises
        frecencyFile.writeAdapter();
    }

    // ── Fuzzy subsequence matcher: returns { score, indices } or null ─────────
    function fuzzyMatch(query, name) {
        const t = name;
        let qi = 0, indices = [], score = 0, last = -2, consec = 0;
        for (let ti = 0; ti < t.length && qi < query.length; ti++) {
            if (t[ti] === query[qi]) {
                indices.push(ti);
                if (ti === last + 1) { consec++; score += 6 + consec * 4; }
                else { consec = 0; score += 1; }
                if (ti === 0) score += 12;
                else if (/[\s\-_./]/.test(t[ti - 1])) score += 9;   // word boundary
                last = ti;
                qi++;
            }
        }
        if (qi < query.length) return null;     // not all query chars matched
        score -= indices[0] * 0.5;               // prefer earlier first hit
        score -= (t.length - query.length) * 0.1; // prefer tighter names
        return { score: score, indices: indices };
    }

    function selectApp(index) {
        window.selectedAppIndex = index;
        window.selectedAppName  = appModel.get(index).name;
        window.selectedAppIcon  = appModel.get(index).icon || "";
        window.centerOnApp(index);
        window.sphereZoom = 1.65;
    }

    function handleSearch(query) {
        window.searchQuery = query.toLowerCase();
        if (window.searchQuery === "") {
            window.matchInfo        = ({});
            window.selectedAppIndex = -1;
            window.selectedAppName  = "";
            window.selectedAppIcon  = "";
            window.sphereZoom       = 1.0;
            return;
        }
        const info = {};
        let best = -1, bestScore = -Infinity;
        for (let i = 0; i < appModel.count; i++) {
            const item = appModel.get(i);
            const m = window.fuzzyMatch(window.searchQuery, item.name.toLowerCase());
            if (!m) continue;
            const score = m.score + Math.min(20, window.frecencyScore(item.appId) * 2);
            info[i] = { score: score, indices: m.indices };
            if (score > bestScore) { bestScore = score; best = i; }
        }
        window.matchInfo = info;
        if (best >= 0) {
            window.selectApp(best);
        } else {
            window.selectedAppIndex = -1;
            window.sphereZoom       = 1.0;
        }
    }

    // Next/prev match ranked by score (Down = lower rank, Up = higher).
    function stepMatch(dir) {
        const ranked = Object.keys(window.matchInfo)
            .map(k => parseInt(k))
            .sort((a, b) => window.matchInfo[b].score - window.matchInfo[a].score);
        if (ranked.length === 0) return;
        let cur = ranked.indexOf(window.selectedAppIndex);
        let next = Math.max(0, Math.min(ranked.length - 1, cur + dir));
        window.selectApp(ranked[next]);
    }

    function launchApp(index) {
        if (index < 0 || index >= window.entries.length) return;
        window.bumpFrecency(window.entries[index].id);
        window.entries[index].execute();
        closeSequence.start();
    }

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function highlightedName(name, index) {
        const m = window.matchInfo[index];
        if (!m || !m.indices || m.indices.length === 0) return window.escapeHtml(name);
        const c = window.blue;
        const hex = "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("");
        const set = {};
        for (const i of m.indices) set[i] = true;
        let out = "";
        for (let i = 0; i < name.length; i++) {
            const c = window.escapeHtml(name[i]);
            out += set[i] ? `<b><font color="${hex}">${c}</font></b>` : c;
        }
        return out;
    }

    Item {
        anchors.fill: parent
        opacity: window.introPhase

        Repeater {
            model: 50
            Rectangle {
                property real seed: Math.random()
                x: seed * window.width
                y: Math.random() * window.height
                width:  window._s2 + Math.random() * window._s2
                height: width
                radius: width / 2
                color:  window.text
                opacity: 0.08 + Math.random() * 0.12
            }
        }
    }

    Item {
        id: scene3D
        anchors.fill: parent
        opacity: window.introPhase
        scale: 0.8 + (0.2 * window.introPhase)

        MouseArea {
            id: sceneMouse
            anchors.fill: parent
            property real lastX: 0
            property real lastY: 0
            property real pressX: 0
            property real pressY: 0
            property bool dragged: false
            onPressed: mouse => {
                searchRotXAnim.stop();
                searchRotYAnim.stop();
                lastX = mouse.x; lastY = mouse.y;
                pressX = mouse.x; pressY = mouse.y;
                dragged = false;
            }
            onPositionChanged: mouse => {
                if (!pressed) return;
                let dx = mouse.x - lastX;
                let dy = mouse.y - lastY;
                window.rotY += dx * 0.005;
                let newRotX = window.rotX - dy * 0.005;
                window.rotX = Math.max(-1.45, Math.min(1.45, newRotX));
                lastX = mouse.x;
                lastY = mouse.y;
                if (Math.abs(mouse.x - pressX) + Math.abs(mouse.y - pressY) > 6) dragged = true;
            }
            // Clean click on empty space dismisses; a drag (rotate) does not.
            onClicked: {
                if (sceneMouse.dragged) return;
                if (window.hiddenPanelOpen) { window.hiddenPanelOpen = false; return; }
                if (window.searchQuery === "") closeSequence.start();
                else searchInput.forceActiveFocus();
            }
            onWheel: wheel => {
                let step = wheel.angleDelta.y > 0 ? 1.12 : 1 / 1.12;
                window.userZoom = Math.max(0.55, Math.min(2.2, window.userZoom * step));
            }
        }

        Item {
            id: origin
            anchors.centerIn: parent
            width:  window.baseSphereRadius * 2
            height: window.baseSphereRadius * 2

            Repeater {
                id: appRepeater
                model: appModel

                delegate: Item {
                    id: appNode

                    property var proj: (window.projCache && window.projCache.length > index)
                                       ? window.projCache[index]
                                       : { x: 0, y: 0, z: 0 }

                    property real zoomFactor: 1.0 + (window.sphereZoom - 1.0) * 0.45

                    x: (origin.width  / 2) + (proj.x * window.sphereRadius * zoomFactor) - width  / 2
                    y: (origin.height / 2) + (proj.y * window.sphereRadius * zoomFactor) - height / 2

                    z: nodeMa.containsMouse ? 100000 : Math.round(proj.z * 1000)

                    property bool isMatch:    window.searchQuery === "" || (window.matchInfo[index] !== undefined)
                    property bool isSelected: index === window.selectedAppIndex

                    property real _hz: Math.max(0.0, Math.min(1.0, proj.z * 4.0))
                    opacity: proj.z > 0.0 ? (isMatch ? _hz : _hz * 0.15) : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    visible: opacity > 0.01

                    property real _baseScale: 0.78 + (Math.max(0.0, proj.z) * 0.22)
                    scale: isSelected ? 1.0 : (_baseScale * ((nodeMa.containsMouse && !isSelected) ? 1.28 : 1.0))
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                    property real _xNorm: proj.x / (window.sphereRadius / window.s(310.5))
                    property real _yNorm: proj.y / (window.sphereRadius / window.s(310.5))

                    transform: [
                        Rotation {
                            axis { x: 1; y: 0; z: 0 }
                            angle: appNode.isSelected ? 0 : -appNode._yNorm * 45
                            origin.x: appNode.width  / 2
                            origin.y: appNode.height / 2
                        },
                        Rotation {
                            axis { x: 0; y: 1; z: 0 }
                            angle: appNode.isSelected ? 0 : appNode._xNorm * 35
                            origin.x: appNode.width  / 2
                            origin.y: appNode.height / 2
                        }
                    ]

                    width:  window._s74
                    height: window._s104

                    // ── Normal app card (hidden while selected) ───────────────
                    Rectangle {
                        id: cardBg
                        anchors.fill: parent
                        radius: window._s12
                        readonly property bool hot: nodeMa.containsMouse && !appNode.isSelected
                        color: hot ? Qt.alpha(window.blue, 0.14) : "transparent"
                        border.color: hot ? window.blue : "transparent"
                        border.width: hot ? window.s(2.5) : window._s2
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        layer.enabled: hot
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: window.blue
                            shadowOpacity: 0.55
                            shadowBlur: 1.0
                            shadowScale: 1.05
                        }

                        visible: !appNode.isSelected

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: window._s5
                            spacing: window._s5

                            Image {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth:  window._s55
                                Layout.preferredHeight: window._s55
                                source: model.icon
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                cache: true
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: labelText.implicitHeight + window._s4
                                radius: window._s4
                                color: Qt.rgba(window.crust.r, window.crust.g, window.crust.b, 0.60)

                                Text {
                                    id: labelText
                                    anchors.fill: parent
                                    anchors.leftMargin:  window._s3
                                    anchors.rightMargin: window._s3
                                    text: window.highlightedName(model.name, index)
                                    textFormat: Text.StyledText
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window._s11
                                    font.weight: Font.DemiBold
                                    color: window.text
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Loader {
                        id: satLoader
                        anchors.centerIn: parent
                        active: appNode.isSelected
                        opacity: appNode.isSelected ? 1.0 : 0.0
                        scale:   appNode.isSelected ? 1.5 : 0.4

                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        Behavior on scale   { NumberAnimation { duration: 450; easing.type: Easing.OutBack  } }

                        sourceComponent: Component {
                            Item {
                                readonly property real satW: window._sat_panelW + window._sat_strutW
                                                           + window._sat_hullW
                                                           + window._sat_strutW + window._sat_panelW
                                readonly property real satH: window._sat_hullH
                                                           + window._sat_antennaH
                                                           + window._sat_thrusterH
                                                           + window.s(11)

                                width:  satW
                                height: satH

                                // Left solar panel
                                Rectangle {
                                    id: lPanel
                                    width:  window._sat_panelW
                                    height: window._sat_panelH
                                    anchors.right: lStrut.left
                                    anchors.verticalCenter: hull.verticalCenter
                                    color: window.mantle
                                    border.color: Qt.alpha(window.surface2, 0.4)
                                    border.width: 1
                                    radius: window._sat_radius4

                                    Grid {
                                        anchors.fill: parent
                                        anchors.margins: window._sat_screenM * 0.5
                                        columns: 4; rows: 4
                                        spacing: window._s2
                                        Repeater {
                                            model: 16
                                            Rectangle {
                                                width:  (lPanel.width  - window._sat_screenM - 3 * window._s2) / 4
                                                height: (lPanel.height - window._sat_screenM - 3 * window._s2) / 4
                                                color: Qt.alpha(window.blue, index % 3 === 0 ? 0.15 : 0.05)
                                                radius: 1
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: lStrut
                                    width:  window._sat_strutW
                                    height: window._sat_strutH
                                    anchors.right: hull.left
                                    anchors.verticalCenter: hull.verticalCenter
                                    color: Qt.alpha(window.surface2, 0.5)
                                }

                                // Central hull
                                Rectangle {
                                    id: hull
                                    width:  window._sat_hullW
                                    height: window._sat_hullH
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: (window._sat_antennaH - window._sat_thrusterH) * 0.5
                                    color: window.base
                                    border.color: Qt.alpha(window.surface1, 0.6)
                                    border.width: 1.5
                                    radius: window._sat_radius12

                                    // Antenna
                                    Rectangle {
                                        width:  window._sat_antStick
                                        height: window._sat_antennaH
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.horizontalCenterOffset: -window._sat_antOffX
                                        anchors.bottom: parent.top
                                        color: Qt.alpha(window.surface2, 0.7)
                                        radius: 1
                                        Rectangle {
                                            width:  window._sat_antBall
                                            height: window._sat_antBall
                                            radius: width / 2
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.top
                                            color: window.blue
                                        }
                                    }

                                    // Screen showing selected app
                                    Rectangle {
                                        id: notifScreen
                                        anchors.fill: parent
                                        anchors.margins: window._sat_screenM
                                        color: window.mantle
                                        radius: window._sat_radius8
                                        border.color: Qt.alpha(window.surface0, 0.5)
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: window._sat_innerM
                                            spacing: window._sat_spacing

                                            Image {
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.preferredWidth:  window._sat_iconSz
                                                Layout.preferredHeight: window._sat_iconSz
                                                source: window.selectedAppIcon
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
                                                cache: true
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.fillWidth: true
                                                text: window.selectedAppName
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: window._sat_fontSize
                                                font.weight: Font.Bold
                                                color: window.text
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }

                                    // Thruster
                                    Rectangle {
                                        width:  window._sat_thrBase
                                        height: window._sat_thrusterH * 0.5
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.bottom
                                        color: window.surface1
                                        radius: 2
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: parent.bottom
                                            width:  parent.width * 0.6
                                            height: window._sat_thrusterH
                                            radius: width / 2
                                            color: Qt.alpha(window.sapphire, 0.35)
                                        }
                                    }
                                }

                                // Right solar panel
                                Rectangle {
                                    id: rPanel
                                    width:  window._sat_panelW
                                    height: window._sat_panelH
                                    anchors.left: rStrut.right
                                    anchors.verticalCenter: hull.verticalCenter
                                    color: window.mantle
                                    border.color: Qt.alpha(window.surface2, 0.4)
                                    border.width: 1
                                    radius: window._sat_radius4

                                    Grid {
                                        anchors.fill: parent
                                        anchors.margins: window._sat_screenM * 0.5
                                        columns: 4; rows: 4
                                        spacing: window._s2
                                        Repeater {
                                            model: 16
                                            Rectangle {
                                                width:  (rPanel.width  - window._sat_screenM - 3 * window._s2) / 4
                                                height: (rPanel.height - window._sat_screenM - 3 * window._s2) / 4
                                                color: Qt.alpha(window.blue, index % 3 === 0 ? 0.15 : 0.05)
                                                radius: 1
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: rStrut
                                    width:  window._sat_strutW
                                    height: window._sat_strutH
                                    anchors.left: hull.right
                                    anchors.verticalCenter: hull.verticalCenter
                                    color: Qt.alpha(window.surface2, 0.5)
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: nodeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) window.hideApp(model.appId);
                            else window.launchApp(index);
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: searchContainer
        width:  window.s(560)
        height: window._s56
        anchors.bottom: parent.bottom
        anchors.bottomMargin: window._s63
        anchors.horizontalCenter: parent.horizontalCenter

        radius: window._s28
        color: Qt.rgba(window.mantle.r, window.mantle.g, window.mantle.b, 0.92)
        border.color: searchInput.activeFocus ? window.mauve : window.surface1
        border.width: window.s(1.5)

        opacity: window.introPhase
        transform: Translate { y: (1 - window.introPhase) * window._s40 }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        layer.enabled: window.introPhase > 0.01
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.4
            shadowBlur: 1.5
            shadowVerticalOffset: window._s4
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin:  window._s20
            anchors.rightMargin: window._s20
            spacing: window._s12

            Text {
                text: ""
                font.family: "Iosevka Nerd Font"
                font.pixelSize: window._s18
                color: searchInput.activeFocus ? window.mauve : window.subtext0
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            TextField {
                id: searchInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                background: Item {}
                color: window.text
                font.family: "JetBrains Mono"
                font.pixelSize: window._s15
                font.weight: Font.Medium
                selectByMouse: true

                placeholderText: "Search applications..."
                placeholderTextColor: window.overlay0
                verticalAlignment: TextInput.AlignVCenter

                onTextChanged: window.handleSearch(text)

                Keys.onDownPressed: {
                    window.stepMatch(1);
                    event.accepted = true;
                }
                Keys.onUpPressed: {
                    window.stepMatch(-1);
                    event.accepted = true;
                }
                Keys.onReturnPressed: {
                    if (window.selectedAppIndex >= 0 && window.selectedAppIndex < appModel.count) {
                        window.launchApp(window.selectedAppIndex);
                    }
                    event.accepted = true;
                }
                Keys.onEscapePressed: {
                    closeSequence.start();
                    event.accepted = true;
                }
            }

            Text {
                visible: searchInput.text.length > 0
                text: ""
                font.family: "Iosevka Nerd Font"
                font.pixelSize: window._s16
                color: window.subtext0
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchInput.text = "";
                        searchInput.forceActiveFocus();
                    }
                }
            }
        }
    }

    // ── Hidden-apps toggle pill (left of the search bar) ──────────────────────
    Rectangle {
        id: hiddenToggle
        visible: Object.keys(window.hiddenApps).length > 0 && window.introPhase > 0.01
        height: window._s40
        width: hiddenRow.implicitWidth + window._s20
        anchors.verticalCenter: searchContainer.verticalCenter
        anchors.right: searchContainer.left
        anchors.rightMargin: window._s12
        radius: window._s20
        opacity: window.introPhase
        color: window.hiddenPanelOpen ? Qt.alpha(window.blue, 0.18)
                                      : Qt.rgba(window.mantle.r, window.mantle.g, window.mantle.b, 0.92)
        border.color: window.hiddenPanelOpen ? window.blue : window.surface1
        border.width: window.s(1.5)
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Row {
            id: hiddenRow
            anchors.centerIn: parent
            spacing: window._s5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Hidden"
                font.family: "JetBrains Mono"; font.pixelSize: window._s12; font.weight: Font.Medium
                color: window.hiddenPanelOpen ? window.blue : window.subtext0
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: countText.implicitWidth + window._s8; height: window._s18
                radius: height / 2; color: Qt.alpha(window.blue, 0.22)
                Text {
                    id: countText; anchors.centerIn: parent
                    text: Object.keys(window.hiddenApps).length
                    font.family: "JetBrains Mono"; font.pixelSize: window._s11; font.weight: Font.Bold
                    color: window.blue
                }
            }
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: window.hiddenPanelOpen = !window.hiddenPanelOpen
        }
    }

    // ── Hidden-apps restore panel (above the search bar) ──────────────────────
    Rectangle {
        id: hiddenPanel
        visible: opacity > 0.01
        opacity: (window.hiddenPanelOpen && Object.keys(window.hiddenApps).length > 0) ? window.introPhase : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        width: window.s(440)
        height: Math.min(window.s(380), hiddenListView.contentHeight + headerText.height + window._s28)
        anchors.bottom: searchContainer.top
        anchors.bottomMargin: window._s20
        anchors.horizontalCenter: searchContainer.horizontalCenter
        radius: window._s16
        color: Qt.rgba(window.mantle.r, window.mantle.g, window.mantle.b, 0.96)
        border.color: window.surface1
        border.width: window.s(1.5)

        MouseArea { anchors.fill: parent }   // absorb clicks so they don't dismiss

        Column {
            anchors.fill: parent
            anchors.margins: window._s12
            spacing: window._s8

            Text {
                id: headerText
                width: parent.width
                text: "Hidden apps — click to restore"
                font.family: "JetBrains Mono"; font.pixelSize: window._s12; font.weight: Font.DemiBold
                color: window.subtext0
            }

            ListView {
                id: hiddenListView
                width: parent.width
                height: parent.height - headerText.height - window._s8
                clip: true
                spacing: window._s4
                model: window.hiddenPanelOpen ? window.hiddenAppList() : []
                delegate: Rectangle {
                    id: hiddenDelg
                    required property var modelData
                    width: hiddenListView.width
                    height: window._s40
                    radius: window._s8
                    color: rowMa.containsMouse ? Qt.alpha(window.blue, 0.14) : "transparent"
                    Row {
                        anchors.left: parent.left; anchors.right: restoreLabel.left
                        anchors.leftMargin: window._s8; anchors.verticalCenter: parent.verticalCenter
                        spacing: window._s8
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: window._s28; height: window._s28
                            source: hiddenDelg.modelData.icon
                            fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: hiddenListView.width - window._s104
                            text: hiddenDelg.modelData.name
                            color: window.text; font.family: "JetBrains Mono"; font.pixelSize: window._s12
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        id: restoreLabel
                        anchors.right: parent.right; anchors.rightMargin: window._s12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Restore"
                        color: window.blue; font.family: "JetBrains Mono"; font.pixelSize: window._s11; font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: rowMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.unhideApp(hiddenDelg.modelData.appId)
                    }
                }
            }
        }
    }
}
