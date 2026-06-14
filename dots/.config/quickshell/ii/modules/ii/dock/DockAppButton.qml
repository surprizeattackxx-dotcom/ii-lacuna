import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs
import QtQuick
import Quickshell.Wayland

import "./widgets"

DockButton {
    id: root

    property var appToplevel: null
    property var dockContent: null
    property int delegateIndex: -1
    property int lastFocused: -1

    readonly property real dockHeight: Config.options?.dock.height ?? 60
    property int dotMargin: Math.round(dockHeight * 0.2)

    readonly property var desktopEntry: appToplevel ? TaskbarApps.getCachedDesktopEntry(appToplevel.appId) : null
    property bool isVertical: dockContent?.isVertical ?? false


    readonly property bool appIsActive: focusedWindowIndex >= 0
    readonly property int focusedWindowIndex: {
        const active = ToplevelManager.activeToplevel
        if (!active || !appToplevel?.toplevels) return -1
        return appToplevel.toplevels.indexOf(active)
    }

    readonly property bool demandsAttention: appToplevel && !appIsActive && (dockContent?.attentionAppIds ?? []).includes(appToplevel.appId)
    readonly property bool isDragging: dockContent?.draggedAppId === appToplevel?.appId
    readonly property string dockPos: dock.dockEffectivePosition
    readonly property bool appIsRunning: appToplevel && appToplevel.toplevels && appToplevel.toplevels.length > 0

    pointingHandCursor: false

    width: buttonSize + dotMargin * 2
    height: buttonSize + dotMargin * 2

    opacity: isDragging ? 0.0 : 1.0

    Behavior on opacity {
        enabled: !isDragging && !(dockContent?.suppressAnimation ?? false)
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    z: isDragging ? 100 : Math.round((magScale - 1) * 100)

    // Computes how much this delegate should shift to make room for the dragged item
    readonly property real shiftOffset: {
        if (!dockContent || !dockContent.dragActive) return 0
        if (delegateIndex === dockContent.draggedIndex) return 0

        const step = buttonSize + dotMargin * 2
        const isThisPinned = TaskbarApps.isPinned(appToplevel?.appId ?? "")
        const isDraggedPinned = TaskbarApps.isPinned(dockContent.draggedAppId)
        const intent = dockContent.dragIntent

        // Case 1: reordering among pinned apps
        if (isThisPinned && isDraggedPinned) {
            const d = dockContent.draggedIndex

            if (intent === "unpin") {
                if (delegateIndex > d) return step
                return 0
            }

            if (intent === "reorder") {
                const t = dockContent.dropTargetIndex
                if (t > d && delegateIndex > d && delegateIndex <= t) return step
                if (t < d && delegateIndex >= t && delegateIndex < d) return -step
            }
            return 0
        }

        // Case 2: pinning a running app — shift running delegates out of the way
        if (!isDraggedPinned && !isThisPinned && intent === "pin") {
            if (delegateIndex > dockContent.draggedIndex) return -step
        }

        return 0
    }

    transform: Translate {
        x: root.isVertical ? 0 : root.shiftOffset
        y: root.isVertical ? root.shiftOffset : 0

        Behavior on x {
            enabled: !root.isDragging && !(dockContent?.suppressAnimation ?? false)
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on y {
            enabled: !root.isDragging && !(dockContent?.suppressAnimation ?? false)
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    MouseArea {
        id: mainMouseArea
        width: root.buttonSize
        height: root.buttonSize
        anchors.centerIn: parent
        cursorShape: Qt.PointingHandCursor

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        preventStealing: drag.active

        drag.target: appToplevel ? dockContent.dragGhostItem : null
        drag.axis: root.isVertical ? Drag.YAxis : Drag.XAxis
        drag.threshold: 4

        readonly property real ghostHalf: (dockContent?.dragGhostItem?.width ?? 0) / 2

        drag.minimumX: root.isVertical ? 0 : (dockContent?.pinButtonCenter ?? 0) - ghostHalf
        drag.maximumX: root.isVertical ? 0 : (dockContent?.unpinButtonCenter ?? 0) - ghostHalf
        drag.minimumY: root.isVertical ? (dockContent?.pinButtonCenter ?? 0) - ghostHalf : 0
        drag.maximumY: root.isVertical ? (dockContent?.unpinButtonCenter ?? 0) - ghostHalf : 0

        property bool wasDragging: false
        property bool wheelReady: true

        Timer {
            id: wheelCooldown
            interval: 130
            onTriggered: mainMouseArea.wheelReady = true
        }

        onEntered: {
            if (dockContent?.suppressHover) return
            if (appToplevel?.toplevels?.length > 0) {
                dockContent.lastHoveredButton = root
                dockContent.buttonHovered = true
            } else {
                dockContent.buttonHovered = false
                dockContent.popupIsResizing = false
            }
            if (appToplevel && appToplevel.toplevels)
                lastFocused = appToplevel.toplevels.length - 1
        }

        onExited: {
            if (dockContent?.lastHoveredButton === root)
                dockContent.buttonHovered = false
        }

        onPressed: (mouse) => {
            wasDragging = false
            if (dockContent?.dragGhostItem && appToplevel) {
                const p = root.mapToItem(dockContent, 0, 0)
                dockContent.dragGhostItem.x = p.x + root.dotMargin
                dockContent.dragGhostItem.y = p.y + root.dotMargin
            }
        }

        onPositionChanged: (mouse) => {
            if (!drag.active || !appToplevel) return
            if (!wasDragging) {
                wasDragging = true
                dockContent.startDrag(root.appToplevel.appId, root.delegateIndex)
            }
            dockContent.moveDrag()
        }

        onReleased: (mouse) => {
            if (wasDragging) {
                wasDragging = false
                dockContent.endDrag()
                return
            }
            if (mouse.button === Qt.RightButton) {
                dockContent.buttonHovered = false
                dockContent.lastHoveredButton = null
                dockContextMenu.open()
                return
            }
            if (mouse.button === Qt.MiddleButton) {
                root.desktopEntry?.execute()
                root.startBounce()
                return
            }
            if (!appToplevel || appToplevel.toplevels.length === 0) {
                root.desktopEntry?.execute()
                root.startBounce()
                return
            }
            // Cycle through open windows on left click
            pressAnim.restart()
            lastFocused = (lastFocused + 1) % appToplevel.toplevels.length
            appToplevel.toplevels[lastFocused].activate()
        }

        onWheel: (wheel) => {
            const tls = appToplevel?.toplevels ?? []
            if (tls.length < 2) { wheel.accepted = false; return }
            if (!wheelReady) { wheel.accepted = true; return }
            wheelReady = false
            wheelCooldown.restart()
            const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
            const dir = delta > 0 ? -1 : 1
            const base = root.focusedWindowIndex >= 0 ? root.focusedWindowIndex : root.lastFocused
            const next = ((base + dir) % tls.length + tls.length) % tls.length
            root.lastFocused = next
            tls[next].activate()
            wheel.accepted = true
        }
    }

    altAction: () => {
        dockContent.buttonHovered = false
        dockContent.lastHoveredButton = null
        dockContextMenu.open()
    }

    DockContextMenu {
        id: dockContextMenu
        appToplevel: root.appToplevel
        desktopEntry: root.desktopEntry
        anchorItem: root
    }

    Connections {
        target: dockContextMenu
        function onActiveChanged() {
            if (dockContent)
                dockContent.anyContextMenuOpen = dockContextMenu.active
        }
    }

    HoverHandler {
        id: slotHover
    }

    property real bounceScale: 1.0
    property real pressScale: 1.0
    property bool launching: false

    // macOS-style magnification: scale falls off with cursor distance along the dock axis
    readonly property real magScale: {
        const dc = dockContent
        if (!dc || !dc.magnifyEnabled || !dc.magnifyActive || isDragging || dc.dragActive)
            return 1.0
        const host = dc.magnifyHost
        if (!host) return 1.0
        const c = mapToItem(host, width / 2, height / 2)
        const mine = isVertical ? c.y : c.x
        const d = mine - dc.magnifyCursor
        const sigma = dc.magnifySigma
        return 1.0 + (dc.magnifyMax - 1.0) * Math.exp(-(d * d) / (2 * sigma * sigma))
    }

    // macOS ripple: icons translate away from the cursor so a gap opens under it
    readonly property real magShift: {
        const dc = dockContent
        if (!dc || !dc.magnifyEnabled || !dc.magnifyActive || isDragging || dc.dragActive)
            return 0
        const host = dc.magnifyHost
        if (!host) return 0
        const c = mapToItem(host, width / 2, height / 2)
        return dc.magnifySpreadAt(isVertical ? c.y : c.x)
    }

    function startBounce() {
        if (root.appIsRunning) { pressAnim.restart(); return }
        root.launching = true
        launchTimeout.restart()
    }
    onAppIsRunningChanged: if (appIsRunning) launching = false
    onLaunchingChanged: if (!launching && !demandsAttention) bounceScale = 1.0
    onDemandsAttentionChanged: if (!demandsAttention && !launching) bounceScale = 1.0

    Timer { id: launchTimeout; interval: 8000; onTriggered: root.launching = false }

    SequentialAnimation {
        id: bounceAnim
        running: root.launching || root.demandsAttention
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "bounceScale"; from: 1.0; to: 1.32; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "bounceScale"; to: 1.0; duration: 340; easing.type: Easing.OutBounce }
        PauseAnimation { duration: 220 }
    }

    SequentialAnimation {
        id: pressAnim
        NumberAnimation { target: root; property: "pressScale"; to: 0.82; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "pressScale"; to: 1.0; duration: 280; easing.type: Easing.OutBack }
    }

    DockAppIcon {
        scale: root.magScale * root.bounceScale * root.pressScale
        transformOrigin: root.isVertical
            ? (root.dockPos === "left" ? Item.Left : Item.Right)
            : (root.dockPos === "top" ? Item.Top : Item.Bottom)
        anchors.horizontalCenterOffset: root.isVertical ? 0 : root.magShift
        anchors.verticalCenterOffset: root.isVertical ? root.magShift : 0
    }
    DockAppIndicator {
        transform: Translate {
            x: root.isVertical ? 0 : root.magShift
            y: root.isVertical ? root.magShift : 0
        }
    }

    DockTooltip {
        parentItem: root
        text: root.desktopEntry?.name ?? root.appToplevel?.appId ?? ""
        showTooltip: slotHover.hovered && !root.isDragging
            && !(dockContent?.dragActive ?? false)
            && (root.appToplevel?.toplevels?.length ?? 0) === 0
        tooltipOffset: -root.dotMargin
    }
}
