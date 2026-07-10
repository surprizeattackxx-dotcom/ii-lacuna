import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NComboBox {
    label: I18n.tr("panels.audio.visualizer-type-label")
    description: I18n.tr("panels.audio.visualizer-type-description")
    model: SpectrumRegistry.comboModel(true)
    currentKey: Settings.data.audio.visualizerType
    defaultValue: Settings.getDefaultValue("audio.visualizerType")
    onSelected: key => Settings.data.audio.visualizerType = key
  }

  NToggle {
    label: I18n.tr("panels.audio.spectrum-mirrored-label")
    description: I18n.tr("panels.audio.spectrum-mirrored-description")
    checked: Settings.data.audio.spectrumMirrored
    defaultValue: Settings.getDefaultValue("audio.spectrumMirrored")
    onToggled: Settings.data.audio.spectrumMirrored = checked
  }

  NToggle {
    label: I18n.tr("panels.audio.spectrum-peaks-label")
    description: I18n.tr("panels.audio.spectrum-peaks-description")
    checked: Settings.data.audio.spectrumPeaks
    defaultValue: Settings.getDefaultValue("audio.spectrumPeaks")
    onToggled: Settings.data.audio.spectrumPeaks = checked
  }

  NComboBox {
    label: I18n.tr("panels.audio.media-frame-rate-label")
    description: I18n.tr("panels.audio.media-frame-rate-description")
    model: [
      {
        "key": "30",
        "name": I18n.tr("options.frame-rates-fps", {
                          "fps": "30"
                        })
      },
      {
        "key": "60",
        "name": I18n.tr("options.frame-rates-fps", {
                          "fps": "60"
                        })
      },
      {
        "key": "100",
        "name": I18n.tr("options.frame-rates-fps", {
                          "fps": "100"
                        })
      },
      {
        "key": "120",
        "name": I18n.tr("options.frame-rates-fps", {
                          "fps": "120"
                        })
      },
      {
        "key": "144",
        "name": I18n.tr("options.frame-rates-fps", {
                          "fps": "144"
                        })
      },
      {
        "key": "165",
        "name": I18n.tr("options.frame-rates-fps", {
                          "fps": "165"
                        })
      },
      {
        "key": "240",
        "name": I18n.tr("options.frame-rates-fps", {
                          "fps": "240"
                        })
      }
    ]
    currentKey: Settings.data.audio.spectrumFrameRate
    defaultValue: Settings.getDefaultValue("audio.spectrumFrameRate")
    onSelected: key => Settings.data.audio.spectrumFrameRate = key
  }
}
