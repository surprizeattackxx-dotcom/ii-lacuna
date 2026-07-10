pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

Singleton {
  id: root

  // Single source of truth for audio visualizer types.
  //
  // To add a visualizer:
  //   1. Drop N<Name>Spectrum.qml into Widgets/AudioSpectrum/. It must expose the
  //      property contract NSpectrum binds to: values, fillColor, strokeColor,
  //      strokeWidth, vertical, barPosition, mirrored, showMinimumSignal,
  //      minimumSignalValue, peaks, showPeaks.
  //   2. Add one entry below.
  //   3. Add "options.visualizer-types.<key>" to Assets/Translations/*.json.
  //
  // Every consumer (bar widget, lock screen, media panels, desktop widgets, the
  // settings dropdown, click-to-cycle) picks it up automatically.
  readonly property var types: [
    {
      "key": "linear",
      "source": "NLinearSpectrum.qml"
    },
    {
      "key": "mirrored",
      "source": "NMirroredSpectrum.qml"
    },
    {
      "key": "wave",
      "source": "NWaveSpectrum.qml"
    },
    {
      "key": "segmented",
      "source": "NSegmentedSpectrum.qml"
    }
  ]

  readonly property var keys: types.map(t => t.key)

  // "" and "none" both mean "no visualizer" and are persisted in settings.
  function isEnabled(key) {
    return key !== "" && key !== "none" && keys.indexOf(key) >= 0;
  }

  function sourceUrl(key) {
    for (var i = 0; i < types.length; i++) {
      if (types[i].key === key) {
        return Qt.resolvedUrl(Quickshell.shellDir + "/Widgets/AudioSpectrum/" + types[i].source);
      }
    }
    return "";
  }

  function label(key) {
    return I18n.tr("options.visualizer-types." + key);
  }

  // Next type in the cycle. Falls back to the first type when the current value
  // is "none"/"" or something stale left behind by an older config.
  function next(key) {
    const i = keys.indexOf(key);
    if (i < 0) {
      return keys[0];
    }
    return keys[(i + 1) % keys.length];
  }

  // Model for NComboBox. Pass true to prepend the "none" entry.
  function comboModel(includeNone) {
    var model = [];
    if (includeNone) {
      model.push({
        "key": "none",
        "name": I18n.tr("common.none")
      });
    }
    for (var i = 0; i < types.length; i++) {
      model.push({
        "key": types[i].key,
        "name": root.label(types[i].key)
      });
    }
    return model;
  }
}
