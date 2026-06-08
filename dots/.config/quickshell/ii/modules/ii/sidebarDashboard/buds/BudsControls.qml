import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root
    property bool expanded: false

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 16
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    clip: true

    Behavior on implicitHeight {
        NumberAnimation { duration: 250; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.emphasizedDecel }
    }

    onExpandedChanged: if (expanded) Buds.refresh()

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
        spacing: 10

        // --- Header (tap to expand) ---
        RippleButton {
            id: header
            Layout.fillWidth: true
            implicitHeight: 48
            buttonRadius: Appearance.rounding.small
            releaseAction: () => root.expanded = !root.expanded
            contentItem: RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 10
                Rectangle {
                    width: 36; height: 36; radius: 11
                    color: Appearance.colors.colPrimaryContainer
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "earbuds"; iconSize: 22
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2
                    StyledText {
                        text: Buds.deviceName
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: Buds.loading ? Translation.tr("Syncing…")
                            : Buds.parsed ? `${Buds.batteryLeft}%  •  ${Buds.batteryRight}%` + (Buds.batteryCase > 0 ? `  •  ${Translation.tr("Case")} ${Buds.batteryCase}%` : "")
                            : Translation.tr("Tap to load")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
                MaterialSymbol {
                    text: "expand_more"
                    iconSize: 24
                    color: Appearance.colors.colOnLayer1
                    rotation: root.expanded ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }
        }

        // --- Controls ---
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: -4
            Layout.rightMargin: -4
            spacing: 12
            visible: root.expanded
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Noise control
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
                        implicitHeight: 54
                        toggled: Buds.noise === modelData.id
                        buttonRadius: nbtn.toggled ? Appearance.rounding.normal : Appearance.rounding.small
                        colBackground: Appearance.colors.colSurfaceContainerHighest
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        releaseAction: () => Buds.setNoise(modelData.id)
                        contentItem: Item {
                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                MaterialSymbol {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: nbtn.modelData.icon
                                    iconSize: 22
                                    fill: nbtn.toggled ? 1 : 0
                                    color: nbtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                                }
                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: nbtn.modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: nbtn.toggled ? Font.DemiBold : Font.Normal
                                    color: nbtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                }
                            }
                        }
                    }
                }
            }

            // Equalizer
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                StyledText {
                    text: Translation.tr("Equalizer")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 5
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
                            implicitHeight: 32
                            implicitWidth: eqLabel.implicitWidth + 26
                            toggled: Buds.equalizer === modelData.id
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colSurfaceContainerHighest
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            releaseAction: () => Buds.setEqualizer(modelData.id)
                            contentItem: StyledText {
                                id: eqLabel
                                anchors.centerIn: parent
                                text: ebtn.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: ebtn.toggled ? Font.DemiBold : Font.Normal
                                color: ebtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }

            // Touch lock
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Lock touch controls")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1
                }
                StyledSwitch {
                    checked: Buds.touchLocked
                    onToggled: Buds.setLock(checked)
                }
            }

            // Find earbuds
            RippleButton {
                id: findBtn
                Layout.fillWidth: true
                implicitHeight: 38
                buttonRadius: Appearance.rounding.small
                toggled: Buds.finding
                releaseAction: () => Buds.toggleFind()
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol {
                        text: Buds.finding ? "notifications_off" : "notifications_active"
                        iconSize: 18
                        color: findBtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Buds.finding ? Translation.tr("Stop ringing") : Translation.tr("Find earbuds")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: findBtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }
}
