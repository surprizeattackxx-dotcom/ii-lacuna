import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Thin circular arc gauge — ii port of noctalia's NCircleStat.
// Arc runs 150deg -> 390deg (gap at the bottom), with the value centered
// and the metric icon tucked in the bottom gap.
Item {
    id: root

    property real ratio: 0 // 0..1
    property string iconName: ""
    property string valueText: ""
    property color fillColor: Appearance.m3colors.m3onSecondaryContainer
    property color trackColor: Appearance.m3colors.m3surfaceContainerHighest
    property real gaugeSize: 54

    readonly property real _lineWidth: 6
    readonly property real _arcRadius: gaugeSize / 2 - 5

    implicitWidth: gaugeSize
    implicitHeight: gaugeSize

    property real animatedRatio: ratio
    Behavior on animatedRatio {
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
    }
    onAnimatedRatioChanged: gauge.requestPaint()
    onFillColorChanged: gauge.requestPaint()
    onTrackColorChanged: gauge.requestPaint()

    Canvas {
        id: gauge
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        renderTarget: Canvas.FramebufferObject
        layer.enabled: true
        layer.smooth: true

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const cx = width / 2, cy = height / 2;
            const r = root._arcRadius;
            const start = Math.PI * 5 / 6;   // 150deg
            const endBg = Math.PI * 13 / 6;  // 390deg

            ctx.reset();
            ctx.lineWidth = root._lineWidth;
            ctx.lineCap = "round";

            // Track
            ctx.strokeStyle = root.trackColor;
            ctx.beginPath();
            ctx.arc(cx, cy, r, start, endBg);
            ctx.stroke();

            // Value arc
            const r2 = Math.max(0, Math.min(1, root.animatedRatio));
            if (r2 > 0.005) {
                const end = start + (endBg - start) * r2;
                ctx.strokeStyle = root.fillColor;
                ctx.beginPath();
                ctx.arc(cx, cy, r, start, end);
                ctx.stroke();
            }
        }
    }

    StyledText {
        id: valueLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -4
        text: root.valueText
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        color: root.fillColor
    }

    MaterialSymbol {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: valueLabel.bottom
        anchors.topMargin: 1
        text: root.iconName
        iconSize: 13
        fill: 1
        color: root.fillColor
    }
}
