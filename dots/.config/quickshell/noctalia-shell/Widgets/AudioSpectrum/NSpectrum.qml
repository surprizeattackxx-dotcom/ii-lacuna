import QtQuick
import qs.Commons
import qs.Services.Media
import qs.Services.UI

// Type-dispatching wrapper around the concrete N*Spectrum implementations.
// Consumers set `type` and the shared property contract; the right implementation
// is resolved through SpectrumRegistry. Renders nothing for "none"/"" or an
// unknown type.
Item {
  id: root

  property string type: "linear"

  // Property contract every N*Spectrum implementation must expose.
  property var values: []
  property color fillColor: Color.mPrimary
  property color strokeColor: Color.mOnSurface
  property int strokeWidth: 0
  property bool vertical: false
  property string barPosition: "top"
  property bool mirrored: true
  property bool showMinimumSignal: false
  property real minimumSignalValue: 0.01

  // Peak-hold caps. Default to the shared service so consumers get them for free.
  property var peaks: SpectrumService.peaks
  property bool showPeaks: Settings.data.audio.spectrumPeaks

  property bool asynchronous: true

  // Set false to unload the implementation entirely (e.g. hidden, idle, panel closed).
  property bool active: true

  readonly property bool hasSpectrum: SpectrumRegistry.isEnabled(root.type)
  readonly property Item spectrumItem: loader.item

  Loader {
    id: loader
    anchors.fill: parent
    asynchronous: root.asynchronous
    active: root.active && root.hasSpectrum
    source: root.hasSpectrum ? SpectrumRegistry.sourceUrl(root.type) : ""
  }

  // Bindings rather than initial properties so the loaded implementation keeps
  // tracking `values` (which changes every audio frame) and theme colors.
  Binding {
    target: loader.item
    property: "values"
    value: root.values
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
  Binding {
    target: loader.item
    property: "fillColor"
    value: root.fillColor
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
  Binding {
    target: loader.item
    property: "strokeColor"
    value: root.strokeColor
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
  Binding {
    target: loader.item
    property: "strokeWidth"
    value: root.strokeWidth
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
  Binding {
    target: loader.item
    property: "vertical"
    value: root.vertical
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
  Binding {
    target: loader.item
    property: "barPosition"
    value: root.barPosition
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
  Binding {
    target: loader.item
    property: "mirrored"
    value: root.mirrored
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
  Binding {
    target: loader.item
    property: "showMinimumSignal"
    value: root.showMinimumSignal
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
  Binding {
    target: loader.item
    property: "minimumSignalValue"
    value: root.minimumSignalValue
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
  Binding {
    target: loader.item
    property: "peaks"
    value: root.peaks
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
  Binding {
    target: loader.item
    property: "showPeaks"
    value: root.showPeaks
    when: loader.item !== null
    restoreMode: Binding.RestoreNone
  }
}
