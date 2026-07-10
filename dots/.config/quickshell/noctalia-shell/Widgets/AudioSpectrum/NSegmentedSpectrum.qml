import QtQuick
import Quickshell
import qs.Commons

// LED-ladder spectrum: each band is a column of discrete lit segments, with the
// peak-hold value riding on top as a single cap segment.
//
// Rendered in a fragment shader rather than a Repeater of Rectangles: at 64 bands
// mirrored with ~6 segments each that would be ~800 QQuickItems relaying out every
// frame, per instance.
Item {
  id: root

  property color fillColor: Color.mPrimary
  property color strokeColor: Color.mOnSurface
  property int strokeWidth: 0
  property var values: []
  property bool vertical: false
  property string barPosition: "top" // "top", "bottom", "left", "right"
  property bool mirrored: true

  // Minimum signal properties
  property bool showMinimumSignal: false
  property real minimumSignalValue: 0.01

  // Peak-hold caps (amplitudes are computed and decayed by SpectrumService)
  property var peaks: []
  property bool showPeaks: false

  // Caps read as brighter than the bar on a dark surface, darker on a light one.
  property color capColor: Settings.data.colorSchemes.darkMode ? Qt.lighter(fillColor, 1.5) : Qt.darker(fillColor, 1.4)

  // Fraction of each segment left empty, and of each band slot filled by the bar.
  property real gapRatio: 0.32
  property real barRatio: 0.62

  // Target size of one segment (including its gap) along the growth axis.
  property real segmentPitch: 4

  readonly property int valuesCount: (values && values.length !== undefined) ? values.length : 0
  readonly property bool hasData: valuesCount >= 2

  readonly property real growAxisSize: vertical ? width : height
  readonly property int segments: Math.max(3, Math.min(24, Math.floor(growAxisSize / Math.max(1, segmentPitch))))

  // Bars grow from the left edge only when the bar sits on the left.
  readonly property bool flipped: vertical && barPosition !== "left"

  // Data texture: one pixel per band, R = amplitude, G = peak
  Item {
    id: dataRow
    width: Math.max(root.valuesCount, 4)
    height: 1

    Repeater {
      model: dataRow.width

      Rectangle {
        required property int index
        x: index
        width: 1
        height: 1
        color: {
          if (index >= root.valuesCount)
            return Qt.rgba(0, 0, 0, 1);

          var v = root.values[index];
          if (v === undefined || v === null || !isFinite(v))
            v = 0;
          if (root.showMinimumSignal && v === 0)
            v = root.minimumSignalValue;

          var p = (root.peaks && root.peaks[index] !== undefined) ? root.peaks[index] : 0;
          if (p === null || !isFinite(p))
            p = 0;

          return Qt.rgba(Math.max(0, Math.min(1, v)), Math.max(0, Math.min(1, p)), 0, 1);
        }
      }
    }
  }

  ShaderEffectSource {
    id: dataTex
    sourceItem: dataRow
    textureSize: Qt.size(dataRow.width, 1)
    live: true
    smooth: false
    hideSource: true
  }

  ShaderEffect {
    anchors.fill: parent
    visible: root.hasData && root.width > 0 && root.height > 0

    property variant dataSource: dataTex
    property color fillColor: root.fillColor
    property color capColor: root.capColor
    property real count: root.valuesCount
    property real texWidth: dataRow.width
    property real vertical: root.vertical ? 1.0 : 0.0
    property real mirrored: root.mirrored ? 1.0 : 0.0
    property real flip: root.flipped ? 1.0 : 0.0
    property real segments: root.segments
    property real showPeaks: root.showPeaks ? 1.0 : 0.0
    property real gapRatio: root.gapRatio
    property real barRatio: root.barRatio

    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/segmented_spectrum.frag.qsb")
    blending: true
  }
}
