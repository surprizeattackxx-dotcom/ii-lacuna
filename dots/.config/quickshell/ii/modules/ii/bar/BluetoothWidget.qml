import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
  id: root
  property bool vertical: false

  implicitWidth: row.implicitWidth + 8
  implicitHeight: Appearance.sizes.barHeight

  readonly property string firstDevice: BluetoothStatus.connectedDevices.length > 0 ? BluetoothStatus.connectedDevices[0].name || BluetoothStatus.connectedDevices[0].address : ""

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 2

    MaterialSymbol {
      iconSize: 18
      text: !BluetoothStatus.enabled ? "bluetooth_disabled" : BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
      color: BluetoothStatus.connected ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
    }

    StyledText {
      text: root.firstDevice
      font.pixelSize: Appearance.font.pixelSize.small
      color: Appearance.m3colors.m3onSurfaceVariant
      visible: !root.vertical && root.firstDevice.length > 0
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["bash", "-c", "bluetoothctl power toggle"])
  }
}
