import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Bar widget that toggles the bar-attached keybindings cheatsheet panel.
NIconButton {
  id: root

  property ShellScreen screen

  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""

  icon: "keyboard"
  tooltipText: "Keybindings cheatsheet"
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

  onClicked: PanelService.getPanel("cheatsheetPanel", screen)?.toggle(this)
}
