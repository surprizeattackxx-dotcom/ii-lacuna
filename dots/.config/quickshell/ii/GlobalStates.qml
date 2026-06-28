import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    property alias sidebarLeftOpen: root.policiesPanelOpen // Until all sidebars naming is fixed
    property alias sidebarRightOpen: root.dashboardPanelOpen // Until all sidebars naming is fixed

    property string activeTheme: Persistent.states.activeTheme
    onActiveThemeChanged: Persistent.states.activeTheme = activeTheme
    property bool barOpen: true
    property bool barAppletsOpen: false
    property bool crosshairOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property real osdVolumeOverride: -1
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool screenTranslatorOpen: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property bool wallpaperChangerOpen: false
    property bool wallpaperTransitioning: false
    // Live (non-persisted) wallpaper preview path, set while browsing the wallpaperChanger.
    // Empty string = no preview, background shows the real wallpaper.
    property string wallpaperPreviewPath: ""
    // Name of the monitor the preview targets (the focused one), so other monitors don't preview.
    property string wallpaperPreviewMonitor: ""
    // True when the changer closed because a wallpaper was committed (Enter/click), so the
    // preview is held briefly until switchwall.sh updates the real state instead of flashing.
    property bool wallpaperPreviewCommitted: false
    property bool workspaceShowNumbers: true
    property bool isScrollingLayout: false

    // Published by the dock so other edge panels (e.g. the vertical bar) can
    // reclaim the bottom strip the dock reserves and still reach the screen edge.
    property bool dockReserving: false
    property real dockReservedThickness: 0

    property bool appLauncherOpen: false
    property bool gameLauncherOpen: false
    property bool calendarAppOpen: false
    property bool controlCenterOpen: false
    property bool dashboardPanelOpen: false // formerly sidebarRightOpen
    property bool policiesPanelOpen: false  // formerly sidebarLeftOpen

    // Pending text to pre-fill the AI chat input (cleared after AiChat consumes it)
    property string pendingAiInput: ""
    // STT state — toggled by voiceInput shortcut, consumed by AiChat
    property bool sttRecording: false
    property bool sttToggleRequested: false

    readonly property bool effectiveLeftOpen: {
        switch (Config.options.sidebar.position) {
            case "default":  return policiesPanelOpen;  
            case "inverted": return dashboardPanelOpen;  
            case "left":     return dashboardPanelOpen || policiesPanelOpen;
            case "right":    return false;
            default:         return policiesPanelOpen;
        }
    }
    readonly property bool effectiveRightOpen: {
        switch (Config.options.sidebar.position) {
            case "default":  return dashboardPanelOpen; 
            case "inverted": return policiesPanelOpen; 
            case "left":     return false;
            case "right":    return dashboardPanelOpen || policiesPanelOpen;
            default:         return dashboardPanelOpen;
        }
    }

    // helper properties
    readonly property bool policiesOnLeft: Config.options.sidebar.position === "default" || Config.options.sidebar.position === "left"
    readonly property bool dashboardOnLeft: Config.options.sidebar.position === "inverted" || Config.options.sidebar.position === "left"

    onPoliciesPanelOpenChanged: {
        if (policiesPanelOpen) {
            if (Config.options.sidebar.position == "right" || Config.options.sidebar.position == "left") {
                GlobalStates.dashboardPanelOpen = false
            }
        }
        
    }

    onDashboardPanelOpenChanged: {
        if (dashboardPanelOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
            if (Config.options.sidebar.position == "right" || Config.options.sidebar.position == "left") {
                GlobalStates.policiesPanelOpen = false
            }
        }
        
    }

    GlobalShortcut {
        name: "clipboardToAi"
        description: "Open AI sidebar pre-filled with clipboard text"
        onPressed: {
            root.pendingAiInput = Quickshell.clipboardText ?? "";
            root.policiesPanelOpen = true;
            Persistent.states.sidebar.policies.tab = 0;
        }
    }

    property bool openCodeRequested: false
    GlobalShortcut {
        name: "openCodeContext"
        description: "Open OpenCode pre-loaded with current context (clipboard + active window)"
        onPressed: {
            const clip = Quickshell.clipboardText ?? "";
            const win = Hyprland.activeToplevel;
            let ctx = "";
            if (win?.title || win?.wmClass)
                ctx += `Active window: ${win?.title ?? ""} (${win?.wmClass ?? ""})\n`;
            if (clip.trim().length > 0)
                ctx += `\nClipboard:\n${clip}\n`;
            if (ctx.length > 0) ctx += "\n";
            OpenCode.draftInput = ctx;
            root.openCodeRequested = true;
            root.policiesPanelOpen = true;
        }
    }

    GlobalShortcut {
        name: "voiceInput"
        description: "Toggle voice recording for AI chat STT"
        onPressed: {
            root.policiesPanelOpen = true;
            Persistent.states.sidebar.policies.tab = 0;
            root.sttToggleRequested = true;
        }
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"
        onPressed: {
            root.superDown = true
        }
        onReleased: {
            root.superDown = false
        }
    }


    IpcHandler {
        target: "wallpaper"
        function transition(): void {
            GlobalStates.wallpaperTransitioning = true
            wallpaperTransitionTimer.restart()
        }
    }

    IpcHandler {
        target: "controlCenter"
        function toggle(): void {
            GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen
        }
        function open(): void {
            GlobalStates.controlCenterOpen = true
        }
        function close(): void {
            GlobalStates.controlCenterOpen = false
        }
    }

    Timer {
        id: wallpaperTransitionTimer
        interval: 900
        repeat: false
        onTriggered: GlobalStates.wallpaperTransitioning = false
    }

    Process {
        running: true
        command: ["bash", "-c", "hyprctl getoption general:layout | grep 'str:' | awk '{print $2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                GlobalStates.isScrollingLayout = this.text.trim() === "scrolling"
            }
        }
    }
}
