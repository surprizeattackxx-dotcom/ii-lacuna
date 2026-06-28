import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  property string valueIcon: widgetData.icon !== undefined ? widgetData.icon : widgetMetadata.icon
  property bool valueEnableColorization: widgetData.enableColorization !== undefined ? widgetData.enableColorization : widgetMetadata.enableColorization
  property string valueColorizeSystemIcon: widgetData.colorizeSystemIcon !== undefined ? widgetData.colorizeSystemIcon : widgetMetadata.colorizeSystemIcon

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.icon = valueIcon;
    settings.enableColorization = valueEnableColorization;
    settings.colorizeSystemIcon = valueColorizeSystemIcon;
    settingsChanged(settings);
  }

  NIconSelector {
    label: I18n.tr("bar.common.icon-label")
    icon: valueIcon
    onSelected: icon => {
                  valueIcon = icon;
                  saveSettings();
                }
    defaultValue: widgetMetadata.icon
  }

  NToggle {
    label: I18n.tr("bar.common.enable-colorization-label")
    description: I18n.tr("bar.common.enable-colorization-description")
    checked: valueEnableColorization
    onToggled: checked => {
                 valueEnableColorization = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.enableColorization
  }

  NColorChoice {
    visible: valueEnableColorization
    label: I18n.tr("bar.common.colorize-system-icon-label")
    description: I18n.tr("bar.common.colorize-system-icon-description")
    currentColor: valueColorizeSystemIcon
    onColorChanged: color => {
                      valueColorizeSystemIcon = color;
                      saveSettings();
                    }
    defaultValue: widgetMetadata.colorizeSystemIcon
  }
}
