import QtQuick
import qs.Commons

Item {
  id: root
  property color fillColor: Color.mPrimary
  property color strokeColor: Color.mOnSurface
  property int strokeWidth: 0
  property var values: []
  property bool vertical: false
  property bool mirrored: true

  // Part of the shared spectrum contract; unused here since bars grow from the center.
  property string barPosition: "top"

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

  // Pre-compute mirroring
  readonly property int valuesCount: (values && values.length !== undefined) ? values.length : 0
  readonly property int totalBars: mirrored ? valuesCount * 2 : valuesCount
  readonly property real barSlotSize: totalBars > 0 ? (vertical ? height : width) / totalBars : 0
  readonly property real centerY: height / 2
  readonly property real centerX: width / 2

  Repeater {
    model: root.totalBars

    Rectangle {
      property int valueIndex: root.mirrored ? (index < root.valuesCount ? root.valuesCount - 1 - index : index - root.valuesCount) : index

      property real rawAmp: (root.values && root.values[valueIndex] !== undefined) ? root.values[valueIndex] : 0
      property real amp: (root.showMinimumSignal && rawAmp === 0) ? root.minimumSignalValue : rawAmp

      property real barSize: (vertical ? root.width : root.height) * amp

      color: root.fillColor
      border.color: root.strokeColor
      border.width: root.strokeWidth
      antialiasing: true
      smooth: true

      width: vertical ? barSize : root.barSlotSize * 0.8
      height: vertical ? root.barSlotSize * 0.8 : barSize
      x: vertical ? root.centerX - (barSize / 2) : index * root.barSlotSize + (root.barSlotSize * 0.25)
      y: vertical ? index * root.barSlotSize + (root.barSlotSize * 0.25) : root.centerY - (barSize / 2)

      // Disable updates when invisible to save GPU
      visible: root.visible

      // Bars grow from the center in both directions, so each band gets two caps.
      // Coordinates are relative to the bar, hence the parent.x / parent.y offsets.
      readonly property real rawPeak: (root.peaks && root.peaks[valueIndex] !== undefined) ? root.peaks[valueIndex] : 0
      readonly property real peakAmp: Math.max(rawPeak, amp)
      readonly property real peakSize: (root.vertical ? root.width : root.height) * peakAmp

      Repeater {
        model: 2

        Rectangle {
          // index 0 -> the cap on the low side of center, index 1 -> the high side
          readonly property real edge: index === 0 ? (-parent.peakSize / 2) : (parent.peakSize / 2 - root.capThickness)

          visible: root.showPeaks && root.visible && parent.peakAmp > 0
          color: root.capColor
          antialiasing: true

          width: root.vertical ? root.capThickness : parent.width
          height: root.vertical ? parent.height : root.capThickness

          x: root.vertical ? (root.centerX + edge) - parent.x : 0
          y: root.vertical ? 0 : (root.centerY + edge) - parent.y
        }
      }
    }
  }
}
