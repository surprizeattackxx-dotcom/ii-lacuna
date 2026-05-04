pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

PanelWindow {
    Process {
        id: themeApplyProc
        onExited: (code, status) => { MaterialThemeLoader.reapplyTheme() }
    }

    Timer {
        id: themeReloadTimer
        interval: 1000
        repeat: false
        onTriggered: MaterialThemeLoader.reapplyTheme()
    }

    id: root
    visible: GlobalStates.barAppletsOpen
    color: "transparent"

    WlrLayershell.namespace: "quickshell:bar-applets"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    onVisibleChanged: {
        if (visible) {
            panel._shown = false
            Qt.callLater(() => { panel._shown = true })
        }
    }

    property string _leftSnap: JSON.stringify(Config.options.bar.layouts.left)
    property string _centerSnap: JSON.stringify(Config.options.bar.layouts.center)
    property string _rightSnap: JSON.stringify(Config.options.bar.layouts.right)
    property string _layoutSnapshot: _leftSnap + _centerSnap + _rightSnap

    property var availableComponents: {
        _layoutSnapshot
        const usedIds = []
        for (const s of ["left", "center", "right"]) {
            for (const item of (Config.options.bar.layouts[s] || []))
                usedIds.push(item.id)
        }
        return BarComponentRegistry.allComponents.filter(c => !usedIds.includes(c.id))
    }

    readonly property var themeNames: ["Mocha", "Glass", "Matugen", "Gruvbox", "Apple", "Nord"]
    property string activeTheme: "Matugen"

    function moveUp(section, index) {
        if (index === 0) return
        let arr = Config.options.bar.layouts[section].slice()
        let tmp = arr[index - 1]; arr[index - 1] = arr[index]; arr[index] = tmp
        Config.options.bar.layouts[section] = arr
    }

    function moveDown(section, index) {
        let arr = Config.options.bar.layouts[section].slice()
        if (index >= arr.length - 1) return
        let tmp = arr[index + 1]; arr[index + 1] = arr[index]; arr[index] = tmp
        Config.options.bar.layouts[section] = arr
    }

    function moveToSection(fromSection, itemId, toSection) {
        let fromArr = Config.options.bar.layouts[fromSection].slice()
        const idx = fromArr.findIndex(x => x.id === itemId)
        if (idx === -1) return
        const item = fromArr.splice(idx, 1)[0]
        Config.options.bar.layouts[fromSection] = fromArr
        let toArr = Config.options.bar.layouts[toSection].slice()
        toArr.push(item)
        Config.options.bar.layouts[toSection] = toArr
    }

    function addToSection(compId, section) {
        let arr = Config.options.bar.layouts[section].slice()
        arr.push({ id: compId, visible: true })
        Config.options.bar.layouts[section] = arr
    }

    function removeComponent(compId) {
        for (const section of ["left", "center", "right"]) {
            let arr = Config.options.bar.layouts[section].slice()
            const idx = arr.findIndex(x => x.id === compId)
            if (idx !== -1) {
                arr.splice(idx, 1)
                Config.options.bar.layouts[section] = arr
                return
            }
        }
    }

    function getTitle(compId) {
        const c = BarComponentRegistry.getComponent(compId)
        return c ? c.title : compId
    }

    function getIcon(compId) {
        const c = BarComponentRegistry.getComponent(compId)
        return c ? c.icon : "widgets"
    }

    function applyTheme(themeName) {
        if (themeName === "Matugen") {
            themeApplyProc.command = ["bash", Directories.wallpaperSwitchScriptPath, "--noswitch", "--mode", "dark"];
        } else {
            const path = Directories.defaultThemes + "/" + themeName.toLowerCase() + ".json";
            themeApplyProc.command = ["bash", Directories.applyCustomThemeScriptPath, path];
        }
        themeApplyProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: GlobalStates.barAppletsOpen = false
    }

    Rectangle {
        id: panel
        property bool _shown: false

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: Appearance.sizes.barHeight + 8
        }

        width: Math.min(760, parent.width - 32)
        height: Math.min(
            panelFlick.contentHeight + 32,
            parent.height - anchors.topMargin - 20
        )

        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.large
        border.width: 1
        border.color: Qt.rgba(
            Appearance.m3colors.m3outlineVariant.r,
            Appearance.m3colors.m3outlineVariant.g,
            Appearance.m3colors.m3outlineVariant.b, 0.6)

        opacity: _shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: panel._shown ? 0 : -10
            Behavior on y {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Flickable {
            id: panelFlick
            anchors { fill: parent; margins: 16 }
            contentHeight: panelCol.implicitHeight
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: panelCol
                width: panelFlick.width
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Bar Applets"
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: doneBtnLbl.implicitWidth + 24
                        height: 30
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary

                        Text {
                            id: doneBtnLbl
                            anchors.centerIn: parent
                            text: "Done"
                            color: Appearance.m3colors.m3onPrimary
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: GlobalStates.barAppletsOpen = false
                        }
                    }
                }

                Text {
                    text: "THEME"
                    color: Qt.rgba(Appearance.colors.colOnLayer0.r,
                                   Appearance.colors.colOnLayer0.g,
                                   Appearance.colors.colOnLayer0.b, 0.45)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.themeNames
                        delegate: Rectangle {
                            id: themeChip
                            required property string modelData
                            readonly property bool isActive: root.activeTheme === modelData

                            height: 30
                            width: themeChipText.implicitWidth + 22
                            radius: Appearance.rounding.full
                            color: isActive
                                ? Appearance.colors.colPrimary
                                : Appearance.m3colors.m3surfaceContainerHigh
                            border.width: 1
                            border.color: isActive ? "transparent"
                                : Qt.rgba(Appearance.m3colors.m3outlineVariant.r,
                                          Appearance.m3colors.m3outlineVariant.g,
                                          Appearance.m3colors.m3outlineVariant.b, 0.5)
                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }

                            Text {
                                id: themeChipText
                                anchors.centerIn: parent
                                text: themeChip.modelData
                                color: themeChip.isActive ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: themeChip.isActive ? Font.Medium : Font.Normal
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.activeTheme = themeChip.modelData; root.applyTheme(themeChip.modelData) }
                            }
                        }
                    }
                }

                Text {
                    text: "LAYOUT"
                    color: Qt.rgba(Appearance.colors.colOnLayer0.r,
                                   Appearance.colors.colOnLayer0.g,
                                   Appearance.colors.colOnLayer0.b, 0.45)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { key: "left",   label: "Left" },
                            { key: "center", label: "Center" },
                            { key: "right",  label: "Right" }
                        ]
                        delegate: Rectangle {
                            id: secCard
                            required property var modelData
                            required property int index

                            property var items: {
                                root._layoutSnapshot
                                return Config.options.bar.layouts[secCard.modelData.key] || []
                            }

                            Layout.fillWidth: true
                            implicitHeight: secCardCol.implicitHeight + 16
                            radius: Appearance.rounding.normal
                            color: Appearance.m3colors.m3surfaceContainer
                            border.width: 1
                            border.color: Qt.rgba(
                                Appearance.m3colors.m3outlineVariant.r,
                                Appearance.m3colors.m3outlineVariant.g,
                                Appearance.m3colors.m3outlineVariant.b, 0.3)

                            ColumnLayout {
                                id: secCardCol
                                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                                spacing: 4

                                Text {
                                    text: secCard.modelData.label
                                    color: Appearance.colors.colPrimary
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    bottomPadding: 2
                                }

                                Repeater {
                                    model: secCard.items
                                    delegate: Rectangle {
                                        id: appletItem
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        height: 28
                                        radius: Appearance.rounding.normal
                                        color: Qt.rgba(
                                            Appearance.m3colors.m3surfaceContainerHighest.r,
                                            Appearance.m3colors.m3surfaceContainerHighest.g,
                                            Appearance.m3colors.m3surfaceContainerHighest.b, 0.8)

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                                            spacing: 2

                                            MaterialSymbol {
                                                text: root.getIcon(appletItem.modelData.id)
                                                iconSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colOnLayer1
                                            }

                                            Text {
                                                text: root.getTitle(appletItem.modelData.id)
                                                color: Appearance.colors.colOnLayer1
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Rectangle {
                                                width: 18; height: 18; radius: 4
                                                visible: appletItem.index > 0
                                                color: upMa.containsMouse
                                                    ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.25)
                                                    : Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.1)
                                                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                                                Text { anchors.centerIn: parent; text: "↑"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Bold; color: Appearance.colors.colPrimary }
                                                MouseArea { id: upMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.moveUp(secCard.modelData.key, appletItem.index) }
                                            }

                                            Rectangle {
                                                width: 18; height: 18; radius: 4
                                                visible: appletItem.index < secCard.items.length - 1
                                                color: downMa.containsMouse
                                                    ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.25)
                                                    : Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.1)
                                                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                                                Text { anchors.centerIn: parent; text: "↓"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Bold; color: Appearance.colors.colPrimary }
                                                MouseArea { id: downMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.moveDown(secCard.modelData.key, appletItem.index) }
                                            }

                                            Rectangle {
                                                width: 18; height: 18; radius: 4
                                                visible: secCard.index > 0
                                                color: prevSecMa.containsMouse
                                                    ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.25)
                                                    : Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.1)
                                                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                                                Text { anchors.centerIn: parent; text: "←"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Bold; color: Appearance.colors.colPrimary }
                                                MouseArea {
                                                    id: prevSecMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.moveToSection(secCard.modelData.key, appletItem.modelData.id, ["left", "center", "right"][secCard.index - 1])
                                                }
                                            }

                                            Rectangle {
                                                width: 18; height: 18; radius: 4
                                                visible: secCard.index < 2
                                                color: nextSecMa.containsMouse
                                                    ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.25)
                                                    : Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.1)
                                                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                                                Text { anchors.centerIn: parent; text: "→"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Bold; color: Appearance.colors.colPrimary }
                                                MouseArea {
                                                    id: nextSecMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.moveToSection(secCard.modelData.key, appletItem.modelData.id, ["left", "center", "right"][secCard.index + 1])
                                                }
                                            }

                                            Rectangle {
                                                width: 18; height: 18; radius: 9
                                                color: removeMa.containsMouse
                                                    ? Qt.rgba(Appearance.colors.colError.r, Appearance.colors.colError.g, Appearance.colors.colError.b, 0.3)
                                                    : Qt.rgba(Appearance.colors.colError.r, Appearance.colors.colError.g, Appearance.colors.colError.b, 0.12)
                                                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                                                Text { anchors.centerIn: parent; text: "×"; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Bold; color: Appearance.colors.colError }
                                                MouseArea { id: removeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.removeComponent(appletItem.modelData.id) }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: secCard.items.length === 0
                                    text: "Empty"
                                    color: Qt.rgba(Appearance.colors.colOnLayer0.r,
                                                   Appearance.colors.colOnLayer0.g,
                                                   Appearance.colors.colOnLayer0.b, 0.3)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.italic: true
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    topPadding: 4; bottomPadding: 4
                                }

                                Item { height: 2 }
                            }
                        }
                    }
                }

                Text {
                    text: "AVAILABLE APPLETS"
                    color: Qt.rgba(Appearance.colors.colOnLayer0.r,
                                   Appearance.colors.colOnLayer0.g,
                                   Appearance.colors.colOnLayer0.b, 0.45)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.availableComponents
                        delegate: Rectangle {
                            id: availChip
                            required property var modelData

                            height: 32
                            width: availChipRow.implicitWidth + 20
                            radius: Appearance.rounding.full
                            color: Appearance.m3colors.m3surfaceContainer
                            border.width: 1
                            border.color: Qt.rgba(
                                Appearance.m3colors.m3outlineVariant.r,
                                Appearance.m3colors.m3outlineVariant.g,
                                Appearance.m3colors.m3outlineVariant.b, 0.4)

                            RowLayout {
                                id: availChipRow
                                anchors.centerIn: parent
                                spacing: 5

                                MaterialSymbol {
                                    text: availChip.modelData.icon
                                    iconSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                }

                                Text {
                                    text: availChip.modelData.title
                                    color: Appearance.colors.colOnLayer1
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }

                                Row {
                                    spacing: 2

                                    Repeater {
                                        model: [
                                            { lbl: "L", sec: "left" },
                                            { lbl: "C", sec: "center" },
                                            { lbl: "R", sec: "right" }
                                        ]
                                        delegate: Rectangle {
                                            id: secAddBtn
                                            required property var modelData
                                            width: 18; height: 18; radius: 4
                                            color: secAddMa.containsMouse
                                                ? Appearance.colors.colPrimary
                                                : Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.15)
                                            Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                                            Text {
                                                anchors.centerIn: parent
                                                text: secAddBtn.modelData.lbl
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                                color: secAddMa.containsMouse ? Appearance.m3colors.m3onPrimary : Appearance.colors.colPrimary
                                            }

                                            MouseArea {
                                                id: secAddMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.addToSection(availChip.modelData.id, secAddBtn.modelData.sec)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.availableComponents.length === 0
                        text: "All applets are on the bar"
                        color: Qt.rgba(Appearance.colors.colOnLayer0.r,
                                       Appearance.colors.colOnLayer0.g,
                                       Appearance.colors.colOnLayer0.b, 0.35)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.italic: true
                    }
                }

                Item { height: 4 }
            }
        }
    }
}
