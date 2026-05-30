import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.modules.ii.bar

StyledPopup {
    id: root
    property bool open: false

    contentItem: Item {
        id: musicContent
        implicitWidth: s(720)
        implicitHeight: s(800)

        Scaler { id: scaler; currentWidth: Screen.width }
        function s(val) { return scaler.s(val); }

        MatugenColors { id: _theme }

        readonly property color base: Appearance.m3colors.base
        readonly property color surface0: Appearance.m3colors.surface0
        readonly property color surface1: Appearance.m3colors.surface1
        readonly property color surface2: Appearance.m3colors.surface2
        readonly property color text: Appearance.m3colors.text
        readonly property color subtext0: Appearance.m3colors.subtext0
        readonly property color mauve: Appearance.m3colors.mauve
        readonly property color blue: Appearance.m3colors.blue

        property var musicData: ({
            "title": "Loading...", "artist": "", "status": "Stopped", "percent": 0,
            "lengthStr": "00:00", "positionStr": "00:00", "artUrl": "", "playerName": ""
        })

        property var eqData: ({ "preset": "Flat" })
        property bool userIsSeeking: false

        Timer {
            interval: 500; running: true; repeat: true; triggeredOnStart: true
            onTriggered: { musicProc.running = true; eqProc.running = true; }
        }

        Process {
            id: musicProc
            command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/music/music_info.sh"]
            stdout: StdioCollector {
                onStreamFinished: { try { if (this.text) musicContent.musicData = JSON.parse(this.text); } catch(e) {} }
            }
        }

        Process {
            id: eqProc
            command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/music/equalizer.sh get"]
            stdout: StdioCollector {
                onStreamFinished: { try { if (this.text) musicContent.eqData = JSON.parse(this.text); } catch(e) {} }
            }
        }

        function exec(cmd) { Quickshell.execDetached(["bash", "-c", cmd]); }

        // --- UI ---
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(base.r, base.g, base.b, 0.95)
            radius: s(20)
            border.color: Qt.rgba(text.r, text.g, text.b, 0.1)
            border.width: 1
            clip: true

            // Minimalist Background Blur
            Image {
                anchors.fill: parent
                source: musicContent.musicData.blur || ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width, height)
                asynchronous: true
                opacity: 0.15
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: s(35)
                spacing: s(30)

                // Header Row
                RowLayout {
                    spacing: s(30)
                    
                    // Cover Art
                    Rectangle {
                        width: s(160); height: s(160); radius: s(16); color: surface0
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.3; shadowBlur: 0.5 }
                        
                        Image {
                            anchors.fill: parent; anchors.margins: 1
                            source: musicContent.musicData.artUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(width, height)
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 500 } }
                            
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: 160; height: 160; radius: s(15)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: s(5)
                        
                        Text {
                            text: musicContent.musicData.title; font.family: "JetBrains Mono"; font.pixelSize: s(20); font.weight: Font.Black; color: text
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: musicContent.musicData.artist; font.family: "JetBrains Mono"; font.pixelSize: s(14); color: subtext0
                        }

                        // Progress Slider
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.topMargin: s(20); spacing: s(2)
                            Slider {
                                id: prog; Layout.fillWidth: true; from: 0; to: 100; value: musicContent.musicData.percent
                                onMoved: { musicContent.userIsSeeking = true; exec("~/.config/hypr/scripts/quickshell/music/player_control.sh seek " + value + " " + musicContent.musicData.length + " \"" + musicContent.musicData.playerName + "\""); }
                                onPressedChanged: if(!pressed) musicContent.userIsSeeking = false
                                background: Rectangle { height: 4; radius: 2; color: surface0; Rectangle { width: prog.visualPosition * parent.width; height: 4; color: mauve; radius: 2 } }
                                handle: Rectangle { x: prog.visualPosition * (prog.width-12); y: (prog.height-12)/2; width: 12; height: 12; radius: 6; color: text }
                            }
                            RowLayout {
                                Text { text: musicContent.musicData.positionStr; font.family: "JetBrains Mono"; font.pixelSize: s(10); color: subtext0 }
                                Item { Layout.fillWidth: true }
                                Text { text: musicContent.musicData.lengthStr; font.family: "JetBrains Mono"; font.pixelSize: s(10); color: subtext0 }
                            }
                        }
                    }
                }

                // Controls
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter; spacing: s(50)
                    Text { text: "󰒮"; font.family: "Iosevka Nerd Font"; font.pixelSize: s(28); color: text; MouseArea { anchors.fill: parent; onClicked: exec("playerctl previous") } }
                    Rectangle {
                        width: s(60); height: s(60); radius: s(30); color: mauve
                        Text { anchors.centerIn: parent; text: musicContent.musicData.status === "Playing" ? "󰏤" : "󰐊"; font.family: "Iosevka Nerd Font"; font.pixelSize: s(32); color: base }
                        MouseArea { anchors.fill: parent; onClicked: exec("playerctl play-pause") }
                    }
                    Text { text: "󰒭"; font.family: "Iosevka Nerd Font"; font.pixelSize: s(28); color: text; MouseArea { anchors.fill: parent; onClicked: exec("playerctl next") } }
                }

                // Minimalist Equalizer
                ColumnLayout {
                    Layout.fillWidth: true; spacing: s(15)
                    
                    RowLayout {
                        Text { text: "Audio Equalizer"; font.family: "JetBrains Mono"; font.pixelSize: s(14); font.bold: true; color: mauve; Layout.fillWidth: true }
                        Text { text: musicContent.eqData.preset; font.family: "JetBrains Mono"; font.pixelSize: s(12); color: subtext0 }
                    }

                    Row {
                        Layout.fillWidth: true; height: s(120); spacing: s(12)
                        Repeater {
                            model: 10
                            delegate: Item {
                                width: (parent.width - (9 * s(12))) / 10; height: parent.height
                                Slider {
                                    id: eq; anchors.fill: parent; orientation: Qt.Vertical; from: -12; to: 12; stepSize: 1; value: musicContent.eqData["b"+(index+1)] || 0
                                    onMoved: exec("~/.config/hypr/scripts/quickshell/music/equalizer.sh set_band " + (index+1) + " " + value)
                                    background: Rectangle { anchors.centerIn: parent; width: s(6); height: parent.height; radius: 3; color: surface0 }
                                    handle: Rectangle { x: (parent.width-12)/2; y: eq.visualPosition * (parent.height-12); width: 12; height: 12; radius: 6; color: mauve }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: s(10)
                        Repeater {
                            model: ["Flat", "Bass", "Treble", "Rock", "Pop"]
                            delegate: Rectangle {
                                Layout.fillWidth: true; height: s(32); radius: 8; color: musicContent.eqData.preset === modelData ? mauve : surface0
                                Text { anchors.centerIn: parent; text: modelData; font.family: "JetBrains Mono"; font.pixelSize: s(11); color: musicContent.eqData.preset === modelData ? base : text }
                                MouseArea { anchors.fill: parent; onClicked: exec("~/.config/hypr/scripts/quickshell/music/equalizer.sh preset " + modelData) }
                            }
                        }
                    }
                }
            }
        }
    }
}
