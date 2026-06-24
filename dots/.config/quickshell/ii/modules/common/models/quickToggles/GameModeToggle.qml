import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.models.hyprland
import qs.services

QuickToggleModel {
    id: root
    name: Translation.tr("Game mode")
    toggled: confOpt.value !== undefined ? !confOpt.value : false
    icon: "gamepad"

    mainAction: () => {
        root.toggled = !root.toggled;
        if (root.toggled) {
            Quickshell.execDetached(["hyprctl", "eval", `hl.config({ animations = { enabled = false }, decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0 }, general = { gaps_in = 0, gaps_out = 0, border_size = 1, allow_tearing = true } })`]);
        } else {
            Quickshell.execDetached(["hyprctl", "reload"])
        }
    }

    HyprlandConfigOption {
        id: confOpt
        key: "animations:enabled"
    }

    tooltipText: Translation.tr("Game mode")
}
