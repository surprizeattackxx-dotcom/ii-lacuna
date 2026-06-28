import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Hardware
import qs.Services.Location
import qs.Services.Media
import qs.Services.Networking
import qs.Services.Power
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  preferredHeight: Math.round(520 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent

    ColumnLayout {
      x: Style.marginL
      y: Style.marginL
      width: parent.width - Style.margin2L
      spacing: Style.marginM

      // Header: System info
      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NText {
            text: I18n.tr("panels.dashboard.title")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: root.close()
          }
        }
      }

      // Quick Toggles grid
      NBox {
        Layout.fillWidth: true
        implicitHeight: togglesGrid.implicitHeight + Style.margin2M

        GridLayout {
          id: togglesGrid
          anchors.fill: parent
          anchors.margins: Style.marginM
          columns: 4
          rowSpacing: Style.marginS
          columnSpacing: Style.marginS

          DashboardToggle {
            icon: "moon"
            label: I18n.tr("common.dark-mode")
            toggled: Settings.data.colorSchemes.darkMode
            onClicked: Settings.data.colorSchemes.darkMode = !Settings.data.colorSchemes.darkMode
            Layout.fillWidth: true
          }

          DashboardToggle {
            icon: "brightness-2"
            label: I18n.tr("common.night-light")
            toggled: Settings.data.nightLight.enabled
            onClicked: Settings.data.nightLight.enabled = !Settings.data.nightLight.enabled
            Layout.fillWidth: true
          }

          DashboardToggle {
            icon: "bluetooth"
            label: I18n.tr("common.bluetooth")
            toggled: BluetoothService.enabled
            onClicked: BluetoothService.setBluetoothEnabled(!BluetoothService.enabled)
            Layout.fillWidth: true
          }

          DashboardToggle {
            icon: "wifi"
            label: I18n.tr("common.wifi")
            toggled: NetworkService.wifiEnabled
            onClicked: NetworkService.wifiEnabled = !NetworkService.wifiEnabled
            Layout.fillWidth: true
          }

          DashboardToggle {
            icon: "microphone"
            label: I18n.tr("common.microphone")
            toggled: AudioService.inputMuted
            onClicked: AudioService.setInputMuted(!AudioService.inputMuted)
            Layout.fillWidth: true
          }

          DashboardToggle {
            icon: "coffee"
            label: I18n.tr("common.keep-awake")
            toggled: IdleInhibitorService.active
            onClicked: IdleInhibitorService.manualToggle()
            Layout.fillWidth: true
          }

          DashboardToggle {
            icon: "battery-eco"
            label: I18n.tr("common.power-profile")
            toggled: !PowerProfileService.isDefault()
            onClicked: PowerProfileService.cycleProfile()
            Layout.fillWidth: true
          }

          DashboardToggle {
            icon: "notification-off"
            label: I18n.tr("common.dnd")
            toggled: NotificationService.doNotDisturb
            onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
            Layout.fillWidth: true
          }
        }
      }

      // Quick sliders (Volume + Brightness)
      NBox {
        Layout.fillWidth: true
        implicitHeight: slidersColumn.implicitHeight + Style.margin2M

        ColumnLayout {
          id: slidersColumn
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          // Volume slider
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
              icon: AudioService.getOutputIcon()
              pointSize: Style.fontSizeXL
              color: Color.mOnSurface
            }

            NSlider {
              id: volumeSlider
              Layout.fillWidth: true
              from: 0
              to: Settings.data.audio.volumeOverdrive ? 1.5 : 1.0
              value: AudioService.volume
              stepSize: 0.01
              onMoved: AudioService.setVolume(value)
            }

            NText {
              text: Math.round(AudioService.volume * 100) + "%"
              pointSize: Style.fontSizeS
              family: Settings.data.ui.fontFixed
              color: Color.mOnSurface
              Layout.preferredWidth: 40
              horizontalAlignment: Text.AlignRight
            }
          }

          // Brightness slider
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
              icon: "brightness-up"
              pointSize: Style.fontSizeXL
              color: Color.mOnSurface
            }

            NSlider {
              id: brightnessSlider
              Layout.fillWidth: true
              from: 0
              to: BrightnessService.maxBrightness
              value: BrightnessService.brightness
              stepSize: 1
              onMoved: BrightnessService.setBrightness(value)
            }

            NText {
              text: BrightnessService.maxBrightness > 0 ? Math.round(BrightnessService.brightness / BrightnessService.maxBrightness * 100) + "%" : ""
              pointSize: Style.fontSizeS
              family: Settings.data.ui.fontFixed
              color: Color.mOnSurface
              Layout.preferredWidth: 40
              horizontalAlignment: Text.AlignRight
            }
          }
        }
      }

      // Recent notifications
      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Math.min(notifScroll.implicitHeight + Style.margin2M, 200)

        NText {
          x: Style.marginM
          y: Style.marginM
          text: I18n.tr("panels.dashboard.notifications")
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }

        NScrollView {
          id: notifScroll
          anchors.fill: parent
          anchors.margins: Style.marginM
          anchors.topMargin: Style.marginXL + Style.marginM
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          contentWidth: availableWidth
          gradientColor: Color.mSurface

          ColumnLayout {
            width: notifScroll.availableWidth
            spacing: Style.marginS

            Repeater {
              model: NotificationService.popupModel

              Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: notifRow.implicitHeight + Style.marginM
                radius: Style.radiusS
                color: Color.mSurfaceVariant
                border.color: Color.mOutline
                border.width: Style.borderXS

                RowLayout {
                  id: notifRow
                  x: Style.marginS
                  y: Style.marginS
                  width: parent.width - Style.marginS * 2
                  spacing: Style.marginS

                  NIcon {
                    icon: "notification"
                    pointSize: Style.fontSizeL
                    color: Color.mOnSurface
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    NText {
                      text: modelData.summary || ""
                      pointSize: Style.fontSizeXS
                      font.weight: Style.fontWeightBold
                      color: Color.mOnSurface
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    NText {
                      text: modelData.body || ""
                      pointSize: Style.fontSizeXXS
                      color: Color.mOnSurfaceVariant
                      elide: Text.ElideRight
                      maximumLineCount: 2
                      wrapMode: Text.WordWrap
                      Layout.fillWidth: true
                    }
                  }
                }
              }
            }

            NText {
              visible: NotificationService.popupModel.count === 0
              text: I18n.tr("panels.dashboard.no-notifications")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
              Layout.topMargin: Style.marginM
            }
          }
        }
      }
    }
  }

  // Dashboard toggle button component
  component DashboardToggle: Item {
    id: toggleRoot
    property string icon: ""
    property string label: ""
    property bool toggled: false
    signal clicked()

    implicitHeight: toggleBtn.implicitHeight + 8
    implicitWidth: toggleBtn.implicitWidth + 8

    NIconButton {
      id: toggleBtn
      anchors.centerIn: parent
      icon: toggleRoot.icon
      baseSize: Style.baseWidgetSize * 0.85
      applyUiScale: false
      customRadius: Style.radiusM
      colorBg: toggleRoot.toggled ? Color.mPrimary : Color.mSurfaceVariant
      colorFg: toggleRoot.toggled ? Color.mOnPrimary : Color.mOnSurface
      colorBgHover: toggleRoot.toggled ? Color.mPrimary : Color.mHover
      colorFgHover: toggleRoot.toggled ? Color.mOnPrimary : Color.mOnHover
      colorBorder: toggleRoot.toggled ? Color.mPrimary : Color.mOutline
      colorBorderHover: toggleRoot.toggled ? Color.mPrimary : Color.mOnSurface
      tooltipText: toggleRoot.label
      onClicked: toggleRoot.clicked()
    }
  }
}
