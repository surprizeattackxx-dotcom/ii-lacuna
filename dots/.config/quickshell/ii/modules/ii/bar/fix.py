
with open("/home/claude/MonitorPopup.qml", "r") as f:
    content = f.read()

# 1. Add sdrbrightness and sdrsaturation to the model
old_append = """                            vrr: 0,
                            bitdepth: 8,
                            cm: "auto\""""

new_append = """                            vrr: 0,
                            bitdepth: 8,
                            cm: "auto",
                            sdrbrightness: 1.0,
                            sdrsaturation: 1.0"""

assert old_append in content, "append not found"
content = content.replace(old_append, new_append, 1)

# 2. Add to rects push
old_rects = """                                vrr: m.vrr, bitdepth: m.bitdepth, cm: m.cm"""
new_rects = """                                vrr: m.vrr, bitdepth: m.bitdepth, cm: m.cm,
                                sdrbrightness: m.sdrbrightness, sdrsaturation: m.sdrsaturation"""

assert old_rects in content, "rects not found"
content = content.replace(old_rects, new_rects, 1)

# 3. Add to lua output — only emit sdrbrightness/sdrsaturation when cm is hdr/hdredid
old_lua = """                            luaMonitorBlocks.push("    cm = \\"" + r.cm + "\\"");
                            luaMonitorBlocks.push("})");"""

new_lua = """                            luaMonitorBlocks.push("    cm = \\"" + r.cm + "\\"" + (r.cm === "hdr" || r.cm === "hdredid" ? "," : ""));
                            if (r.cm === "hdr" || r.cm === "hdredid") {
                                luaMonitorBlocks.push("    sdrbrightness = " + r.sdrbrightness.toFixed(2) + ",");
                                luaMonitorBlocks.push("    sdrsaturation = " + r.sdrsaturation.toFixed(2));
                            }
                            luaMonitorBlocks.push("})");"""

assert old_lua in content, "lua block not found"
content = content.replace(old_lua, new_lua, 1)

# 4. Add the sliders UI after the Color Mode section, before the closing ColumnLayout
old_end = """                    Item { height: window.s(8) }
                }
                } // Flickable"""

