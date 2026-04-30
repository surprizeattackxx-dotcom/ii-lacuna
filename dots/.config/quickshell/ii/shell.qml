//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Default
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Window
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.3
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import "modules/common"
import "services"
import "panelFamilies"
import "./modules/ii"

import qs.modules.common
import qs.modules.common.widgets

ShellRoot {
    id: root

    Process { id: applyProcess }

    // Recompute widget positions on shell startup to ensure they persist across boots
    Process {
        id: updateWidgetPositionsProcess
        running: true
        command: [Quickshell.env("HOME") + "/.config/quickshell/ii/scripts/images/update_widget_positions.sh"]
    }

    Process {
        id: listProcess
        running: true
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/Animations.sh", "preview"]
        stdout: StdioCollector {
            id: animListStdout
            onStreamFinished: {
                const raw = animListStdout.text.trim()
                if (!raw)
                    return
                presetsModel.clear()
                raw.split("\n").forEach(line => {
                    const parts = line.trim().split("|")
                    if (parts.length >= 7)
                        presetsModel.append({
                            "name": parts[0],
                            "bx1": parseFloat(parts[1]), "by1": parseFloat(parts[2]),
                            "bx2": parseFloat(parts[3]), "by2": parseFloat(parts[4]),
                            "speed": parseFloat(parts[5]),
                            "style": parts[6]
                        })
                })
            }
        }
    }

    Process {
        id: activeProcess
        running: true
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/Animations.sh", "active"]
        stdout: StdioCollector {
            id: activeStdout
            onStreamFinished: {
                const name = activeStdout.text.trim()
                if (name.length > 0)
                    root.activePreset = name
            }
        }
    }

    ListModel { id: presetsModel }

    property string searchQuery: ""
    property string activePreset: ""

    function applyAnimation(preset) {
        applyProcess.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/Animations.sh", "apply", preset]
        applyProcess.running = true
        root.activePreset = preset
        notifyProcess.command = ["notify-send", "-a", "Quickshell", "-i", "preferences-desktop-animation", "Animations", "Applied: " + preset]
        notifyProcess.running = true
    }
    Process { id: notifyProcess }

    FloatingWindow {
        id: animationsWindow
        implicitWidth: 480
        implicitHeight: 580
        color: "transparent"
        visible: false

        screen: Quickshell.screens[0]

        onVisibleChanged: {
            if (visible) {
                const targetScreen = Quickshell.screens[0]
                animationsWindow.x = (targetScreen.geometry.width - implicitWidth) / 2
                animationsWindow.y = (targetScreen.geometry.height - implicitHeight) / 2
                searchField.text = ""
            }
        }

        Rectangle {
            id: windowRect
            anchors.fill: parent
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.small
            opacity: 1

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: parent.radius
                border.color: Appearance.colors.colPrimary
                border.width: 1
                opacity: 0.45
                enabled: false
                z: 10
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // --- Header (M3: secondaryContainer band + primary strip, same idea as StyledPopupHeaderRow) ---
                Rectangle {
                    Layout.fillWidth: true
                    height: 54
                    color: Appearance.m3colors.m3secondaryContainer
                    radius: Appearance.rounding.small
                    border.width: 1
                    border.color: Appearance.m3colors.m3outlineVariant
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 12
                        color: Appearance.m3colors.m3secondaryContainer
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 12
                        spacing: 10

                        Rectangle {
                            width: 4
                            height: 22
                            radius: 2
                            color: Appearance.colors.colPrimary
                        }

                        MaterialSymbol {
                            text: "motion_mode"
                            fill: 0
                            font.weight: Font.DemiBold
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.m3colors.m3onSecondaryContainer
                        }

                        StyledText {
                            text: "Animations"
                            Layout.fillWidth: true
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onSecondaryContainer
                        }

                        StyledText {
                            text: presetsModel.count + " presets"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.m3colors.m3onSurfaceVariant
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Appearance.rounding.unsharpenmore
                            color: closeMa.containsMouse ? Appearance.colors.colError : Appearance.colors.colLayer3
                            Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                            StyledText {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                color: Appearance.colors.colOnLayer2
                            }
                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: animationsWindow.visible = false
                            }
                        }
                    }
                }

                // --- Search ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    height: 38
                    radius: Appearance.rounding.unsharpenmore
                    color: Appearance.colors.colLayer2
                    border.color: searchField.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outlineVariant
                    border.width: 1
                    Behavior on border.color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        MaterialSymbol {
                            text: "search"
                            fill: 0
                            iconSize: Appearance.font.pixelSize.large
                            color: searchField.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                            Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: Appearance.colors.colOnSurface
                            font.pixelSize: Appearance.font.pixelSize.smallie
                            font.family: Appearance.font.family.main
                            selectionColor: Appearance.colors.colPrimary
                            selectedTextColor: Appearance.colors.colOnPrimary
                            clip: true
                            onTextChanged: root.searchQuery = text.toLowerCase()

                            Text {
                                anchors.fill: parent
                                text: "Search presets..."
                                color: Appearance.m3colors.m3onSurfaceVariant
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                font.family: Appearance.font.family.main
                                visible: !searchField.text && !searchField.activeFocus
                            }
                        }

                        StyledText {
                            text: "✕"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.m3colors.m3onSurfaceVariant
                            visible: searchField.text.length > 0
                            MouseArea {
                                anchors.fill: parent
                                onClicked: searchField.text = ""
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                // --- List ---
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 10
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    Layout.bottomMargin: 14
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical: StyledScrollBar {}

                    ListView {
                        id: presetsList
                        model: presetsModel
                        spacing: 5
                        clip: true

                        delegate: Item {
                            id: delegateItem
                            width: presetsList.width
                            height: visible ? (cardMa.containsMouse ? 120 : 46) : 0
                            visible: root.searchQuery === "" || model.name.toLowerCase().indexOf(root.searchQuery) !== -1
                            clip: true
                            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                            // Preview animation properties from model
                            property real bx1: model.bx1 ?? 0.25
                            property real by1: model.by1 ?? 0.1
                            property real bx2: model.bx2 ?? 0.25
                            property real by2: model.by2 ?? 1.0
                            property real speed: model.speed ?? 4
                            property string style: model.style ?? "slide"

                            Rectangle {
                                id: card
                                anchors.fill: parent
                                radius: Appearance.rounding.unsharpenmore
                                color: root.activePreset === model.name
                                    ? Appearance.colors.colPrimaryContainer
                                    : (cardMa.containsMouse ? Appearance.colors.colLayer3Hover : Appearance.colors.colLayer2)
                                border.color: root.activePreset === model.name || cardMa.containsMouse
                                    ? Appearance.colors.colPrimary
                                    : "transparent"
                                border.width: 1
                                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                                Behavior on border.color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                                Rectangle {
                                    width: 3
                                    height: 22
                                    radius: 2
                                    anchors.left: parent.left
                                    anchors.leftMargin: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Appearance.colors.colPrimary
                                    visible: root.activePreset === model.name
                                }

                                // --- Title row ---
                                RowLayout {
                                    id: titleRow
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 46
                                    anchors.leftMargin: root.activePreset === model.name ? 16 : 14
                                    anchors.rightMargin: 14
                                    Behavior on anchors.leftMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }

                                    StyledText {
                                        text: model.name
                                        color: root.activePreset === model.name
                                            ? Appearance.colors.colPrimary
                                            : (cardMa.containsMouse ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant)
                                        font.pixelSize: Appearance.font.pixelSize.smallie
                                        font.weight: root.activePreset === model.name ? Font.DemiBold : Font.Normal
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                                    }

                                    StyledText {
                                        text: delegateItem.style
                                        color: Appearance.m3colors.m3onSurfaceVariant
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        opacity: cardMa.containsMouse ? 0.7 : 0
                                        Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                                    }

                                    StyledText {
                                        text: root.activePreset === model.name ? "✓ active" : (cardMa.containsMouse ? "apply →" : "")
                                        color: root.activePreset === model.name
                                            ? Appearance.m3colors.m3success
                                            : Appearance.colors.colPrimary
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        opacity: (root.activePreset === model.name || cardMa.containsMouse) ? 1 : 0
                                        Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                                    }
                                }

                                // --- Animation preview stage ---
                                Rectangle {
                                    id: previewStage
                                    anchors.top: titleRow.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 6
                                    anchors.topMargin: 0
                                    radius: Appearance.rounding.unsharpenmore
                                    color: Appearance.m3colors.m3surfaceContainerLowest
                                    opacity: cardMa.containsMouse ? 1 : 0
                                    visible: opacity > 0
                                    clip: true
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    // Mock window
                                    Rectangle {
                                        id: mockWindow
                                        width: 50
                                        height: 36
                                        radius: 4
                                        color: Appearance.colors.colPrimary
                                        opacity: 0

                                        // Title bar
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 10
                                            radius: 4
                                            color: Qt.darker(Appearance.colors.colPrimary, 1.2)
                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                height: 4
                                                color: parent.color
                                            }
                                            // Dots
                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.leftMargin: 4
                                                spacing: 2
                                                Repeater {
                                                    model: 3
                                                    Rectangle {
                                                        width: 3; height: 3; radius: 1.5
                                                        color: Appearance.colors.colOnPrimary
                                                        opacity: 0.6
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Preview animation loop
                                    property bool animRunning: false
                                    property int durationMs: Math.max(200, delegateItem.speed * 100)

                                    SequentialAnimation {
                                        id: previewAnim
                                        loops: Animation.Infinite
                                        running: false

                                        // Reset to start position
                                        ScriptAction {
                                            script: {
                                                const stage = previewStage
                                                const cx = (stage.width - mockWindow.width) / 2
                                                const cy = (stage.height - mockWindow.height) / 2
                                                const s = delegateItem.style
                                                if (s === "slide" || s === "slidefade") {
                                                    mockWindow.x = -mockWindow.width
                                                    mockWindow.y = cy
                                                    mockWindow.scale = 1.0
                                                } else if (s === "slidevert" || s === "slidefadevert") {
                                                    mockWindow.x = cx
                                                    mockWindow.y = stage.height
                                                    mockWindow.scale = 1.0
                                                } else if (s === "popin") {
                                                    mockWindow.x = cx
                                                    mockWindow.y = cy
                                                    mockWindow.scale = 0.3
                                                } else {
                                                    mockWindow.x = cx
                                                    mockWindow.y = cy
                                                    mockWindow.scale = 1.0
                                                }
                                                mockWindow.opacity = 0
                                            }
                                        }
                                        PauseAnimation { duration: 200 }
                                        // Animate in
                                        ParallelAnimation {
                                            NumberAnimation {
                                                target: mockWindow; property: "x"
                                                to: (previewStage.width - mockWindow.width) / 2
                                                duration: previewStage.durationMs
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: [delegateItem.bx1, delegateItem.by1, delegateItem.bx2, delegateItem.by2, 1, 1]
                                            }
                                            NumberAnimation {
                                                target: mockWindow; property: "y"
                                                to: (previewStage.height - mockWindow.height) / 2
                                                duration: previewStage.durationMs
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: [delegateItem.bx1, delegateItem.by1, delegateItem.bx2, delegateItem.by2, 1, 1]
                                            }
                                            NumberAnimation {
                                                target: mockWindow; property: "scale"
                                                to: 1.0
                                                duration: previewStage.durationMs
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: [delegateItem.bx1, delegateItem.by1, delegateItem.bx2, delegateItem.by2, 1, 1]
                                            }
                                            NumberAnimation {
                                                target: mockWindow; property: "opacity"
                                                to: 1.0
                                                duration: previewStage.durationMs * 0.5
                                                easing.type: Easing.OutQuad
                                            }
                                        }
                                        // Hold
                                        PauseAnimation { duration: 600 }
                                        // Animate out (reverse)
                                        ParallelAnimation {
                                            NumberAnimation {
                                                target: mockWindow; property: "x"
                                                to: {
                                                    const s = delegateItem.style
                                                    return (s === "slide" || s === "slidefade")
                                                        ? previewStage.width
                                                        : (previewStage.width - mockWindow.width) / 2
                                                }
                                                duration: previewStage.durationMs * 0.7
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: [delegateItem.bx2, delegateItem.by2, delegateItem.bx1, delegateItem.by1, 1, 1]
                                            }
                                            NumberAnimation {
                                                target: mockWindow; property: "y"
                                                to: {
                                                    const s = delegateItem.style
                                                    return (s === "slidevert" || s === "slidefadevert")
                                                        ? -mockWindow.height
                                                        : (previewStage.height - mockWindow.height) / 2
                                                }
                                                duration: previewStage.durationMs * 0.7
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: [delegateItem.bx2, delegateItem.by2, delegateItem.bx1, delegateItem.by1, 1, 1]
                                            }
                                            NumberAnimation {
                                                target: mockWindow; property: "scale"
                                                to: delegateItem.style === "popin" ? 0.3 : 1.0
                                                duration: previewStage.durationMs * 0.7
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: [delegateItem.bx2, delegateItem.by2, delegateItem.bx1, delegateItem.by1, 1, 1]
                                            }
                                            NumberAnimation {
                                                target: mockWindow; property: "opacity"
                                                to: 0
                                                duration: previewStage.durationMs * 0.5
                                                easing.type: Easing.InQuad
                                            }
                                        }
                                        PauseAnimation { duration: 300 }
                                    }

                                    onVisibleChanged: {
                                        if (visible) previewAnim.start()
                                        else previewAnim.stop()
                                    }
                                }

                                Rectangle {
                                    id: rippleRect
                                    anchors.centerIn: parent
                                    width: 0; height: 0
                                    radius: width / 2
                                    color: Appearance.colors.colPrimary
                                    opacity: 0
                                    SequentialAnimation {
                                        id: ripple
                                        ParallelAnimation {
                                            NumberAnimation { target: rippleRect; property: "width"; from: 0; to: card.width * 2; duration: 350; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: rippleRect; property: "height"; from: 0; to: card.width * 2; duration: 350; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: rippleRect; property: "opacity"; from: 0.3; to: 0; duration: 350 }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cardMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { ripple.restart(); applyAnimation(model.name) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Panel Family Logic ---
    property list<string> families: ["ii", "waffle"]
    function cyclePanelFamily() {
        const currentIndex = families.indexOf(Config.options.panelFamily)
        Config.options.panelFamily = families[(currentIndex + 1) % families.length]
    }

    component PanelFamilyLoader: LazyLoader {
        required property string identifier
        active: Config.ready && Config.options.panelFamily === identifier
    }

    PanelFamilyLoader { identifier: "ii"; component: IllogicalImpulseFamily {} }
    PanelFamilyLoader { identifier: "waffle"; component: WaffleFamily {} }

    IpcHandler { target: "panelFamily"; function cycle(): void { root.cyclePanelFamily() } }
    IpcHandler {
        target: "animations"
        function toggle(): void { animationsWindow.visible = !animationsWindow.visible }
        function open(): void { animationsWindow.visible = true }
        function close(): void { animationsWindow.visible = false }
    }

    GlobalShortcut { name: "panelFamilyCycle"; onPressed: root.cyclePanelFamily() }
}
