import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Bar widget for the AI assistant panel. Toggles the bar-attached SmartPanel.
NIconButton {
  id: root

  property ShellScreen screen

  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""

  icon: "sparkles"
  tooltipText: {
    if (!screen || PanelService.getPanel("aiChatPanel", screen)?.isPanelOpen)
      return "";
    return "AI assistant";
  }
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: Color.mOnSurface
  colorBgHover: Color.mHover
  colorFgHover: Color.mOnHover
  colorBorder: Style.capsuleBorderColor
  colorBorderHover: Style.capsuleBorderColor

  onClicked: PanelService.getPanel("aiChatPanel", screen)?.toggle(this)
}
