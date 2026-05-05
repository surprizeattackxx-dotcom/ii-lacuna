import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/*
 *    Almost all of the custom color schemes (latte.json, samurai.json etc.) are gotten from https://github.com/snowarch/quickshell-ii-niri/blob/main/modules/common/ThemePresets.qml
 *
 *    To add a new custom color scheme:
 *
 *    1. Get a proper color scheme (in the same format as the default ones) and put in to ~/.config/illogical_impulse/themes
 *    2. Add the exact name of the json file to the config.json - appearance - customColorSchemes
 */

ColumnLayout {
    id: root
    spacing: 6
    Layout.fillWidth: true
    implicitWidth: parent?.width ?? 0

    property bool customTheme: false
    property bool builtInTheme: false

    readonly property list<string> wallpaperColorSchemes: ["scheme-auto", "scheme-content", "scheme-tonal-spot", "scheme-fidelity", "scheme-fruit-salad", "scheme-expressive", "scheme-rainbow", "scheme-neutral", "scheme-monochrome"]
    property list<string> customColorSchemes: Config.options.appearance.customColorSchemes ?? []

    // Built-in themes — auto-detected from the themes directory
    property list<string> detectedBuiltInSchemes: []

    property list<string> colorSchemes: customTheme
    ? customColorSchemes
    : builtInTheme
    ? detectedBuiltInSchemes
    : root.wallpaperColorSchemes

    property string filterText: ""
    property list<string> filteredSchemes: colorSchemes.filter(s =>
    filterText.trim() === "" || s.toLowerCase().includes(filterText.toLowerCase())
    )

    property int loadedCount: 0

    // Batch color preview data for wallpaper schemes (keyed by scheme name)
    property var batchPreviewColors: ({})
    readonly property string configWallpaperPath: Config.options.background.wallpaperPath
    property string resolvedWallpaperPath: ""
    readonly property string wallpaperPath: configWallpaperPath || resolvedWallpaperPath
    readonly property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/generate_colors_material.py`)
    readonly property string venvPython: `${FileUtils.trimFileProtocol(Directories.home)}/.local/state/quickshell/.venv/bin/python3`

    // Resolve wallpaper path from per-monitor state when config path is empty
    Process {
        id: wallpaperPathResolver
        running: false
        command: ["bash", "-c", `
focused_monitor="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)"
if [[ -n "$focused_monitor" && -f "${Wallpapers.monitorStateDir}/$focused_monitor.json" ]]; then
    jq -r '.path // empty' "${Wallpapers.monitorStateDir}/$focused_monitor.json" 2>/dev/null
else
    first_state="$(find "${Wallpapers.monitorStateDir}" -name "*.json" 2>/dev/null | sort | head -1)"
    [[ -n "$first_state" ]] && jq -r '.path // empty' "$first_state" 2>/dev/null
fi
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path.length > 0) root.resolvedWallpaperPath = path
            }
        }
    }

    // Batch fetch all wallpaper scheme previews in one Python call
    Process {
        id: batchColorFetch
        running: false
        command: ["bash", "-c", `${root.venvPython} ${root.scriptPath} --path '${root.wallpaperPath}' --preview-all 2>/dev/null`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.batchPreviewColors = JSON.parse(this.text)
                } catch (e) {
                    console.log("[ColorPreviewGrid] Batch parse error:", this.text)
                }
            }
        }
    }

    onWallpaperPathChanged: {
        if (wallpaperPath && !customTheme && !builtInTheme) {
            batchColorFetch.running = true
        }
    }

    function formatText(text) {
        if (customTheme || builtInTheme) return text.charAt(0).toUpperCase() + text.slice(1).replace(/_/g, " ");
        const sliced = text.split("-").slice(1).join(" ");
        return sliced.charAt(0).toUpperCase() + sliced.slice(1);
    }

    function removeCustomTheme(schemeName) {
        const idx = Config.options.appearance.customColorSchemes.indexOf(schemeName)
        if (idx !== -1) {
            Config.options.appearance.customColorSchemes.splice(idx, 1)
            // Force notify
            Config.options.appearance.customColorSchemes = [...Config.options.appearance.customColorSchemes]
        }
    }

    // Auto-detect built-in themes from themes directory
    Process {
        id: themeDetector
        running: root.builtInTheme
        command: ["bash", "-c", `ls '${Directories.defaultThemes}'/*.json 2>/dev/null | xargs -I{} basename {} .json | sort`]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.trim().split("\n").filter(l => l.trim() !== "")
                if (names.length > 0) root.detectedBuiltInSchemes = names
            }
        }
    }

    // Search bar — only shown when there are enough schemes to warrant filtering
    Loader {
        Layout.fillWidth: true
        active: root.colorSchemes.length > 6
        sourceComponent: MaterialTextField {
            placeholderText: Translation.tr("Filter themes…")
            onTextChanged: root.filterText = text
        }
    }

    // No results label
    StyledText {
        visible: root.filteredSchemes.length === 0 && root.filterText.trim() !== ""
        Layout.alignment: Qt.AlignHCenter
        text: Translation.tr("No themes match \"%1\"").arg(root.filterText)
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colSubtext
        opacity: 0.7
    }

    GridLayout {
        id: grid
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 4
        rowSpacing: 4

        Repeater {
            model: root.filteredSchemes

            delegate: ColorPreviewButton {
                Layout.fillWidth: true

                colorScheme: modelData
                colorSchemeDisplayName: root.formatText(modelData)
                customTheme: root.customTheme
                builtInTheme: root.builtInTheme

                batchColors: (!root.customTheme && !root.builtInTheme)
                    ? root.batchPreviewColors[modelData] ?? null
                    : null

                shouldLoad: {
                    const realIndex = root.colorSchemes.indexOf(modelData)
                    return realIndex < root.loadedCount
                }

                onDeleteRequested: (schemeName) => root.removeCustomTheme(schemeName)
            }
        }
    }

    Timer {
        id: loadTimer
        interval: 20
        repeat: true
        running: false
        onTriggered: {
            root.loadedCount += 1
            if (root.loadedCount >= root.colorSchemes.length) loadTimer.stop()
        }
    }

    Component.onCompleted: {
        if (root.customTheme || root.builtInTheme) {
            // Staggered loading for custom/builtIn themes (individual process per button)
            Qt.callLater(() => loadTimer.start())
        } else if (!root.configWallpaperPath) {
            // Need to resolve wallpaper path first, then batch fetch triggers via onWallpaperPathChanged
            wallpaperPathResolver.running = true
        } else {
            // Wallpaper path known — batch fetch all scheme previews
            batchColorFetch.running = true
        }
    }

    onColorSchemesChanged: {
        root.loadedCount = 0
        if (root.customTheme || root.builtInTheme) {
            Qt.callLater(() => loadTimer.start())
        }
    }
}
