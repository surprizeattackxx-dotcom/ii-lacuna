import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.controlCenter

RowLayout {
    id: root
    spacing: 13

    // ---- Left pill: Network, Bluetooth, Dark mode ----
    CCBox {
        Layout.fillWidth: true
        Layout.preferredHeight: 52

        Row {
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: [
                    {
                        icon: Network.materialSymbol,
                        toggled: Network.connected,
                        tooltip: "Network",
                        action: () => Quickshell.execDetached("nm-connection-editor")
                    },
                    {
                        icon: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled",
                        toggled: BluetoothStatus.enabled,
                        tooltip: "Bluetooth",
                        action: () => BluetoothStatus.enabled = !BluetoothStatus.enabled
                    },
                    {
                        icon: "dark_mode",
                        toggled: Appearance.m3colors.darkTheme,
                        tooltip: "Dark mode",
                        action: () => { Appearance.m3colors.darkTheme = !Appearance.m3colors.darkTheme }
                    }
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: 40
                    height: 40
                    radius: width / 2
                    color: modelData.toggled ? Appearance.m3colors.m3secondaryContainer : "transparent"

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: modelData.icon
                        iconSize: 22
                        color: modelData.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurfaceVariant
                    }

                    MouseArea {
                        id: leftMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.action()
                    }

                    StyledToolTip {
                        extraVisibleCondition: leftMouseArea.containsMouse
                        text: modelData.tooltip
                    }
                }
            }
        }
    }

    // ---- Right pill: Notifications, Keep awake, Night light ----
    CCBox {
        Layout.fillWidth: true
        Layout.preferredHeight: 52

        Row {
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: [
                    {
                        icon: Notifications.silent ? "notifications_off" : "notifications",
                        toggled: !Notifications.silent,
                        tooltip: "Notifications",
                        action: () => Notifications.silent = !Notifications.silent
                    },
                    {
                        icon: Idle.inhibit ? "kettle" : "coffee",
                        toggled: Idle.inhibit,
                        tooltip: "Keep awake",
                        action: () => Idle.toggleInhibit()
                    },
                    {
                        icon: "routine",
                        toggled: Hyprsunset.temperatureActive,
                        tooltip: "Night light",
                        action: () => Hyprsunset.toggleTemperature()
                    }
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: 40
                    height: 40
                    radius: width / 2
                    color: modelData.toggled ? Appearance.m3colors.m3secondaryContainer : "transparent"

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: modelData.icon
                        iconSize: 22
                        color: modelData.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurfaceVariant
                    }

                    MouseArea {
                        id: rightMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.action()
                    }

                    StyledToolTip {
                        extraVisibleCondition: rightMouseArea.containsMouse
                        text: modelData.tooltip
                    }
                }
            }
        }
    }
}
