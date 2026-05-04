import QtQuick
import QtQuick.Effects
import qs.modules.common

MultiEffect {
    required property var target
    source: target
    anchors.fill: source
    autoPaddingEnabled: true
    shadowEnabled: true
    shadowColor: Appearance.colors.colShadow
    shadowBlur: 0.65
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 0
    shadowScale: 1.0
}
