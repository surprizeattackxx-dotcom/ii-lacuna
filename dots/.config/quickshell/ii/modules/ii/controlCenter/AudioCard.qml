import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.controlCenter

// Audio controls card: OUTPUT and INPUT volume controls placed side by side.
// ii translation of noctalia's AudioCard (two ColumnLayouts inside a RowLayout,
// each with a mute-toggle icon button, a device description, and a slider).
CCBox {
    id: root
    Layout.fillWidth: true
    implicitHeight: 60

    RowLayout {
        anchors.fill: parent
        anchors.margins: 9
        spacing: 9

        // Output Volume Section
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            spacing: 2
            opacity: Audio.sink ? 1.0 : 0.5
            enabled: Audio.sink !== null

            // Output header: mute toggle + device name
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                RippleButton {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    buttonRadius: 13
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up"
                        iconSize: 18
                        color: (Audio.sink?.audio?.muted ?? false) ? Appearance.colors.colError : Appearance.m3colors.m3onSurface
                    }
                    onClicked: {
                        if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    text: Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : Translation.tr("No output device")
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.m3colors.m3onSurfaceVariant
                }
            }

            // Output slider
            StyledSlider {
                Layout.fillWidth: true
                configuration: StyledSlider.Configuration.XS
                from: 0
                to: 1
                value: Audio.sink?.audio?.volume ?? 0
                onMoved: {
                    if (Audio.sink?.audio) Audio.sink.audio.volume = value
                }
            }
        }

        // Input Volume Section
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            spacing: 2
            opacity: Audio.source ? 1.0 : 0.5
            enabled: Audio.source !== null

            // Input header: mic mute toggle + device name
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                RippleButton {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    buttonRadius: 13
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: (Audio.source?.audio?.muted ?? false) ? "mic_off" : "mic"
                        iconSize: 18
                        color: (Audio.source?.audio?.muted ?? false) ? Appearance.colors.colError : Appearance.m3colors.m3onSurface
                    }
                    onClicked: {
                        if (Audio.source?.audio) Audio.source.audio.muted = !Audio.source.audio.muted
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    text: Audio.source ? Audio.friendlyDeviceName(Audio.source) : Translation.tr("No input device")
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.m3colors.m3onSurfaceVariant
                }
            }

            // Input slider
            StyledSlider {
                Layout.fillWidth: true
                configuration: StyledSlider.Configuration.XS
                from: 0
                to: 1
                value: Audio.source?.audio?.volume ?? 0
                onMoved: {
                    if (Audio.source?.audio) Audio.source.audio.volume = value
                }
            }
        }
    }
}
