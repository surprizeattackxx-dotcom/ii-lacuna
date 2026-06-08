import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
    id: scope

    property bool open: false

    function show() { if (Buds.available) { Buds.refresh(); open = true; } }
    function hide() { open = false; }
    function toggle() { open ? hide() : show(); }

    IpcHandler {
        target: "budsMenu"
        function open(): void { scope.show() }
        function close(): void { scope.hide() }
        function toggle(): void { scope.toggle() }
    }

    GlobalShortcut {
        name: "budsMenuToggle"
        description: "Toggle Galaxy Buds menu"
        onPressed: scope.toggle()
    }

    PanelWindow {
        id: win
        visible: scope.open || card.scale > 0.01
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-budsmenu"
        WlrLayershell.keyboardFocus: scope.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        focusable: scope.open

        Rectangle { // scrim
            anchors.fill: parent
            color: Appearance.colors.colScrim
            opacity: scope.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: scope.hide() }
        }

        FocusScope {
            anchors.fill: parent
            focus: scope.open
            Keys.onPressed: event => { if (event.key === Qt.Key_Escape) { scope.hide(); event.accepted = true; } }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: 380
                implicitHeight: content.implicitHeight + 48
                radius: Appearance.rounding.large
                color: Appearance.m3colors.m3surfaceContainerHigh

                scale: scope.open ? 1 : 0.85
                opacity: scope.open ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
                Behavior on opacity { NumberAnimation { duration: 180 } }

                MouseArea { anchors.fill: parent } // swallow clicks

                ColumnLayout {
                    id: content
                    anchors { fill: parent; margins: 24 }
                    spacing: 20

                    // --- Header ---
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            width: 44; height: 44; radius: 14
                            color: Appearance.colors.colPrimaryContainer
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "earbuds"
                                iconSize: 26
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                text: Buds.deviceName
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            StyledText {
                                text: Buds.loading ? Translation.tr("Syncing…")
                                    : Buds.parsed ? Translation.tr("Connected")
                                    : Translation.tr("No data")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.m3colors.m3onSurfaceVariant
                            }
                        }
                        RippleButton {
                            implicitWidth: 36; implicitHeight: 36
                            buttonRadius: 18
                            releaseAction: () => scope.hide()
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"; iconSize: 22
                                color: Appearance.colors.colOnSurface
                            }
                        }
                    }

                    // --- Battery ---
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Repeater {
                            model: [
                                { label: Translation.tr("Left"),  val: Buds.batteryLeft,  show: true },
                                { label: Translation.tr("Case"),  val: Buds.batteryCase,  show: Buds.batteryCase > 0 },
                                { label: Translation.tr("Right"), val: Buds.batteryRight, show: true }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                visible: modelData.show
                                Layout.fillWidth: true
                                implicitHeight: 76
                                radius: Appearance.rounding.normal
                                color: Appearance.colors.colSurfaceContainerHighest
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    CircularProgress {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitSize: 38
                                        lineWidth: 4
                                        value: Math.max(0, modelData.val) / 100
                                        colPrimary: modelData.val <= 15 ? Appearance.m3colors.m3error : Appearance.colors.colPrimary
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: modelData.val > 0 ? modelData.val : "–"
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnSurface
                                        }
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.label
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.m3colors.m3onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }

                    // --- Noise control ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        StyledText {
                            text: Translation.tr("Noise control")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnSurface
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [
                                    { id: "off",     icon: "do_not_disturb_on", label: Translation.tr("Off") },
                                    { id: "anc",     icon: "noise_control_on",  label: Translation.tr("ANC") },
                                    { id: "ambient", icon: "noise_aware",       label: Translation.tr("Ambient") }
                                ]
                                delegate: RippleButton {
                                    id: nbtn
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 56
                                    toggled: Buds.noise === modelData.id
                                    buttonRadius: Appearance.rounding.normal
                                    releaseAction: () => Buds.setNoise(modelData.id)
                                    contentItem: ColumnLayout {
                                        spacing: 2
                                        MaterialSymbol {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: nbtn.modelData.icon; iconSize: 22
                                            color: nbtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: nbtn.modelData.label
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: nbtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- Equalizer ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        StyledText {
                            text: Translation.tr("Equalizer")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnSurface
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [
                                    { id: "normal",  label: Translation.tr("Normal") },
                                    { id: "bass",    label: Translation.tr("Bass") },
                                    { id: "soft",    label: Translation.tr("Soft") },
                                    { id: "dynamic", label: Translation.tr("Dynamic") },
                                    { id: "clear",   label: Translation.tr("Clear") },
                                    { id: "treble",  label: Translation.tr("Treble") }
                                ]
                                delegate: RippleButton {
                                    id: ebtn
                                    required property var modelData
                                    implicitHeight: 36
                                    implicitWidth: eqLabel.implicitWidth + 28
                                    toggled: Buds.equalizer === modelData.id
                                    buttonRadius: Appearance.rounding.full
                                    releaseAction: () => Buds.setEqualizer(modelData.id)
                                    contentItem: StyledText {
                                        id: eqLabel
                                        anchors.centerIn: parent
                                        text: ebtn.modelData.label
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: ebtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                                    }
                                }
                            }
                        }
                    }

                    // --- Touch controls lock ---
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colSurfaceContainerHighest
                        RowLayout {
                            anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Lock touch controls")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSurface
                            }
                            StyledSwitch {
                                checked: Buds.touchLocked
                                onToggled: Buds.setLock(checked)
                            }
                        }
                    }

                    // --- Find earbuds ---
                    RippleButton {
                        id: findBtn
                        Layout.fillWidth: true
                        implicitHeight: 44
                        buttonRadius: Appearance.rounding.normal
                        toggled: Buds.finding
                        releaseAction: () => Buds.toggleFind()
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            MaterialSymbol {
                                text: Buds.finding ? "notifications_off" : "notifications_active"
                                iconSize: 20
                                color: findBtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                            }
                            StyledText {
                                text: Buds.finding ? Translation.tr("Stop ringing") : Translation.tr("Find earbuds")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: findBtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                            }
                        }
                    }
                }
            }
        }
    }
}
