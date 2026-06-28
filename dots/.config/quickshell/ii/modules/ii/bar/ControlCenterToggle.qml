import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root

    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.rightMargin: Appearance.rounding.screenRounding
    Layout.fillWidth: false

    implicitWidth: indicatorRow.implicitWidth + 10 * 2
    implicitHeight: indicatorRow.implicitHeight + 5 * 2

    buttonRadius: Appearance.rounding.full
    colBackground: Appearance.m3colors.m3surfaceContainerHigh
    colBackgroundHover: Appearance.m3colors.m3surfaceContainerHighest
    colRipple: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.12)
    colBackgroundToggled: Appearance.m3colors.m3secondaryContainer
    colBackgroundToggledHover: Qt.rgba(Appearance.m3colors.m3secondaryContainer.r, Appearance.m3colors.m3secondaryContainer.g, Appearance.m3colors.m3secondaryContainer.b, 0.85)
    colRippleToggled: Qt.rgba(Appearance.m3colors.m3onSecondaryContainer.r, Appearance.m3colors.m3onSecondaryContainer.g, Appearance.m3colors.m3onSecondaryContainer.b, 0.12)
    toggled: GlobalStates.controlCenterOpen
    property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurface

    Behavior on colText {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    onPressed: {
        GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen
    }

    RowLayout {
        id: indicatorRow
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            text: "control_camera"
            iconSize: Appearance.font.pixelSize.larger
            color: root.colText
        }
    }
}
