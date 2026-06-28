import qs.modules.ii.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

import Quickshell.Io

Item { // Bar content region
    id: root

    signal sectionGeometryChanged()

    property var screen: root.QsWindow.window?.screen
    property int monitorIndex
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0
    readonly property int centerSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth

    readonly property alias leftMaskRegionItem: leftMaskRegion
    readonly property alias middleMaskRegionItem: middleMaskRegion
    readonly property alias rightMaskRegionItem: rightMaskRegion

    property bool hasActiveWindows: false
    property bool showBarBackground: root.hasActiveWindows && Config.options.bar.barBackgroundStyle === 2 || Config.options.bar.barBackgroundStyle === 1

    Connections {
        enabled: Config.options.bar.barBackgroundStyle === 2
        target: HyprlandData
        function onWindowListChanged() {
            const monitor = HyprlandData.monitors.find(m => m.id === monitorIndex);
            const wsId = monitor?.activeWorkspace?.id;

            const hasWindow = wsId ? HyprlandData.windowList.some(w => w.workspace.id === wsId && !w.floating) : false;

            root.hasActiveWindows = hasWindow
        }
    }

    ////// Definning places of center modules //////
    property var fullModel: Config.options.bar.layouts.center

    property var leftList: []
    property var centerList: []
    property var rightList: []

    // JSON snapshot to detect deep changes that QML reference comparison misses
    property string _centerSnapshot: JSON.stringify(Config.options.bar.layouts.center)
    on_CenterSnapshotChanged: _splitCenter()
    onFullModelChanged: _splitCenter()

    function _splitCenter() {
        const model = Config.options.bar.layouts.center
        const idx = model.findIndex(item => item.centered)

        if (idx === -1) {
            leftList = []
            centerList = model
            rightList = []
            return
        }

        leftList = model.slice(0, idx)
        centerList = [model[idx]]
        rightList = model.slice(idx + 1)
    }

    // Background using Noctalia wrapped frame
    BarFrame {
        id: barFrame
        z: -10
        anchors {
            fill: parent
            topMargin: Config.options.bar.barType === "floating" ? (Appearance.sizes.hyprlandGapsOut + Config.options.bar.marginVertical) : Config.options.bar.marginVertical
            bottomMargin: Config.options.bar.barType === "floating" ? (Appearance.sizes.hyprlandGapsOut + Config.options.bar.marginVertical) : Config.options.bar.marginVertical
            leftMargin: Config.options.bar.barType === "floating" ? (Appearance.sizes.hyprlandGapsOut + Config.options.bar.marginHorizontal) : Config.options.bar.marginHorizontal
            rightMargin: Config.options.bar.barType === "floating" ? (Appearance.sizes.hyprlandGapsOut + Config.options.bar.marginHorizontal) : Config.options.bar.marginHorizontal
        }
        screen: root.screen
        tint: Appearance.colors.colLayer0
        visible: root.showBarBackground
    }

    MouseArea { // Right-click to open Bar Applets overlay
        anchors.fill: parent
        z: -5
        acceptedButtons: Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton)
                GlobalStates.barAppletsOpen = !GlobalStates.barAppletsOpen
        }
    }

    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        width: parent.width / 2
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: Brightness.decreaseBrightness()
        onScrollUp: Brightness.increaseBrightness()
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

        ScrollHint {
            reveal: barLeftSideMouseArea.hovered
            icon: Hyprsunset.gamma === 100 ? "light_mode" : "wb_twilight"
            tooltipText: Translation.tr("Scroll to change brightness")
            side: "left"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
    }


    Item {
        id: leftStopper
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            leftMargin: Math.ceil(Appearance.rounding.screenRounding / 2)
        }
        width: 1
    }

    Item {
        id: leftMaskRegion
        x: leftSection.x
        y: leftSection.y
        width: leftSection.width
        height: leftSection.height
        onXChanged: root.sectionGeometryChanged()
        onWidthChanged: root.sectionGeometryChanged()
    }

    RowLayout { // Left section
        id: leftSection
        property bool _shown: false
        opacity: _shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        transform: Translate {
            x: leftSection._shown ? 0 : -20
            Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        }
        Timer { running: true; interval: 10; onTriggered: leftSection._shown = true }
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: leftStopper.right
        }
        spacing: Config.options.bar.widgetSpacing

        Repeater {
            id: leftRepeater
            model: Config.options.bar.layouts.left
            delegate: BarComponent {
                list: Config.options.bar.layouts.left
                barSection: 0
            }
        }
    }

    Item { // Middle section
        id: middleSection
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height
        width: centerCenter.width + (middleLeftRepeater.count > 0 ? Config.options.bar.widgetSpacing : 0) + (middleRightRepeater.count > 0 ? Config.options.bar.widgetSpacing : 0)
        onXChanged: root.sectionGeometryChanged()
        onWidthChanged: root.sectionGeometryChanged()

        RowLayout {
            anchors.right: centerCenter.left
            anchors.rightMargin: Config.options.bar.widgetSpacing
            height: parent.height
            spacing: Config.options.bar.widgetSpacing
            Repeater {
                id: middleLeftRepeater
                model: root.leftList
                delegate: BarComponent {
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

        RowLayout { // center
            id: centerCenter
            anchors {
                top: parent.top
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }
            spacing: Config.options.bar.widgetSpacing
            Repeater {
                model: root.centerList
                delegate: BarComponent {
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

        RowLayout {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: centerCenter.right
                leftMargin: Config.options.bar.widgetSpacing
            }
            spacing: Config.options.bar.widgetSpacing
            Repeater {
                id: middleRightRepeater
                model: root.rightList
                delegate: BarComponent {
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

    }

    RowLayout { // Right section
        id: rightSection
        property bool _shown: false
        opacity: _shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        transform: Translate {
            x: rightSection._shown ? 0 : 20
            Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        }
        Timer { running: true; interval: 250; onTriggered: rightSection._shown = true }
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: rightStopper.left
            rightMargin: Math.ceil(Appearance.rounding.screenRounding / 2)
        }
        spacing: Config.options.bar.widgetSpacing

        Repeater {
            id: rightRepeater
            model: Config.options.bar.layouts.right
            delegate: BarComponent {
                list: Config.options.bar.layouts.right
                barSection: 2
            }
        }
    }


    Item {
        id: rightMaskRegion
        x: rightSection.x
        y: rightSection.y
        width: rightSection.width
        height: rightSection.height
        onXChanged: root.sectionGeometryChanged()
        onWidthChanged: root.sectionGeometryChanged()
    }

    Item {
        // middleSection's width only counts centerCenter; the non-centered
        // rows overflow it on both sides, so track childrenRect instead.
        id: middleMaskRegion
        x: middleSection.x + middleSection.childrenRect.x
        y: middleSection.y
        width: middleSection.childrenRect.width
        height: middleSection.height
        onXChanged: root.sectionGeometryChanged()
        onWidthChanged: root.sectionGeometryChanged()
    }

    Item {
        id: rightStopper
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        width: 1
    }

    FocusedScrollMouseArea { // Right side | scroll to change volume
        id: barRightSideMouseArea

        z: -1
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        width: parent.width / 2
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: Audio.decrementVolume();
        onScrollUp: Audio.incrementVolume();
        onMovedAway: GlobalStates.osdVolumeOpen = false;
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }

        ScrollHint {
            reveal: barRightSideMouseArea.hovered
            icon: "volume_up"
            tooltipText: Translation.tr("Scroll to change volume")
            side: "right"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
