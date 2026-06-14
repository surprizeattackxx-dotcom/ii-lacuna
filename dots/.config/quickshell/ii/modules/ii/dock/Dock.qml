import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

pragma ComponentBehavior: Bound

Scope {
    id: dock

    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false

    readonly property string dockEffectivePosition: {
        const pos = Config.options?.dock.position ?? "bottom"
        if (pos !== "auto") return pos
        return (Config.options?.bar.bottom && !Config.options?.bar.vertical) ? "top" : "bottom"
    }

    readonly property bool isVertical: dockEffectivePosition === "left" || dockEffectivePosition === "right"

    function computeSizes(opts) {
        const gapsOut = opts.gapsOut
        const headroom = opts.magnifyHeadroom ?? 0
        const spread = opts.magnifySpread ?? 0
        const barConflicts = opts.barActive && (opts.isVertical !== opts.barIsVertical)

        const barOffset = barConflicts ? (opts.isVertical ? opts.barThickness : 0) : 0
        const barOffsetH = barConflicts ? (!opts.isVertical ? opts.barThickness : 0) : 0

        const maxW = Math.max(1, opts.availableW - gapsOut * 2 - barOffsetH)
        const maxH = Math.max(1, opts.availableH - gapsOut * 2 - barOffset)

        const contentW = opts.contentVisualWidth + opts.dockPadding * 2
        const contentH = opts.contentVisualHeight + opts.dockPadding * 2

        // Headroom is added only to the dock's cross-axis (thickness), giving magnified
        // icons transparent space to balloon into above the translucent bar — mac-style.
        const crossW = contentW + gapsOut * 2 + (opts.isVertical ? headroom : 0)
        const crossH = contentH + gapsOut * 2 + (opts.isVertical ? 0 : headroom)

        // The ripple spread grows the bar along its length only.
        const longW = opts.isVertical ? contentW : contentW + spread
        const longH = opts.isVertical ? contentH + spread : contentH

        return {
            maxWidth: maxW,
            maxHeight: maxH,
            dockWidth:     opts.isVertical ? crossW : Math.min(longW + gapsOut * 2, maxW),
            dockHeight:    opts.isVertical ? Math.min(longH + gapsOut * 2, maxH) : crossH,
            dockThickness: opts.isVertical ? crossW : crossH,
            reservedThickness: opts.isVertical ? contentW + gapsOut * 2 : contentH + gapsOut * 2,
            backgroundWidth:  Math.max(1, opts.isVertical ? contentW : Math.min(longW, maxW - gapsOut * 2)),
            backgroundHeight: Math.max(1, opts.isVertical ? Math.min(longH, maxH - gapsOut * 2) : contentH),
            contentWidth:  Math.max(1, opts.isVertical ? contentW : Math.min(contentW, maxW - gapsOut * 2)),
            contentHeight: Math.max(1, opts.isVertical ? Math.min(contentH, maxH - gapsOut * 2) : contentH)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            
            visible: !GlobalStates.screenLocked && !positionChanging 
            // using a flag for positionChanging is not really necessary, but it prevents some graphical issues caused by qml when the dock is moving

            readonly property real availableW: screen?.width ?? 1920
            readonly property real availableH: screen?.height ?? 1080
            readonly property bool barActive: GlobalStates.barOpen
            readonly property bool barIsVertical: Config.options?.bar?.vertical ?? false
            readonly property real barThickness: barActive? (barIsVertical ? (Config.options?.bar?.sizes?.width ?? Appearance.sizes.verticalBarWidth) : (Config.options?.bar?.sizes?.height ?? Appearance.sizes.barHeight)) : 0

            readonly property bool isVertical: dock.isVertical
            readonly property real dockThickness: isVertical ? dockRoot.sizing.dockWidth : dockRoot.sizing.dockHeight

            readonly property real magnifyHeadroom: {
                const magOn = Config.options?.dock.hoverMagnify ?? true
                const mag = magOn ? (Config.options?.dock.hoverMagnifyScale ?? 1.3) : 1.0
                const btn = Appearance.sizes.dockButtonSize
                const dm = (Config.options?.dock.height ?? 60) * 0.2
                return Math.max(0, Math.round((mag - 1) * btn - dm + 6))
            }
            property bool reveal: dock.pinned || (Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse) || (dockContent.requestDockShow) || (workspaceEmpty)
            property bool positionChanging: false

            readonly property bool workspaceEmpty: {
                const monitor = HyprlandData.monitors.find(m => m.name === dockRoot.screen?.name)
                const wsId = monitor?.activeWorkspace?.id ?? -1
                if (wsId === -1) return true
                return HyprlandData.hyprlandClientsForWorkspace(wsId).length === 0
            }

            readonly property var sizing: dock.computeSizes({
                gapsOut: Appearance.sizes.hyprlandGapsOut,
                isVertical: dock.isVertical,
                barActive: barActive,
                barIsVertical: barIsVertical,
                barThickness: barThickness,
                availableW: availableW,
                availableH: availableH,
                contentVisualWidth: dockContent.visualWidth,
                contentVisualHeight: dockContent.visualHeight,
                dockPadding: dockContent.dockPadding,
                magnifyHeadroom: magnifyHeadroom,
                magnifySpread: dockContent.magnifySpread
            })

            implicitWidth: Math.max(1, dockRoot.sizing.dockWidth)
            implicitHeight: Math.max(1, dockRoot.sizing.dockHeight)

            anchors {
                top: dock.dockEffectivePosition !== "bottom"
                bottom: dock.dockEffectivePosition !== "top"
                left: dock.dockEffectivePosition !== "right"
                right: dock.dockEffectivePosition !== "left"
            }

            exclusiveZone: dock.pinned ? dockRoot.sizing.reservedThickness : 0
            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            // Mask the bar plus a thin inner-edge strip (the auto-reveal trigger), so the
            // transparent balloon headroom above the bar stays click-through.
            mask: Region {
                Region { item: dockVisualBackground }
                Region { item: revealSensor }
            }

            Timer {
                id: positionChangeTimer
                interval: 200
                onTriggered: dockRoot.positionChanging = false
            }

            Connections {
                target: dock
                function onDockEffectivePositionChanged() {
                    dockRoot.positionChanging = true
                    positionChangeTimer.restart()
                }
            }

            HyprlandFocusGrab {
                id: dragFocusGrab
                active: dockContent.dragState != "idle"
                windows: [dockRoot]
                onCleared: {
                    if (dockContent.isAppDrag) dockContent.endDrag()
                    if (dockContent.isFileDrag) dockContent.endFileDrag()
                }
            }

            MouseArea {
                id: dockMouseArea
                hoverEnabled: true

                property real hiddenOffset: dockRoot.dockThickness - (Config.options?.dock.hoverRegionHeight ?? 10)
                property real fullyHiddenOffset: dockRoot.dockThickness + 1
                property real currentOffset: dockRoot.reveal ? 0 : (Config.options?.dock.hoverToReveal ? hiddenOffset : fullyHiddenOffset)

                width: dock.isVertical ? dockRoot.dockThickness : dockRoot.sizing.dockWidth
                height: dock.isVertical ? dockRoot.sizing.dockHeight : dockRoot.dockThickness

                Item {
                    id: revealSensor
                    readonly property string dp: dock.dockEffectivePosition
                    readonly property real hr: Config.options?.dock.hoverRegionHeight ?? 2
                    anchors.top: dp !== "top" ? parent.top : undefined
                    anchors.bottom: dp !== "bottom" ? parent.bottom : undefined
                    anchors.left: dp !== "left" ? parent.left : undefined
                    anchors.right: dp !== "right" ? parent.right : undefined
                    width: dock.isVertical ? hr : undefined
                    height: dock.isVertical ? undefined : hr
                }

                state: dock.dockEffectivePosition

                states: [
                    State {
                        name: "top"
                        AnchorChanges { target: dockMouseArea; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.topMargin: -currentOffset }
                    },
                    State {
                        name: "bottom"
                        AnchorChanges { target: dockMouseArea; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.bottomMargin: -currentOffset }
                    },
                    State {
                        name: "left"
                        AnchorChanges { target: dockMouseArea; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.leftMargin: -currentOffset }
                    },
                    State {
                        name: "right"
                        AnchorChanges { target: dockMouseArea; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.rightMargin: -currentOffset }
                    }
                ]

                Behavior on anchors.topMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.bottomMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.leftMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.rightMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }

                StyledRectangularShadow { target: dockVisualBackground }

                Rectangle {
                    id: dockVisualBackground

                    readonly property string dpos: dock.dockEffectivePosition
                    anchors.bottom: dpos === "bottom" ? parent.bottom : undefined
                    anchors.top: dpos === "top" ? parent.top : undefined
                    anchors.left: dpos === "left" ? parent.left : undefined
                    anchors.right: dpos === "right" ? parent.right : undefined
                    anchors.horizontalCenter: dock.isVertical ? undefined : parent.horizontalCenter
                    anchors.verticalCenter: dock.isVertical ? parent.verticalCenter : undefined
                    anchors.bottomMargin: dpos === "bottom" ? Appearance.sizes.hyprlandGapsOut : 0
                    anchors.topMargin: dpos === "top" ? Appearance.sizes.hyprlandGapsOut : 0
                    anchors.leftMargin: dpos === "left" ? Appearance.sizes.hyprlandGapsOut : 0
                    anchors.rightMargin: dpos === "right" ? Appearance.sizes.hyprlandGapsOut : 0

                    width: dockRoot.sizing.backgroundWidth
                    height: dockRoot.sizing.backgroundHeight

                    Behavior on width { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockVisualBackground) }
                    Behavior on height { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockVisualBackground) }

                    color: "transparent"
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    radius: Appearance.rounding.large

                    GlassPanel {
                        anchors.fill: parent
                        anchors.margins: 1
                        cornerRadius: dockVisualBackground.radius - 1
                        screen: dockVisualBackground.QsWindow.window?.screen
                        screenX: ((dockVisualBackground.QsWindow.window?.screen?.width ?? 0) - width) / 2
                        screenY: (dockVisualBackground.QsWindow.window?.screen?.height ?? 0) - height - Appearance.sizes.hyprlandGapsOut
                        tint: Appearance.colors.colLayer0
                    }

                    DropArea {
                        id: fileDropArea
                        anchors.fill: parent
                        keys: ["text/uri-list"]

                        // We delay the re-enablement slightly after an internal drag ends
                        // to prevent the "exited" event from firing for the internal drag.
                        property bool blockDueToInternal: dockContent.dragActive
                        onBlockDueToInternalChanged: {
                            if (!blockDueToInternal) {
                                reEnableTimer.restart()
                            } else {
                                enabled = false
                            }
                        }

                        Timer {
                            id: reEnableTimer
                            interval: 50
                            onTriggered: fileDropArea.enabled = true
                        }

                        onEntered: (drag) => {
                            if (!drag.hasUrls) return
                            //console.log("[Dock] External drag entered")
                            const url = drag.urls[0]?.toString() ?? ""
                            dockContent.externalDragIcon = dockContent.mimeIconFromPath(url)
                            dockContent.externalDragOver = true
                        }
                        onExited: {
                            //console.log("[Dock] External drag exited")
                            dockContent.externalDragIcon = ""
                            dockContent.externalDragOver = false
                        }
                        onDropped: (drop) => {
                            if (!drop.hasUrls) return
                            //console.log("[Dock] External drag dropped")
                            for (let i = 0; i < drop.urls.length; i++)
                                TaskbarApps.addPinnedFile(drop.urls[i])
                            drop.accept(Qt.CopyAction)
                            dockContent.externalDragIcon = ""
                            dockContent.externalDragOver = false
                        }
                    }

                    DockContent {
                        id: dockContent
                        // Stay at resting size, centred in the bar. The bar grows around it
                        // for the ripple; keeping this fixed means the magnify math never
                        // sees a moving coordinate frame (no feedback, no drift).
                        anchors.centerIn: parent
                        width: dockRoot.sizing.contentWidth
                        height: dockRoot.sizing.contentHeight
                        isPinned: dock.pinned
                        currentScreen: dockRoot.screen
                        onTogglePinRequested: {
                            dock.pinned = !dock.pinned
                        }
                    }
                }
            }
        }
    }
}