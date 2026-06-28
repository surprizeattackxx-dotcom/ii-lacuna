import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(420 * Style.uiScaleRatio)
  preferredHeight: Math.round(480 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent

    ColumnLayout {
      x: Style.marginL
      y: Style.marginL
      width: parent.width - Style.margin2L
      spacing: 0

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: I18n.tr("panels.policies.title")
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

      // Tab bar
      NTabBar {
        id: tabBar
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM

        NTabButton { text: I18n.tr("panels.policies.translator"); icon: "language" }
        NTabButton { text: I18n.tr("panels.policies.assistant"); icon: "sparkles" }
        NTabButton { text: I18n.tr("panels.policies.info"); icon: "info-circle" }
      }

      // Stacked content
      StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: Style.marginM
        currentIndex: tabBar.currentIndex

        // --- Translator tab ---
        Item {
          ColumnLayout {
            anchors.fill: parent
            spacing: Style.marginM

            NBox {
              Layout.fillWidth: true
              implicitHeight: sourceLayout.implicitHeight + Style.marginM

              RowLayout {
                id: sourceLayout
                anchors.fill: parent
                anchors.margins: Style.marginS
                spacing: Style.marginS

                NTextInput {
                  id: sourceText
                  Layout.fillWidth: true
                  placeholderText: I18n.tr("panels.policies.translate-placeholder")
                  fontSize: Style.fontSizeM
                  showClearButton: true
                }

                NIconButton {
                  icon: "arrow-right"
                  baseSize: Style.baseWidgetSize
                  colorBg: Color.mPrimary
                  colorFg: Color.mOnPrimary
                  colorBgHover: Color.mPrimary
                  colorFgHover: Color.mOnPrimary
                  enabled: sourceText.text.trim().length > 0
                  tooltipText: I18n.tr("panels.policies.translate-from")
                  onClicked: {
                    transResult.text = I18n.tr("panels.policies.translating");
                    transProc.running = true;
                  }
                }
              }
            }

            StdioCollector {
              id: transCollector
              onStreamFinished: transResult.text = this.text
            }

            Process {
              id: transProc
              stdout: transCollector
              stderr: StdioCollector {}
              command: ["trans", "-brief", sourceText.text.trim()]
            }

            NScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              horizontalPolicy: ScrollBar.AlwaysOff
              verticalPolicy: ScrollBar.AsNeeded
              gradientColor: Color.mSurface

              NText {
                id: transResult
                width: parent.availableWidth
                pointSize: Style.fontSizeM
                color: Color.mOnSurface
                wrapMode: Text.WordWrap
                font.family: Settings.data.ui.fontFixed
                text: I18n.tr("panels.policies.translate-hint")
                topPadding: Style.marginS
              }
            }
          }
        }

        // --- Assistant tab (placeholder) ---
        Item {
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            NIcon {
              icon: "sparkles"
              pointSize: 48
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: I18n.tr("panels.policies.assistant-placeholder")
              pointSize: Style.fontSizeM
              color: Color.mOnSurfaceVariant
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }

        // --- Info tab ---
        Item {
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NBox {
              Layout.fillWidth: true
              implicitHeight: infoColumn.implicitHeight + Style.marginM

              ColumnLayout {
                id: infoColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                NText {
                  text: I18n.tr("panels.policies.system-info")
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                }

                PropertyRow { label: I18n.tr("common.os"); value: HostService.osPretty }
                PropertyRow { label: I18n.tr("common.hostname"); value: HostService.hostName }
                PropertyRow { label: I18n.tr("common.user"); value: HostService.displayName }
              }
            }
          }
        }
      }
    }
  }

  // Helper: label-value row
  component PropertyRow: RowLayout {
    property string label: ""
    property string value: ""

    spacing: Style.marginS
    Layout.fillWidth: true

    NText {
      text: parent.label + ":"
      pointSize: Style.fontSizeXS
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
      Layout.preferredWidth: 80
    }

    NText {
      text: parent.value
      pointSize: Style.fontSizeXS
      color: Color.mOnSurfaceVariant
      font.family: Settings.data.ui.fontFixed
      Layout.fillWidth: true
      elide: Text.ElideRight
    }
  }
}