new_end = """                        // SDR Brightness & Saturation — only shown in HDR modes
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: window.s(8)
                            visible: monitorsModel.count > 0 &&
                                     (monitorsModel.get(window.activeEditIndex).cm === "hdr" ||
                                      monitorsModel.get(window.activeEditIndex).cm === "hdredid")

                            Text {
                                text: "HDR SDR CONTENT"
                                color: window.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(12)
                            }

                            // SDR Brightness
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: window.s(4)

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "SDR Brightness"
                                        color: window.text
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: window.s(11)
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: monitorsModel.count > 0 ? monitorsModel.get(window.activeEditIndex).sdrbrightness.toFixed(2) : "1.00"
                                        color: window.yellow
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: window.s(11)
                                        font.weight: Font.Bold
                                    }
                                }

                                Item {
                                    id: brightSlider
                                    Layout.fillWidth: true
                                    height: window.s(32)

                                    property real minVal: 0.5
                                    property real maxVal: 4.0
                                    property real value: monitorsModel.count > 0 ? monitorsModel.get(window.activeEditIndex).sdrbrightness : 1.0
                                    property real pct: (value - minVal) / (maxVal - minVal)

                                    Rectangle {
                                        id: brightTrack
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: window.s(8)
                                        radius: window.s(4)
                                        color: window.mantle
                                        border.color: window.crust
                                        border.width: 1

                                        Rectangle {
                                            width: Math.max(brightKnob.width / 2, brightSlider.pct * parent.width)
                                            height: parent.height
                                            radius: parent.radius
                                            color: window.yellow
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    Rectangle {
                                        id: brightKnob
                                        width: window.s(20); height: window.s(20); radius: window.s(10)
                                        anchors.verticalCenter: brightTrack.verticalCenter
                                        x: (brightSlider.pct * brightTrack.width) - width / 2
                                        color: brightMa.containsPress ? window.yellow : window.text
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        border.width: brightMa.containsMouse ? 3 : 0
                                        border.color: Qt.alpha(window.yellow, 0.4)
                                        Behavior on border.width { NumberAnimation { duration: 100 } }
                                    }

                                    MouseArea {
                                        id: brightMa
                                        anchors.fill: brightTrack
                                        anchors.margins: window.s(-10)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPositionChanged: (mouse) => {
                                            if (pressed && monitorsModel.count > 0) {
                                                let pct = Math.max(0, Math.min(1, (mouse.x - brightTrack.x) / brightTrack.width))
                                                let val = brightSlider.minVal + pct * (brightSlider.maxVal - brightSlider.minVal)
                                                val = Math.round(val * 100) / 100
                                                monitorsModel.setProperty(window.activeEditIndex, "sdrbrightness", val)
                                            }
                                        }
                                        onPressed: (mouse) => {
                                            if (monitorsModel.count > 0) {
                                                let pct = Math.max(0, Math.min(1, (mouse.x - brightTrack.x) / brightTrack.width))
                                                let val = brightSlider.minVal + pct * (brightSlider.maxVal - brightSlider.minVal)
                                                val = Math.round(val * 100) / 100
                                                monitorsModel.setProperty(window.activeEditIndex, "sdrbrightness", val)
                                            }
                                        }
                                    }
                                }

                                // Tick labels
                                RowLayout {
                                    Layout.fillWidth: true
                                    Repeater {
                                        model: ["0.5", "1.0", "1.5", "2.0", "2.5", "3.0", "3.5", "4.0"]
                                        delegate: Text {
                                            Layout.fillWidth: true
                                            horizontalAlignment: index === 0 ? Text.AlignLeft : (index === 7 ? Text.AlignRight : Text.AlignHCenter)
                                            text: modelData
                                            color: window.overlay0
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: window.s(9)
                                        }
                                    }
                                }
                            }

                            // SDR Saturation
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: window.s(4)

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "SDR Saturation"
                                        color: window.text
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: window.s(11)
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: monitorsModel.count > 0 ? monitorsModel.get(window.activeEditIndex).sdrsaturation.toFixed(2) : "1.00"
                                        color: window.pink
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: window.s(11)
                                        font.weight: Font.Bold
                                    }
                                }

                                Item {
                                    id: satSlider
                                    Layout.fillWidth: true
                                    height: window.s(32)

                                    property real minVal: 0.0
                                    property real maxVal: 2.0
                                    property real value: monitorsModel.count > 0 ? monitorsModel.get(window.activeEditIndex).sdrsaturation : 1.0
                                    property real pct: (value - minVal) / (maxVal - minVal)

                                    Rectangle {
                                        id: satTrack
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: window.s(8)
                                        radius: window.s(4)
                                        color: window.mantle
                                        border.color: window.crust
                                        border.width: 1

                                        Rectangle {
                                            width: Math.max(satKnob.width / 2, satSlider.pct * parent.width)
                                            height: parent.height
                                            radius: parent.radius
                                            color: window.pink
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    Rectangle {
                                        id: satKnob
                                        width: window.s(20); height: window.s(20); radius: window.s(10)
                                        anchors.verticalCenter: satTrack.verticalCenter
                                        x: (satSlider.pct * satTrack.width) - width / 2
                                        color: satMa.containsPress ? window.pink : window.text
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        border.width: satMa.containsMouse ? 3 : 0
                                        border.color: Qt.alpha(window.pink, 0.4)
                                        Behavior on border.width { NumberAnimation { duration: 100 } }
                                    }

                                    MouseArea {
                                        id: satMa
                                        anchors.fill: satTrack
                                        anchors.margins: window.s(-10)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPositionChanged: (mouse) => {
                                            if (pressed && monitorsModel.count > 0) {
                                                let pct = Math.max(0, Math.min(1, (mouse.x - satTrack.x) / satTrack.width))
                                                let val = satSlider.minVal + pct * (satSlider.maxVal - satSlider.minVal)
                                                val = Math.round(val * 100) / 100
                                                monitorsModel.setProperty(window.activeEditIndex, "sdrsaturation", val)
                                            }
                                        }
                                        onPressed: (mouse) => {
                                            if (monitorsModel.count > 0) {
                                                let pct = Math.max(0, Math.min(1, (mouse.x - satTrack.x) / satTrack.width))
                                                let val = satSlider.minVal + pct * (satSlider.maxVal - satSlider.minVal)
                                                val = Math.round(val * 100) / 100
                                                monitorsModel.setProperty(window.activeEditIndex, "sdrsaturation", val)
                                            }
                                        }
                                    }
                                }

                                // Tick labels
                                RowLayout {
                                    Layout.fillWidth: true
                                    Repeater {
                                        model: ["0.0", "0.5", "1.0", "1.5", "2.0"]
                                        delegate: Text {
                                            Layout.fillWidth: true
                                            horizontalAlignment: index === 0 ? Text.AlignLeft : (index === 4 ? Text.AlignRight : Text.AlignHCenter)
                                            text: modelData
                                            color: window.overlay0
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: window.s(9)
                                        }
                                    }
                                }
                            }
                        }

                    Item { height: window.s(8) }
                }
                } // Flickable"""

assert old_end in content, "end block not found"
content = content.replace(old_end, new_end, 1)

with open("/home/claude/MonitorPopup.qml", "w") as f:
    f.write(content)
print("SUCCESS")
PYEOF
