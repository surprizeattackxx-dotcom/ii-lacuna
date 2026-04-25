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
        const enabling = !root.toggled;
        if (enabling) {
            Quickshell.execDetached(["bash", "-c",
                `hyprctl --batch "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0; keyword general:allow_tearing 1"`
            ]);
            refetchTimer.restart();
        } else {
            Quickshell.execDetached(["hyprctl", "reload"]);
            // configreloaded event fires after reload, which auto-triggers confOpt.fetch()
        }
    }

    Timer {
        id: refetchTimer
        interval: 500
        onTriggered: confOpt.fetch()
    }

    HyprlandConfigOption {
        id: confOpt
        key: "animations:enabled"
    }

    tooltipText: Translation.tr("Game mode")
}
