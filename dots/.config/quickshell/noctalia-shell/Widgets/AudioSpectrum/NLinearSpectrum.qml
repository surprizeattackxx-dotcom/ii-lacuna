import QtQuick
import qs.Commons

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
  property real minimumSignalValue: 0.01 // Default to 1% of height

  // Peak-hold caps (amplitudes are computed and decayed by SpectrumService)
  property var peaks: []
  property bool showPeaks: false
  property real capThickness: 2

  // Caps need to read as brighter than the bar against a dark surface, and darker
  // against a light one — Qt.lighter() alone washes them out in light mode.
  property color capColor: Settings.data.colorSchemes.darkMode ? Qt.lighter(fillColor, 1.5) : Qt.darker(fillColor, 1.4)

  // Pre compute horizontal mirroring
  readonly property int valuesCount: (values && values.length !== undefined) ? values.length : 0
  readonly property int totalBars: mirrored ? valuesCount * 2 : valuesCount
  readonly property real barSlotSize: totalBars > 0 ? (vertical ? height : width) / totalBars : 0

  Repeater {
    model: root.totalBars

    Rectangle {
      property int valueIndex: root.mirrored ? (index < root.valuesCount ? root.valuesCount - 1 - index : index - root.valuesCount) : index

      property real rawAmp: (root.values && root.values[valueIndex] !== undefined) ? root.values[valueIndex] : 0
      property real amp: (root.showMinimumSignal && rawAmp === 0) ? root.minimumSignalValue : rawAmp

      color: root.fillColor
      border.color: root.strokeColor
      border.width: root.strokeWidth
      antialiasing: true
      smooth: true

      // Only update when value actually changes - reduces GPU load
      width: vertical ? root.width * amp : root.barSlotSize * 0.5
      height: vertical ? root.barSlotSize * 0.5 : root.height * amp
      x: vertical ? (root.barPosition === "left" ? 0 : root.width - width) : index * root.barSlotSize + (root.barSlotSize * 0.25)
      y: vertical ? index * root.barSlotSize + (root.barSlotSize * 0.25) : root.height - height

      // Disable updates when invisible to save GPU
      visible: root.visible

      // Peak cap, drawn as a child so it rides along with the bar's slot geometry.
      // Offsets are relative to the bar and go negative because the cap always sits
      // beyond the bar's growing edge (peakAmp >= amp by construction).
      Rectangle {
        readonly property real rawPeak: (root.peaks && root.peaks[parent.valueIndex] !== undefined) ? root.peaks[parent.valueIndex] : 0
        readonly property real peakAmp: Math.max(rawPeak, parent.amp)

        visible: root.showPeaks && root.visible && peakAmp > 0
        color: root.capColor
        antialiasing: true

        width: root.vertical ? root.capThickness : parent.width
        height: root.vertical ? parent.height : root.capThickness

        x: {
          if (!root.vertical)
            return 0;
          const peakSize = root.width * peakAmp;
          // Bar grows rightward from x=0, or leftward from the right edge.
          return root.barPosition === "left" ? peakSize - root.capThickness - parent.x : (root.width - peakSize) - parent.x;
        }
        y: root.vertical ? 0 : (root.height - root.height * peakAmp) - parent.y
      }
    }
  }
}
