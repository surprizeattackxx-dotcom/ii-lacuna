pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Ai
import qs.Widgets

// AI assistant panel — native noctalia SmartPanel (bar-attached popup with the
// standard open animation). Content styled with noctalia widgets.
SmartPanel {
    id: root

    panelContent: Item {
        id: pc
        anchors.fill: parent

        readonly property real contentPreferredWidth: Math.round(460 * Style.uiScaleRatio)
        readonly property real contentPreferredHeight: Math.round(600 * Style.uiScaleRatio)

        function strip(c) {
            return ("" + c).replace(/<think>[\s\S]*?<\/think>/g, "").replace(/<think>[\s\S]*$/g, "").trim();
        }
        function send() {
            const t = input.text;
            if (t.trim().length === 0) return;
            input.text = "";
            AiService.sendMessage(t);
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            // ─── Header ───
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                    text: "Assistant"
                    pointSize: Style.fontSizeXL
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                }
                Item { Layout.fillWidth: true }

                NComboBox {
                    id: modelCombo
                    minimumWidth: Math.round(150 * Style.uiScaleRatio)
                    model: AiService.models.map(function (m, i) { return { "key": String(i), "name": m.name }; })
                    currentKey: String(AiService.currentModelId)
                    onSelected: function (key) { AiService.setModel(parseInt(key)); }
                }
                NIconButton {
                    icon: "trash-2"
                    tooltipText: "Clear conversation"
                    baseSize: Style.baseWidgetSize * 0.9
                    onClicked: AiService.clearChat()
                }
            }

            // ─── Messages ───
            NListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Style.marginS
                model: AiService.visibleMessages
                onContentHeightChanged: contentY = Math.max(0, contentHeight)

                delegate: Item {
                    id: rowItem
                    required property var modelData
                    width: list.width

                    readonly property bool isUser: modelData.role === "user"
                    readonly property bool isInterface: modelData.role === "interface"
                    readonly property string body: pc.strip(modelData.content)
                    // reasoning text (inside <think>) — shown live while there's no final answer yet
                    readonly property string reasoning: ("" + modelData.content).replace(/<\/?think>/g, "").trim()
                    readonly property bool showReasoning: body.length === 0 && !modelData.done && reasoning.length > 0
                    // hide assistant messages that are pure tool-calls with no text
                    readonly property bool collapsed: body.length === 0 && modelData.done && !isUser
                    visible: !collapsed
                    implicitHeight: collapsed ? 0 : bubble.implicitHeight

                    NBox {
                        id: bubble
                        width: rowItem.isUser ? Math.min(rowItem.width * 0.82, contentText.implicitWidth + Style.marginL * 2)
                                              : rowItem.width
                        anchors.right: rowItem.isUser ? parent.right : undefined
                        anchors.left: rowItem.isUser ? undefined : parent.left
                        implicitHeight: contentText.implicitHeight + Style.marginM * 2
                        color: rowItem.isUser ? Color.mPrimary
                             : rowItem.isInterface ? Color.mSurfaceVariant
                             : Color.smartAlpha(Color.mSurfaceVariant)

                        NText {
                            id: contentText
                            anchors {
                                left: parent.left; right: parent.right; top: parent.top
                                margins: Style.marginM
                            }
                            markdownTextEnabled: !rowItem.showReasoning
                            wrapMode: Text.Wrap
                            pointSize: rowItem.showReasoning ? Style.fontSizeM : Style.fontSizeL
                            font.italic: rowItem.showReasoning
                            color: rowItem.isUser ? Color.mOnPrimary
                                 : rowItem.showReasoning ? Color.mOnSurfaceVariant : Color.mOnSurface
                            text: {
                                if (rowItem.body.length > 0) return rowItem.body;
                                if (rowItem.showReasoning) return "💭 " + rowItem.reasoning;
                                return rowItem.modelData.done ? "" : "…";
                            }
                            onLinkActivated: (link) => Qt.openUrlExternally(link)
                        }
                    }
                }
            }

            // ─── Input ───
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NTextInput {
                    id: input
                    Layout.fillWidth: true
                    label: ""
                    placeholderText: AiService.busy ? "Thinking…" : "Message the assistant…"
                    inputIconName: "message-circle"
                    onAccepted: pc.send()
                }
                NIconButton {
                    icon: "send"
                    tooltipText: "Send"
                    enabled: input.text.trim().length > 0 && !AiService.busy
                    onClicked: pc.send()
                }
            }
        }
    }
}
