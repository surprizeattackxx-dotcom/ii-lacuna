import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property real currentWidth: 1920.0
    property real uiScale: 1.0

    readonly property real baseScale: {
        if (currentWidth <= 0) return uiScale
        let r = currentWidth / 1920.0
        let b = r <= 1.0 ? Math.max(0.35, Math.pow(r, 0.85)) : Math.pow(r, 0.5)
        return b * uiScale
    }

    function s(val) {
        return Math.round(val * baseScale)
    }

    Process {
        id: scaleReader
        command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                        let parsed = JSON.parse(this.text)
                        if (parsed.uiScale !== undefined && root.uiScale !== parsed.uiScale)
                            root.uiScale = parsed.uiScale
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: scaleWatcher
        command: ["bash", "-c", "while [ ! -f ~/.config/hypr/settings.json ]; do sleep 1; done; inotifywait -qq -e modify,close_write ~/.config/hypr/settings.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                scaleReader.running = false
                scaleReader.running = true
                scaleWatcher.running = false
                scaleWatcher.running = true
            }
        }
    }
}
