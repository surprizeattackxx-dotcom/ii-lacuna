import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(520 * Style.uiScaleRatio)
  preferredHeight: Math.round(600 * Style.uiScaleRatio)

  // Poll hyprctl for monitor + device info
  property var monitorData: []
  property var deviceData: ({})
  property string hyprlandVersion: ""

  Component.onCompleted: {
    refreshHyprctlData();
  }

  function refreshHyprctlData() {
    monitorsProcess.running = true;
    devicesProcess.running = true;
    versionProcess.running = true;
  }

  // --- hyprctl processes ---

  Process {
    id: monitorsProcess
    running: false
    command: ["hyprctl", "monitors", "-j"]
    property string buf: ""
    stdout: SplitParser { onRead: line: monitorsProcess.buf += line }
    onExited: {
      try { monitorData = JSON.parse(buf); } catch(e) {}
      buf = "";
    }
  }

  Process {
    id: devicesProcess
    running: false
    command: ["hyprctl", "devices", "-j"]
    property string buf: ""
    stdout: SplitParser { onRead: line: devicesProcess.buf += line }
    onExited: {
      try { deviceData = JSON.parse(buf); } catch(e) {}
      buf = "";
    }
  }

  Process {
    id: versionProcess
    running: false
    command: ["hyprctl", "version", "-j"]
    property string buf: ""
    stdout: SplitParser { onRead: line: versionProcess.buf += line }
    onExited: {
      try {
        var d = JSON.parse(buf);
        hyprlandVersion = d.version || d["branch"] || "";
      } catch(e) {}
      buf = "";
    }
  }

  // Refresh every 2 seconds while open
  Timer {
    running: root.isPanelOpen
    repeat: true
    interval: 2000
    onTriggered: refreshHyprctlData()
  }

  panelContent: Item {
    id: panelContent
    property real contentPreferredHeight: mainColumn.implicitHeight + Style.margin2L

    ColumnLayout {
      id: mainColumn
      x: Style.marginL
      y: Style.marginL
      width: parent.width - Style.margin2L
      spacing: Style.marginM

      // ── Header ──
      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "layout-dashboard"
            pointSize: Style.fontSizeXXL
            color: Color.mPrimary
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            NText {
              text: "Hyprland IPC"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }

            NText {
              visible: hyprlandVersion !== ""
              text: hyprlandVersion
              pointSize: Style.fontSizeXXS
              color: Color.mOnSurfaceVariant
              font.family: Settings.data.ui.fontFixed
            }
          }

          NIconButton {
            icon: "refresh"
            tooltipText: "Refresh"
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: refreshHyprctlData()
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: root.close()
          }
        }
      }

      // ── Workspace Map ──
      NBox {
        Layout.fillWidth: true
        implicitHeight: wsMapColumn.implicitHeight + Style.margin2M

        ColumnLayout {
          id: wsMapColumn
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText {
            text: "Workspaces"
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }

          // Workspace map: each workspace is a mini preview
          Flow {
            Layout.fillWidth: true
            spacing: Style.marginS

            Repeater {
              model: CompositorService.workspaces

              Rectangle {
                required property var modelData
                width: 100
                height: 70
                radius: Style.radiusS
                color: modelData.isFocused ? Qt.alpha(Color.mPrimary, 0.15) : Color.mSurfaceVariant
                border.color: modelData.isFocused ? Color.mPrimary : Color.mOutline
                border.width: modelData.isFocused ? 2 : Style.borderXS

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: Style.marginXS
                  spacing: 2

                  // Workspace header
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                      width: 6; height: 6; radius: 3
                      color: modelData.isFocused ? Color.mPrimary
                           : modelData.isOccupied ? Color.mSecondary
                           : Color.mOutline
                    }

                    NText {
                      text: modelData.name || "#" + modelData.id
                      pointSize: Style.fontSizeXXS
                      font.weight: modelData.isFocused ? Style.fontWeightBold : Style.fontWeightNormal
                      color: modelData.isFocused ? Color.mPrimary : Color.mOnSurface
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }

                  // Window rectangles in this workspace
                  Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Repeater {
                      model: {
                        var wins = [];
                        for (var i = 0; i < CompositorService.windows.count; i++) {
                          var w = CompositorService.windows.get(i);
                          if (w && w.workspaceId === modelData.id) {
                            wins.push(w);
                          }
                        }
                        return wins;
                      }

                      Rectangle {
                        required property var modelData
                        property real mapScale: 0.06

                        x: {
                          // Map relative to monitor
                          var mon = root.monitorData.length > 0 ? root.monitorData[0] : null;
                          var monW = mon ? mon.width : 1920;
                          return Math.max(0, (modelData.x || 0) * mapScale);
                        }
                        y: {
                          var mon = root.monitorData.length > 0 ? root.monitorData[0] : null;
                          var monH = mon ? mon.height : 1080;
                          return Math.max(0, (modelData.y || 0) * mapScale);
                        }
                        width: {
                          var mon = root.monitorData.length > 0 ? root.monitorData[0] : null;
                          var monW = mon ? mon.width : 1920;
                          return Math.max(8, monW * mapScale * 0.45);
                        }
                        height: {
                          var mon = root.monitorData.length > 0 ? root.monitorData[0] : null;
                          var monH = mon ? mon.height : 1080;
                          return Math.max(6, monH * mapScale * 0.35);
                        }
                        radius: 3
                        color: modelData.isFocused ? Qt.alpha(Color.mPrimary, 0.5) : Qt.alpha(Color.mSecondary, 0.3)
                        border.color: modelData.isFocused ? Color.mPrimary : Color.mOutline
                        border.width: modelData.isFocused ? 1 : 0

                        NText {
                          anchors.centerIn: parent
                          text: modelData.appId || "?"
                          pointSize: 6
                          color: Color.mOnSurface
                          elide: Text.ElideRight
                          width: parent.width - 4
                          horizontalAlignment: Text.AlignHCenter
                        }
                      }
                    }

                    NText {
                      anchors.centerIn: parent
                      visible: {
                        var count = 0;
                        for (var i = 0; i < CompositorService.windows.count; i++) {
                          var w = CompositorService.windows.get(i);
                          if (w && w.workspaceId === modelData.id) count++;
                        }
                        return count === 0;
                      }
                      text: "empty"
                      pointSize: Style.fontSizeXXS
                      color: Color.mOnSurfaceVariant
                      opacity: 0.5
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ── Window Tree ──
      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: Math.min(windowTreeScroll.implicitHeight + Style.margin2M, 280 * Style.uiScaleRatio)

        NScrollView {
          id: windowTreeScroll
          anchors.fill: parent
          anchors.margins: Style.marginM
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          contentWidth: availableWidth
          gradientColor: Color.mSurface

          ColumnLayout {
            width: windowTreeScroll.availableWidth
            spacing: Style.marginXS

            NText {
              text: "Windows (" + CompositorService.windows.count + ")"
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.bottomMargin: Style.marginXS
            }

            Repeater {
              model: CompositorService.windows

              Rectangle {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: windowRow.implicitHeight + Style.marginM
                radius: Style.radiusS
                color: modelData.isFocused ? Qt.alpha(Color.mPrimary, 0.1) : Color.mSurfaceVariant
                border.color: modelData.isFocused ? Color.mPrimary : Color.mOutline
                border.width: modelData.isFocused ? 1 : Style.borderXS

                RowLayout {
                  id: windowRow
                  x: Style.marginS
                  y: Style.marginS / 2
                  width: parent.width - Style.marginS * 2
                  spacing: Style.marginS

                  // Focus indicator
                  Rectangle {
                    width: 4
                    height: parent.height
                    radius: 2
                    color: modelData.isFocused ? Color.mPrimary : "transparent"
                  }

                  // App icon placeholder
                  NIcon {
                    icon: "app-window"
                    pointSize: Style.fontSizeM
                    color: modelData.isFocused ? Color.mPrimary : Color.mOnSurfaceVariant
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    NText {
                      text: modelData.appId || "unknown"
                      pointSize: Style.fontSizeXS
                      font.weight: Style.fontWeightBold
                      color: modelData.isFocused ? Color.mPrimary : Color.mOnSurface
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    NText {
                      text: modelData.title || ""
                      pointSize: Style.fontSizeXXS
                      color: Color.mOnSurfaceVariant
                      elide: Text.ElideRight
                      maximumLineCount: 1
                      Layout.fillWidth: true
                    }
                  }

                  // Workspace badge
                  Rectangle {
                    implicitWidth: wsLabel.implicitWidth + Style.marginS * 2
                    implicitHeight: wsLabel.implicitHeight + 4
                    radius: Style.radiusXS
                    color: Qt.alpha(Color.mSecondary, 0.2)

                    NText {
                      id: wsLabel
                      anchors.centerIn: parent
                      text: "ws:" + modelData.workspaceId
                      pointSize: Style.fontSizeXXS
                      font.family: Settings.data.ui.fontFixed
                      color: Color.mSecondary
                    }
                  }

                  // Close button
                  NIconButton {
                    icon: "close"
                    baseSize: Style.baseWidgetSize * 0.5
                    applyUiScale: false
                    colorBg: "transparent"
                    colorFg: Color.mOnSurfaceVariant
                    colorBgHover: Qt.alpha(Color.mError, 0.15)
                    colorFgHover: Color.mError
                    colorBorder: "transparent"
                    colorBorderHover: "transparent"
                    tooltipText: "Close window"
                    onClicked: {
                      HyprlandService.closeWindow(modelData);
                    }
                  }
                }
              }
            }

            NText {
              visible: CompositorService.windows.count === 0
              text: "No windows"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
              Layout.topMargin: Style.marginM
            }
          }
        }
      }

      // ── Monitor Info ──
      NBox {
        Layout.fillWidth: true
        visible: monitorData.length > 0
        implicitHeight: monColumn.implicitHeight + Style.margin2M

        ColumnLayout {
          id: monColumn
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginXS

          NText {
            text: "Monitors"
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }

          Repeater {
            model: monitorData

            RowLayout {
              required property var modelData
              Layout.fillWidth: true
              spacing: Style.marginS

              Rectangle {
                width: 8; height: 8; radius: 4
                color: modelData.focused ? Color.mPrimary : Color.mOutline
              }

              NText {
                text: modelData.name
                pointSize: Style.fontSizeXS
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                Layout.preferredWidth: 60
              }

              NText {
                text: modelData.width + "x" + modelData.height + " @ " + (modelData.refreshRate || 0).toFixed(0) + "Hz"
                pointSize: Style.fontSizeXXS
                color: Color.mOnSurfaceVariant
                font.family: Settings.data.ui.fontFixed
              }

              NText {
                text: "scale: " + modelData.scale
                pointSize: Style.fontSizeXXS
                color: Color.mOnSurfaceVariant
                font.family: Settings.data.ui.fontFixed
              }

              NText {
                visible: modelData.vrr
                text: "VRR"
                pointSize: Style.fontSizeXXS
                font.weight: Style.fontWeightBold
                color: Color.mPrimary
              }
            }
          }
        }
      }
    }
  }
}
