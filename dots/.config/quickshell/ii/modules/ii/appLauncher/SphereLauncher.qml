import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
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

    property real sphereRadius: baseSphereRadius

    property real rotX: -0.2
    property real rotY: 0

    NumberAnimation { id: searchRotXAnim; target: window; property: "rotX"; duration: 700; easing.type: Easing.OutCubic }
    NumberAnimation { id: searchRotYAnim; target: window; property: "rotY"; duration: 700; easing.type: Easing.OutCubic }

    property var projCache: []
    property bool projDirty: true

    function rebuildProjCache() {
        if (!projDirty) return;
        projDirty = false;

        let phi   = Math.PI * (3 - Math.sqrt(5));
        let total = appModel.count;
        let rx    = window.rotX;
        let ry    = window.rotY;
        let cosRx = Math.cos(rx), sinRx = Math.sin(rx);
        let cosRy = Math.cos(ry), sinRy = Math.sin(ry);

        let arr = new Array(total);
        for (let i = 0; i < total; i++) {
            let b_y      = 1.0 - (i / Math.max(1, total - 1)) * 2.0;
            let b_radius = Math.sqrt(1.0 - b_y * b_y);
            let b_theta  = phi * i;
            let b_x      = Math.cos(b_theta) * b_radius;
            let b_z      = Math.sin(b_theta) * b_radius;

            let y1 = b_y * cosRx - b_z * sinRx;
            let z1 = b_y * sinRx + b_z * cosRx;

            let x2 = b_x * cosRy + z1 * sinRy;
            let z2 = -b_x * sinRy + z1 * cosRy;

            arr[i] = { x: x2, y: y1, z: z2 };
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
        if (index < 0 || index >= appModel.count) return;

        let phi    = Math.PI * (3 - Math.sqrt(5));
        let total  = appModel.count;
        let b_y    = 1.0 - (index / Math.max(1, total - 1)) * 2.0;
        let b_radius = Math.sqrt(1.0 - b_y * b_y);
        let b_theta  = phi * index;
        let b_x    = Math.cos(b_theta) * b_radius;
        let b_z    = Math.sin(b_theta) * b_radius;

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

    property var entries: []

    function rebuildApps() {
        const seen = new Set();
        const list = DesktopEntries.applications.values.filter(a => {
            if (!a.name || a.name.length === 0) return false;
            if (seen.has(a.id)) return false;
            seen.add(a.id); return true;
        }).sort((a, b) => a.name.localeCompare(b.name));

        window.entries = list;
        appModel.clear();
        for (const a of list) {
            appModel.append({ name: a.name, icon: Quickshell.iconPath(a.icon, "application-x-executable") });
        }
        window.projDirty = true;
        window.rebuildProjCache();
    }

    ListModel { id: appModel }

    function handleSearch(query) {
        window.searchQuery = query.toLowerCase();
        if (window.searchQuery === "") {
            window.selectedAppIndex = -1;
            window.selectedAppName  = "";
            window.selectedAppIcon  = "";
            window.sphereZoom       = 1.0;
            return;
        }
        let found = false;
        for (let i = 0; i < appModel.count; i++) {
            if (appModel.get(i).name.toLowerCase().includes(window.searchQuery)) {
                window.selectedAppIndex = i;
                window.selectedAppName  = appModel.get(i).name;
                window.selectedAppIcon  = appModel.get(i).icon || "";
                centerOnApp(i);
                window.sphereZoom = 1.65;
                found = true;
                break;
            }
        }
        if (!found) {
            window.selectedAppIndex = -1;
            window.sphereZoom       = 1.0;
        }
    }

    function launchApp(index) {
        if (index < 0 || index >= window.entries.length) return;
        window.entries[index].execute();
        closeSequence.start();
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
            onPressed: mouse => {
                searchRotXAnim.stop();
                searchRotYAnim.stop();
                lastX = mouse.x;
                lastY = mouse.y;
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
            }
            onClicked: searchInput.forceActiveFocus()
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

                    property bool isMatch:    window.searchQuery === "" || model.name.toLowerCase().includes(window.searchQuery)
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
                                    text: model.name
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
                        onClicked: window.launchApp(index)
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
                    for (let i = window.selectedAppIndex + 1; i < appModel.count; i++) {
                        if (appModel.get(i).name.toLowerCase().includes(window.searchQuery)) {
                            window.selectedAppIndex = i;
                            window.selectedAppName  = appModel.get(i).name;
                            window.selectedAppIcon  = appModel.get(i).icon || "";
                            window.centerOnApp(i);
                            window.sphereZoom = 1.65;
                            break;
                        }
                    }
                    event.accepted = true;
                }
                Keys.onUpPressed: {
                    for (let i = window.selectedAppIndex - 1; i >= 0; i--) {
                        if (appModel.get(i).name.toLowerCase().includes(window.searchQuery)) {
                            window.selectedAppIndex = i;
                            window.selectedAppName  = appModel.get(i).name;
                            window.selectedAppIcon  = appModel.get(i).icon || "";
                            window.centerOnApp(i);
                            window.sphereZoom = 1.65;
                            break;
                        }
                    }
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
}
