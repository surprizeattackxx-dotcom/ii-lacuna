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

  readonly property string profileIcon: PowerProfiles.activeProfile === "performance" ? "bolt"
    : PowerProfiles.activeProfile === "power-saver" ? "eco"
    : PowerProfiles.activeProfile === "balanced" ? "balance"
    : "power_settings_new"

  visible: PowerProfiles.available

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 2

    MaterialSymbol {
      iconSize: 18
      text: root.profileIcon
      color: PowerProfiles.activeProfile === "performance"
        ? Appearance.m3colors.m3primary
        : Appearance.m3colors.m3onSurfaceVariant
    }

    StyledText {
      text: PowerProfiles.activeProfile
      font.pixelSize: Appearance.font.pixelSize.small
      color: Appearance.m3colors.m3onSurfaceVariant
      visible: !root.vertical && PowerProfiles.activeProfile.length > 0
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    visible: PowerProfiles.profiles.length > 1
    onClicked: {
      var profiles = PowerProfiles.profiles
      var idx = profiles.indexOf(PowerProfiles.activeProfile)
      var next = (idx + 1) % profiles.length
      PowerProfiles.setProfile(profiles[next])
    }
  }
}
