pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.utils //FIXME. remove
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.common.functions as CF
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.modules.ii.background.widgets
import qs.modules.ii.background.widgets.clock
import qs.modules.ii.background.widgets.weather
import qs.modules.ii.background.widgets.media

// WpeWidgetOverlay — renders background widgets at WlrLayer.Bottom so they sit
// above WPE (which is at Bottom) but below xdg-toplevel windows (normal apps).
//
// Layer stack (bottom → top): awww-daemon | background | WPE | wpe-widgets | [windows] | overlay
//
// KEY: The PanelWindow is only CREATED when WPE is detected active on a monitor.
// This ensures wpe-widgets is registered AFTER WPE in the compositor's bottom layer,
// so the compositor stacks it on top of WPE. If created before WPE, it'd be below it.
// We add a short Timer delay to account for WPE startup lag.
Variants {
    id: root
    model: Quickshell.screens

    // Outer item: watches wallpaper state, conditionally creates the PanelWindow
    Item {
        id: perScreen
        required property var modelData

        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

        // ── Per-monitor wallpaper state ─────────────────────────────────────
        readonly property string wallpaperStatePath: {
            const stateDir = CF.FileUtils.trimFileProtocol(Directories.state).replace(/\/$/, "");
            return `${stateDir}/user/generated/wallpaper/monitors/${perScreen.monitor.name}.json`;
        }

        FileView {
            id: wallpaperStateFile
            path: perScreen.wallpaperStatePath
            blockLoading: true
            watchChanges: true
            onFileChanged: {
                reload()
                // When the state file changes while WPE is already active, WPE
                // restarted and its new surface is now above ours. Reset wpeReady
                // so the overlay window is destroyed and recreated after WPE settles.
                Qt.callLater(() => {
                    if (perScreen.wallpaperIsWpe && perScreen.wpeReady) {
                        perScreen.wpeReady = false
                        wpeDelayTimer.restart()
                    }
                })
            }
        }

        readonly property bool wallpaperIsWpe: {
            const raw = wallpaperStateFile?.text() ?? "";
            try { return JSON.parse(raw)?.wpe === true; } catch (e) { return false; }
        }

        // ── Per-monitor widget positions ────────────────────────────────────
        readonly property string widgetStatePath: {
            const stateDir = CF.FileUtils.trimFileProtocol(Directories.state).replace(/\/$/, "");
            return `${stateDir}/user/generated/widgets/monitors/${perScreen.monitor.name}.json`;
        }

        FileView {
            id: widgetStateFile
            path: perScreen.widgetStatePath
            blockLoading: true
            watchChanges: true
            onFileChanged: reload()
        }

        readonly property var monitorWidgetPositions: {
            const raw = widgetStateFile.text();
            try { return JSON.parse(raw) ?? {}; } catch (e) { return {}; }
        }

        function widgetX(name) {
            const pos = monitorWidgetPositions[name];
            return (pos !== undefined && pos.x !== undefined)
            ? pos.x
            : Config.options.background.widgets[name].x;
        }
        function widgetY(name) {
            const pos = monitorWidgetPositions[name];
            return (pos !== undefined && pos.y !== undefined)
            ? pos.y
            : Config.options.background.widgets[name].y;
        }

        // Colors — match Background.qml logic for WPE mode
        property color dominantColor: Appearance.colors.colPrimary
        property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
        property color colText: CF.ColorUtils.colorWithLightness(
            Appearance.colors.colPrimary,
            dominantColorIsDark ? 0.8 : 0.12
        )

        // Delay-gate: only activate the Loader after a short delay once WPE is seen.
        // This ensures WPE's Wayland surface is committed before ours, so we stack on top.
        property bool wpeReady: false

        Timer {
            id: wpeDelayTimer
            interval: 1500   // 1.5s after WPE detected — enough for WPE surface to commit
            repeat: false
            onTriggered: perScreen.wpeReady = true
        }

        onWallpaperIsWpeChanged: {
            if (wallpaperIsWpe && !wpeReady) {
                wpeDelayTimer.restart()
            } else if (!wallpaperIsWpe) {
                wpeDelayTimer.stop()
                wpeReady = false
            }
        }

        Component.onCompleted: {
            // If WPE is already active on startup (e.g. after --restore), start the timer
            if (wallpaperIsWpe && !wpeReady) {
                wpeDelayTimer.restart()
            }
        }

        // The PanelWindow is only INSTANTIATED when wpeReady = true.
        // When wpeReady goes false (WPE stopped), the window is destroyed and
        // will be re-created after the delay next time WPE starts.
        PanelWindow {
            id: overlayRoot

            screen: perScreen.modelData

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell:wpe-widgets"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: perScreen.wpeReady

            // ── Widget canvas ───────────────────────────────────────────
            WidgetCanvas {
                id: widgetCanvas
                anchors.fill: parent
                z: 1

                FadeLoader {
                    shown: Config.options.background.widgets.weather.enable
                    sourceComponent: WeatherWidget {
                        screenWidth: perScreen.modelData.width
                        screenHeight: perScreen.modelData.height
                        scaledScreenWidth: perScreen.modelData.width
                        scaledScreenHeight: perScreen.modelData.height
                        wallpaperScale: 1
                        overrideX: perScreen.widgetX("weather")
                        overrideY: perScreen.widgetY("weather")
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.clock.enable
                    sourceComponent: ClockWidget {
                        screenWidth: perScreen.modelData.width
                        screenHeight: perScreen.modelData.height
                        scaledScreenWidth: perScreen.modelData.width
                        scaledScreenHeight: perScreen.modelData.height
                        wallpaperScale: 1
                        wallpaperSafetyTriggered: false
                        overrideX: perScreen.widgetX("clock")
                        overrideY: perScreen.widgetY("clock")
                    }
                }

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        console.log("wallpaperIsWpe =", wallpaperIsWpe)
                        console.log("wpeReady =", wpeReady)
                    }
                }

                FadeLoader {
                    id: mediaLoader
                    property bool enableLoading: true
                    shown: Config.options.background.widgets.media.enable && enableLoading
                    sourceComponent: MediaWidget {
                        screenWidth: perScreen.modelData.width
                        screenHeight: perScreen.modelData.height
                        scaledScreenWidth: perScreen.modelData.width
                        scaledScreenHeight: perScreen.modelData.height
                        wallpaperScale: 1
                        overrideX: perScreen.widgetX("media")
                        overrideY: perScreen.widgetY("media")
                    }
                    onLoaded: {
                        if (item && item.requestReset) {
                            item.requestReset.connect(() => {
                                mediaLoader.enableLoading = false
                                mediaResetTimer.running = true
                            })
                        }
                    }
                }

                Timer {
                    id: mediaResetTimer
                    interval: 200
                    onTriggered: mediaLoader.enableLoading = true
                }
            }
        }
    }
}
