import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects

Item {
    id: root
    property list<var> points
    property real maxVisualizerValue: 1000
    property int smoothing: 2
    property bool live: true
    property color color: Appearance.m3colors.m3primary

    property real barSpacing: 0.3
    property real cornerRadius: 3
    property real barWidth: 4

    property var _smoothBuf: []
    property int _barCount: Math.max(2, Math.floor(width / (barWidth / (1.0 - barSpacing))))

    anchors.fill: parent

    onPointsChanged: _recalc()
    on_BarCountChanged: _recalc()

    function _recalc() {
        if (!root.live || root.points.length < 2) {
            root._smoothBuf = new Array(root._barCount).fill(0);
            return;
        }
        var n = root._barCount;
        var pLen = root.points.length;
        var sw = root.smoothing;
        var buf = new Array(n);
        for (var i = 0; i < n; ++i) {
            var srcIdx = (i / (n - 1)) * (pLen - 1);
            var sum = 0, count = 0;
            for (var j = -sw; j <= sw; ++j) {
                var idx = Math.max(0, Math.min(pLen - 1, Math.round(srcIdx) + j));
                sum += root.points[idx];
                count++;
            }
            buf[i] = sum / count;
        }
        root._smoothBuf = buf;
    }

    Row {
        anchors.fill: parent
        spacing: root.barWidth * root.barSpacing / (1.0 - root.barSpacing)

        Repeater {
            model: root._barCount
            delegate: Rectangle {
                required property int index
                width: root.barWidth
                height: Math.max(1, ((root._smoothBuf[index] ?? 0) / (root.maxVisualizerValue || 1)) * root.parent.height)
                anchors.bottom: parent.bottom
                radius: root.cornerRadius
                color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.85)
            }
        }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        source: root
        saturation: 0.2
        blurEnabled: true
        blurMax: 5
        blur: 0.6
    }
}