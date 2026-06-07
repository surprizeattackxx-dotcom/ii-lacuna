import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.common
import qs.modules.ii.bar as Bar
import "../bar/WindowRegistry.js" as LayoutMath

// =========================================================
// OSRS + M3 Notification Island
// Old School RuneScape aesthetics with Material Design 3 motion
// =========================================================

PanelWindow {
    id: islandWindow

    WlrLayershell.namespace: "qs-island-notifs"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    // --- Scaling ---
    Bar.Scaler { id: scaler; currentWidth: Screen.width }
    function s(v) { return scaler.s(v); }

    implicitHeight: s(120)

    // --- Theme base (still reads M3 for consistency outside the island) ---
    Bar.MatugenColors { id: _theme }

    // --- Glass Color Palette ---
    readonly property color osrsGold: Appearance.m3colors.m3primary
    readonly property color osrsGoldDim: Appearance.m3colors.m3primaryContainer
    readonly property color osrsParchment: Appearance.m3colors.m3onSurface
    readonly property color osrsParchmentDim: Appearance.m3colors.m3onSurfaceVariant
    readonly property color osrsSurface: Appearance.colors.colLayer0
    readonly property color osrsSurfaceLight: Qt.rgba(Appearance.m3colors.m3surfaceBright.r, Appearance.m3colors.m3surfaceBright.g, Appearance.m3colors.m3surfaceBright.b, 0.18)
    readonly property color osrsBorder: Qt.rgba(Appearance.m3colors.m3outline.r, Appearance.m3colors.m3outline.g, Appearance.m3colors.m3outline.b, 0.25)
    readonly property color osrsBevel: Qt.rgba(Appearance.m3colors.m3outline.r, Appearance.m3colors.m3outline.g, Appearance.m3colors.m3outline.b, 0.15)
    readonly property color osrsBevelHi: Qt.rgba(1, 1, 1, 0.35)
    readonly property color osrsText: Appearance.m3colors.m3onSurface
    readonly property color osrsTextDim: Appearance.m3colors.m3onSurfaceVariant
    readonly property color osrsRed: Appearance.m3colors.m3error
    readonly property color osrsGreen: Appearance.m3colors.m3success
    readonly property color osrsBlue: Appearance.m3colors.m3secondary
    // --- Glass specular colors ---
    readonly property color islandShallows: Qt.rgba(Appearance.m3colors.m3primaryContainer.r, Appearance.m3colors.m3primaryContainer.g, Appearance.m3colors.m3primaryContainer.b, 0.15)
    readonly property color islandDeep: Qt.rgba(Appearance.m3colors.m3background.r, Appearance.m3colors.m3background.g, Appearance.m3colors.m3background.b, 0.05)
    readonly property color islandFoam: Qt.rgba(1, 1, 1, 0.08)
    readonly property color islandReflect: Qt.rgba(Appearance.m3colors.m3primary.r, Appearance.m3colors.m3primary.g, Appearance.m3colors.m3primary.b, 0.12)

    // --- State ---
    property bool expanded: false
    property var currentNotification: null
    property int notificationQueue: 0

    // --- Notification Model ---
    ListModel {
        id: notificationStack
    }

    function displayNextNotification() {
        if (notificationStack.count === 0) {
            currentNotification = null;
            collapseIsland();
            return;
        }

        currentNotification = notificationStack.get(0);
        expandIsland();
        autoHideTimer.restart();
    }

    function dismissCurrent() {
        if (notificationStack.count > 0) {
            notificationStack.remove(0);
            notificationQueue = Math.max(0, notificationQueue - 1);
        }
        currentNotification = null;
        collapseIsland();

        if (notificationStack.count > 0) {
            nextNotifTimer.start();
        }
    }

    // --- Timers ---
    Timer {
        id: autoHideTimer
        interval: 5000
        onTriggered: dismissCurrent()
    }

    Timer {
        id: nextNotifTimer
        interval: 300
        onTriggered: displayNextNotification()
    }

    // --- Sizes ---
    property real collapsedWidth: s(180)
    property real collapsedHeight: s(44)
    property real expandedWidth: s(420)
    property real expandedHeight: s(110)

    // --- Bevel border helper: stacked rects for OSRS 3D panel look ---
    property real borderW: 2
    property real bevelW: 1.5

    // --- Island Container ---
    Item {
        id: islandShape
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: s(8)

        width: expanded ? expandedWidth : collapsedWidth
        height: expanded ? expandedHeight : collapsedHeight

        transform: Translate { id: islandFloat; y: 0 }

        Behavior on width { enabled: false }
        Behavior on height { enabled: false }

        NumberAnimation {
            id: widthAnim
            target: islandShape
            property: "width"
            duration: 380
            easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 1, 0.3, 1]
        }

        NumberAnimation {
            id: heightAnim
            target: islandShape
            property: "height"
            duration: 380
            easing.type: Easing.Bezier; easing.bezierCurve: [0.16, 1, 0.3, 1]
        }

        Connections {
            target: islandWindow
            function onExpandedChanged() {
                widthAnim.to = islandWindow.expanded ? islandWindow.expandedWidth : islandWindow.collapsedWidth;
                heightAnim.to = islandWindow.expanded ? islandWindow.expandedHeight : islandWindow.collapsedHeight;
                widthAnim.restart();
                heightAnim.restart();
            }
        }

        // ─── Floating island bob (gentle wave drift) ───
        SequentialAnimation {
            id: floatAnim
            running: expanded
            loops: Animation.Infinite
            NumberAnimation { target: islandFloat; property: "y"; to: -4; duration: 2200; easing.type: Easing.InOutSine }
            NumberAnimation { target: islandFloat; property: "y"; to: 0; duration: 2200; easing.type: Easing.InOutSine }
        }

        // ─── OSRS Panel: beveled border stack ───

        // Water reflection glow (hovers beneath the island)
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: s(8)
            radius: height / 2
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                anchors.margins: -s(12)
                radius: height / 1.5
                color: islandReflect
                opacity: expanded ? 0.5 : 0.3

                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 64
                    blurMultiplier: 8
                    saturation: 0.3
                }
            }

            NumberAnimation on opacity {
                id: reflectPulse
                from: 0.6; to: 1.0
                duration: 3000
                easing.type: Easing.InOutSine
                running: expanded
                loops: Animation.Infinite
            }
        }

        // ─── Island body ───

        // Outermost: dark border
        Rectangle {
            id: outerBorder
            anchors.fill: parent
            radius: height / 2
            color: osrsBorder

            // Inner bevel highlight (top/left edge lighter)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                border.width: 1
                border.color: osrsBevelHi
            }

            // Surface background — sand-to-ocean gradient (island cross-section)
            Rectangle {
                anchors.fill: parent
                anchors.margins: borderW
                radius: parent.radius - borderW
                color: expanded ? osrsSurface : osrsSurfaceLight

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.1) }
                    GradientStop { position: 0.4; color: osrsSurface }
                    GradientStop { position: 1.0; color: islandShallows }
                }

                // Top glow — moonlight / sky hit on the island surface
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 0
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(osrsGold.r, osrsGold.g, osrsGold.b, 0.05) }
                        GradientStop { position: 0.3; color: "transparent" }
                        GradientStop { position: 0.7; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(islandDeep.r, islandDeep.g, islandDeep.b, 0.3) }
                    }
                }
            }

            // OSRS-style edge highlight (thin gold line at inner top)
            Rectangle {
                anchors {
                    top: parent.top; topMargin: borderW + 1
                    left: parent.left; leftMargin: borderW + 4
                    right: parent.right; rightMargin: borderW + 4
                }
                height: 1
                radius: 0
                color: Qt.rgba(osrsGold.r, osrsGold.g, osrsGold.b, 0.15)
                visible: expanded
            }

            // Shadow effect — deeper offset for floating island feel
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.55
                shadowBlur: expanded ? 2.0 : 1.2
                shadowVerticalOffset: expanded ? s(12) : s(6)
            }
        }

        // ─── COLLAPSED STATE ───
        Item {
            id: collapsedContent
            anchors.fill: parent
            anchors.margins: borderW + 2
            opacity: expanded ? 0 : 1
            visible: opacity > 0.01

            NumberAnimation on opacity {
                id: collapsedFade
                duration: 200
                easing.type: Easing.OutQuad
                onStopped: {
                    if (islandWindow.expanded && collapsedContent.opacity === 0) collapsedContent.visible = false;
                }
            }

            onVisibleChanged: {
                if (!islandWindow.expanded && visible) opacity = 1;
            }

            Row {
                anchors.centerIn: parent
                spacing: s(8)

                // App icon (small, inventory-slot style)
                Rectangle {
                    width: s(24)
                    height: s(24)
                    radius: s(3)
                    color: osrsSurface
                    border.width: 1
                    border.color: osrsBorder
                    visible: currentNotification !== null

                    // Inner bevel
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.width: 1
                        border.color: osrsBevelHi
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: s(3)
                        source: currentNotification ? currentNotification.icon : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: s(16)
                        sourceSize.height: s(16)
                        asynchronous: true
                    }

                    // Fallback rune-ish icon
                    Text {
                        anchors.centerIn: parent
                        text: "󰵙"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: s(12)
                        color: osrsGold
                        visible: parent.children[1].status !== Image.Ready
                    }
                }

                // Gold pulsing dot (like a prayer/hitpoint icon)
                Rectangle {
                    width: s(7)
                    height: s(7)
                    radius: s(3.5)
                    color: osrsGold
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.3)
                    }

                    ScaleAnimator on scale {
                        id: pulseAnim
                        from: 1.0
                        to: 1.4
                        duration: 600
                        easing.type: Easing.InOutSine
                        loops: Animation.Infinite
                        running: currentNotification !== null && !expanded
                    }
                }

                // Notification count (gold, like OSRS XP drops)
                Text {
                    text: notificationQueue > 1 ? notificationQueue.toString() : ""
                    font.family: "RuneScape Bold 12"
                    font.pixelSize: s(13)
                    color: osrsGold
                    visible: notificationQueue > 1
                    anchors.verticalCenter: parent.verticalCenter
                    style: Text.Raised
                    styleColor: osrsBorder
                }
            }
        }

        // ─── EXPANDED STATE ───
        Item {
            id: expandedContent
            anchors.fill: parent
            anchors.margins: s(14)
            opacity: expanded ? 1 : 0
            visible: opacity > 0.01

            NumberAnimation on opacity {
                id: expandedFade
                duration: 280
                easing.type: Easing.OutQuad
                onStopped: {
                    if (!islandWindow.expanded && expandedContent.opacity === 0) expandedContent.visible = false;
                }
            }

            transform: Translate { id: contentTranslate; y: 0 }

            NumberAnimation {
                id: slideAnim
                target: contentTranslate
                property: "y"
                duration: 320
                easing.type: Easing.OutBack; easing.overshoot: 1.2
            }

            onVisibleChanged: {
                if (islandWindow.expanded && visible) opacity = 1;
            }

            // --- Content layout ---
            Item {
                anchors.fill: parent

                // OSRS inventory-slot icon
                Rectangle {
                    id: iconContainer
                    width: s(48)
                    height: s(48)
                    radius: s(4)
                    color: osrsSurface
                    border.width: 2
                    border.color: osrsBorder
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    // Bevel highlight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.width: 1
                        border.color: osrsBevelHi
                    }

                    // Gold corner accents (OSRS inventory slot style)
                    Rectangle {
                        anchors.top: parent.top; anchors.topMargin: -1
                        anchors.left: parent.left; anchors.leftMargin: -1
                        width: s(10); height: s(10)
                        color: "transparent"
                        border.width: 1
                        border.color: osrsGoldDim
                        visible: expanded
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.bottomMargin: -1
                        anchors.right: parent.right; anchors.rightMargin: -1
                        width: s(10); height: s(10)
                        color: "transparent"
                        border.width: 1
                        border.color: osrsGoldDim
                        visible: expanded
                    }

                    Image {
                        id: appIcon
                        anchors.fill: parent
                        anchors.margins: s(6)
                        source: currentNotification ? currentNotification.icon : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: s(36)
                        sourceSize.height: s(36)
                        asynchronous: true
                    }

                    // Fallback
                    Text {
                        anchors.centerIn: parent
                        text: "󰵙"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: s(24)
                        color: osrsGold
                        visible: appIcon.status !== Image.Ready
                    }
                }

                // Content column
                Column {
                    anchors.left: iconContainer.right
                    anchors.leftMargin: s(14)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: s(2)

                    // App name - RuneScape Quill Caps for that OSRS UI feel
                    Text {
                        width: parent.width
                        text: currentNotification ? currentNotification.appName : ""
                        font.family: "RuneScape Quill Caps"
                        font.pixelSize: s(10)
                        font.letterSpacing: 1.2
                        color: osrsGold
                        elide: Text.ElideRight
                        opacity: 0.85
                    }

                    // Title - RuneScape Bold 12 in gold
                    Text {
                        width: parent.width
                        text: currentNotification ? currentNotification.title : ""
                        font.family: "RuneScape Bold 12"
                        font.pixelSize: s(15)
                        color: osrsGold
                        elide: Text.ElideRight
                        style: Text.Raised
                        styleColor: osrsBorder
                    }

                    // Body - parchment text
                    Text {
                        width: parent.width
                        text: currentNotification ? currentNotification.body : ""
                        font.family: "RuneScape Plain 12"
                        font.pixelSize: s(12)
                        color: osrsParchment
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        visible: text !== ""
                        lineHeight: 1.2
                    }
                }
            }

            // ─── Wave foam / shoreline ───
            Item {
                anchors {
                    bottom: parent.bottom; bottomMargin: -s(4)
                    left: parent.left; leftMargin: s(8)
                    right: parent.right; rightMargin: s(8)
                }
                height: s(6)
                visible: expanded
                clip: true

                // Multiple foam bands with staggered wave animations
                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: s(2)
                    radius: height / 2
                    color: islandFoam
                    opacity: 0.4

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: expanded
                        NumberAnimation { from: 0.2; to: 0.6; duration: 2400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.6; to: 0.2; duration: 2400; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: s(2)
                    radius: height / 2
                    color: islandFoam
                    opacity: 0.2

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: expanded
                        NumberAnimation { from: 0.1; to: 0.4; duration: 3200; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.4; to: 0.1; duration: 3200; easing.type: Easing.InOutSine }
                    }
                }
            }

            // ─── Tiny palm tree accent (bottom-right) ───
            Item {
                anchors {
                    bottom: parent.bottom; bottomMargin: s(1)
                    right: parent.right; rightMargin: s(10)
                }
                width: s(14); height: s(16)
                visible: expanded
                opacity: 0.5

                // Trunk — short curved line
                Rectangle {
                    x: parent.width / 2 - 0.5
                    y: s(6)
                    width: 1; height: s(9)
                    radius: 0.5
                    color: osrsBevelHi
                }
                // Fronds — 3 small angled lines
                Rectangle {
                    x: parent.width / 2 - s(5); y: s(2)
                    width: s(10); height: 1; radius: 0.5
                    color: Qt.rgba(0.4, 0.8, 0.4, 0.5)
                    transform: Rotation { angle: -15; origin.x: s(7); origin.y: 0 }
                }
                Rectangle {
                    x: parent.width / 2 - s(5); y: s(4)
                    width: s(10); height: 1; radius: 0.5
                    color: Qt.rgba(0.4, 0.8, 0.4, 0.5)
                    transform: Rotation { angle: 10; origin.x: s(7); origin.y: 0 }
                }
                Rectangle {
                    x: parent.width / 2 - s(3); y: s(3)
                    width: s(7); height: 1; radius: 0.5
                    color: Qt.rgba(0.4, 0.8, 0.4, 0.5)
                    transform: Rotation { angle: -40; origin.x: s(5); origin.y: 0 }
                }
            }
        }

        // --- Interaction ---
        MouseArea {
            id: islandMouse
            anchors.fill: parent
            hoverEnabled: true

            onClicked: {
                if (expanded) {
                    dismissCurrent();
                } else if (currentNotification) {
                    expandIsland();
                    autoHideTimer.restart();
                }
            }
        }
    }

    // --- State functions ---
    function expandIsland() {
        expanded = true;
        collapsedFade.to = 0;
        collapsedFade.restart();
        expandedFade.to = 1;
        expandedFade.restart();
        slideAnim.from = islandWindow.s(8);
        slideAnim.to = 0;
        slideAnim.restart();
    }

    function collapseIsland() {
        expanded = false;
        collapsedFade.to = 1;
        collapsedFade.restart();
        expandedFade.to = 0;
        expandedFade.restart();
    }

    // --- DND Support ---
    property bool dndEnabled: false

    Process {
        id: dndPoller
        command: ["bash", "-c", "cat ~/.cache/qs_dnd 2>/dev/null || echo \"0\""]
        stdout: StdioCollector {
            onStreamFinished: islandWindow.dndEnabled = (this.text.trim() === "1")
        }
    }

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: dndPoller.running = true
    }

    function showNotification(appName, title, body, icon) {
        if (dndEnabled) return;

        let notif = {
            "uid": Date.now() + Math.random(),
            "appName": appName || "System",
            "title": title || "",
            "body": body || "",
            "icon": icon || "",
            "timestamp": new Date()
        };

        notificationStack.append(notif);
        notificationQueue++;

        if (!currentNotification) {
            displayNextNotification();
        }
    }

    // --- IPC Listener ---
    Process {
        id: ipcWatcher
        running: true
        command: ["bash", "-c",
            "inotifywait -qq -e close_write,moved_to --include 'qs_island_notif$' /tmp/ 2>/dev/null; " +
            "if [ -f /tmp/qs_island_notif ]; then cat /tmp/qs_island_notif; rm -f /tmp/qs_island_notif; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = this.text.trim();
                if (data) {
                    try {
                        let notif = JSON.parse(data);
                        showNotification(
                            notif.appName || "System",
                            notif.title || "",
                            notif.body || "",
                            notif.icon || ""
                        );
                    } catch(e) {
                        console.log("Failed to parse notification:", e);
                    }
                }
                ipcWatcher.running = false;
                ipcWatcher.running = true;
            }
        }
    }
}
