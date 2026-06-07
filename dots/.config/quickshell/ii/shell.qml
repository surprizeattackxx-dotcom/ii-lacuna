//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Default
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1
//@ pragma Env QT_ORGANIZATION_NAME=illogical-impulse
//@ pragma Env QT_ORGANIZATION_DOMAIN=ii-lacuna

import QtQuick
import QtQuick.Controls
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
import qs.modules.ii.animationsPreview
import qs.services

ShellRoot {
    id: root

    Component.onCompleted: {
        Qt.application.organization = "illogical-impulse"
        Qt.application.domain = "ii-lacuna"
        MaterialThemeLoader.reapplyTheme()
    }

    // Apply colors on startup so kitty theme is resolved before any terminal opens
    Process {
        id: applyProcess
        running: true
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/ii/scripts/colors/applycolor.sh"]
    }

    // Recompute widget positions on shell startup to ensure they persist across boots
    Process {
        id: updateWidgetPositionsProcess
        running: true
        command: [Quickshell.env("HOME") + "/.config/quickshell/ii/scripts/images/update_widget_positions.sh"]
    }

    AnimationsPreview { id: animationsPreview }

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
        function toggle(): void { animationsPreview.windowVisible = !animationsPreview.windowVisible }
        function open(): void { animationsPreview.windowVisible = true }
        function close(): void { animationsPreview.windowVisible = false }
    }

    GlobalShortcut { name: "panelFamilyCycle"; onPressed: root.cyclePanelFamily() }
    GlobalShortcut { name: "animations"; onPressed: animationsPreview.windowVisible = !animationsPreview.windowVisible }
}
