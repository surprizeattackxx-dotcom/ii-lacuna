import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    SwipeView.onIsCurrentItemChanged: if (SwipeView.isCurrentItem) OpenCode.start()

    Connections {
        target: OpenCode
        function onDraftInputChanged() {
            if (OpenCode.draftInput.length === 0) return;
            input.text = OpenCode.draftInput;
            OpenCode.draftInput = "";
            input.forceActiveFocus();
            input.cursorPosition = input.text.length;
        }
    }

    function send() {
        const text = input.text.trim();
        if (text.length === 0) return;
        OpenCode.sendPrompt(text);
        input.clear();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout { // Header: model + agent + new session
            Layout.fillWidth: true
            spacing: 6

            StyledComboBox {
                Layout.fillWidth: true
                model: OpenCode.models.map(m => m.label)
                displayText: OpenCode.providerID === "" ? Translation.tr("Model") : `${OpenCode.providerID}/${OpenCode.modelID}`
                onActivated: (index) => {
                    const m = OpenCode.models[index];
                    if (m) OpenCode.setModel(m.providerID, m.modelID);
                }
            }

            StyledComboBox {
                visible: OpenCode.agents.length > 0
                model: [Translation.tr("auto")].concat(OpenCode.agents)
                displayText: OpenCode.agent === "" ? Translation.tr("auto") : OpenCode.agent
                onActivated: (index) => {
                    OpenCode.agent = (index === 0) ? "" : OpenCode.agents[index - 1];
                }
            }

            RippleButton {
                implicitWidth: 34; implicitHeight: 34
                onClicked: OpenCode.newSession()
                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    text: "add"
                    iconSize: 20
                    color: Appearance.colors.colOnLayer1
                }
                StyledToolTip { text: Translation.tr("New session") }
            }
        }

        StyledListView { // Messages
            id: messageList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 10
            model: OpenCode.messages
            onCountChanged: positionViewAtEnd()

            delegate: ColumnLayout {
                required property var modelData
                width: messageList.width
                spacing: 3

                readonly property bool isUser: modelData.role === "user"
                readonly property var parts: (modelData.order ?? []).map(id => modelData.parts[id]).filter(Boolean)

                StyledText {
                    text: parent.isUser ? Translation.tr("You") : "OpenCode"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                Repeater {
                    model: parent.parts
                    delegate: Loader {
                        required property var modelData
                        Layout.fillWidth: true
                        readonly property string ptype: modelData.type ?? "text"
                        readonly property string ptext: modelData.text ?? ""
                        sourceComponent: {
                            if (ptype === "text") return textPart;
                            if (ptype === "reasoning") return reasoningPart;
                            return toolPart;
                        }

                        Component {
                            id: textPart
                            StyledText {
                                width: messageList.width
                                text: ptext
                                wrapMode: Text.WordWrap
                                color: Appearance.colors.colOnLayer1
                                textFormat: Text.MarkdownText
                                onLinkActivated: (link) => Qt.openUrlExternally(link)
                            }
                        }
                        Component {
                            id: reasoningPart
                            StyledText {
                                width: messageList.width
                                text: ptext
                                visible: ptext.length > 0
                                wrapMode: Text.WordWrap
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                        Component {
                            id: toolPart
                            RowLayout {
                                width: messageList.width
                                spacing: 5
                                MaterialSymbol { text: "build"; iconSize: 15; color: Appearance.colors.colSubtext }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.tool ?? modelData.callID ?? ptype
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }

        Repeater { // Inline permission prompts
            model: OpenCode.pendingPermissions
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: permCol.implicitHeight + 16
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: permCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Allow %1?").arg(modelData.tool ?? modelData.permission ?? Translation.tr("action"))
                        wrapMode: Text.WordWrap
                        color: Appearance.colors.colOnLayer2
                    }
                    RowLayout {
                        spacing: 6
                        RippleButton {
                            implicitHeight: 30
                            onClicked: OpenCode.respondPermission(modelData.id, "once")
                            contentItem: StyledText { text: Translation.tr("Once"); color: Appearance.colors.colOnLayer2 }
                        }
                        RippleButton {
                            implicitHeight: 30
                            onClicked: OpenCode.respondPermission(modelData.id, "always")
                            contentItem: StyledText { text: Translation.tr("Always"); color: Appearance.colors.colOnLayer2 }
                        }
                        RippleButton {
                            implicitHeight: 30
                            onClicked: OpenCode.respondPermission(modelData.id, "reject")
                            contentItem: StyledText { text: Translation.tr("Deny"); color: Appearance.colors.colError }
                        }
                    }
                }
            }
        }

        RowLayout { // Input
            Layout.fillWidth: true
            spacing: 6

            MaterialTextArea {
                id: input
                Layout.fillWidth: true
                Layout.maximumHeight: 120
                placeholderText: OpenCode.serverReady ? Translation.tr("Ask OpenCode…") : Translation.tr("Starting OpenCode…")
                wrapMode: Text.WordWrap
                Keys.onPressed: (event) => {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                        root.send();
                        event.accepted = true;
                    }
                }
            }

            RippleButton {
                implicitWidth: 40; implicitHeight: 40
                enabled: OpenCode.serverReady
                onClicked: OpenCode.busy ? OpenCode.abort() : root.send()
                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    text: OpenCode.busy ? "stop" : "send"
                    iconSize: 22
                    color: Appearance.colors.colOnPrimary
                }
                colBackground: Appearance.colors.colPrimary
            }
        }
    }
}
