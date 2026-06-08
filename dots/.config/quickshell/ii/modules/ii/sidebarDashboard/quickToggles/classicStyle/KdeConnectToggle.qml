import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

QuickToggleButton {
    id: root
    visible: true

    property string deviceName: Translation.tr("Not connected")
    property int deviceCount: 0
    property int batteryLevel: 0

    readonly property string _scriptPath: FileUtils.trimFileProtocol(Directories.scriptPath)

    toggled: root.deviceCount > 0
    buttonIcon: root.deviceCount > 0 ? "phone_android" : "phone_disabled"
    onClicked: {
        Quickshell.execDetached(["bash", "-c", `J=$HOME/.local/state/quickshell/user/generated/colors.json; BG=$(python3 -c "import json;print(json.load(open('$J'))['surface'])" 2>/dev/null||echo '#1e1e2e'); FG=$(python3 -c "import json;print(json.load(open('$J'))['on_surface'])" 2>/dev/null||echo '#cdd6f4'); kitty --class kde-connect-tui -o background_opacity=1.0 -o background=$BG -o foreground=$FG -o window_padding_width=14 -e ${root._scriptPath}/kdeconnect/kdeconnect.sh interactive`])
    }

    function parseState() {
        var text = collector.text.trim()
        if (text.length > 0) {
            var lines = text.split('\n').filter(function(l) { return l.trim().length > 0 })
            root.deviceCount = lines.length
            var parts = lines[0].split('|')
            if (parts.length >= 3) {
                root.deviceName = parts[1]
                root.batteryLevel = parseInt(parts[2]) || 0
            }
        } else {
            root.deviceCount = 0
            root.deviceName = Translation.tr("Not connected")
            root.batteryLevel = 0
        }
    }

    Process {
        id: pollProc
        running: true
        command: ["bash", "-c", `SIMPLE=1 ${root._scriptPath}/kdeconnect/kdeconnect.sh status 2>/dev/null || true`]
        stdout: StdioCollector {
            id: collector
            onStreamFinished: root.parseState()
        }
    }

    Timer {
        interval: 15000
        repeat: true
        onTriggered: { pollProc.running = true }
    }

    StyledToolTip {
        text: root.deviceCount > 0
            ? Translation.tr("%1 · %2% battery").arg(root.deviceName).arg(root.batteryLevel)
            : Translation.tr("KDE Connect")
    }
}
