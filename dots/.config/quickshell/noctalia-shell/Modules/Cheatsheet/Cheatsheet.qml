pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Widgets

// Keybindings cheatsheet — bar-attached noctalia panel (ii port).
// Categories pack side-by-side into balanced fixed-width columns; every
// binding's full description is shown (wrapping, never elided).
SmartPanel {
    id: root

    preferredWidth: Math.round(1100 * Style.uiScaleRatio)
    preferredHeight: Math.round(740 * Style.uiScaleRatio)

    property string filter: ""
    readonly property int numCols: 3

    // Friendly labels for long/awkward key names so chips stay compact.
    readonly property var keyLabels: ({
        "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": "Mute",
        "XF86AudioMicMute": "Mic", "XF86MonBrightnessUp": "Bright +", "XF86MonBrightnessDown": "Bright −",
        "XF86AudioNext": "Next", "XF86AudioPrev": "Prev", "XF86AudioPlay": "Play",
        "XF86AudioPause": "Pause", "XF86AudioStop": "Stop",
        "RETURN": "Enter", "SLASH": "/", "SEMICOLON": ";", "APOSTROPHE": "'", "EQUAL": "=",
        "MINUS": "−", "PERIOD": ".", "COMMA": ",", "SPACE": "Space", "ESCAPE": "Esc",
        "mouse:272": "LMB", "mouse:273": "RMB", "mouse:274": "MMB"
    })
    function prettyKey(k) {
        if (root.keyLabels[k] !== undefined) return root.keyLabels[k];
        return ("" + k).replace(/^XF86/, "").replace(/^KP_/, "Num ");
    }

    onIsPanelOpenChanged: if (isPanelOpen) HyprlandKeybinds.reload()

    readonly property var shownCategories: {
        if (!root.filter || root.filter.length === 0) return HyprlandKeybinds.categories;
        const f = root.filter.toLowerCase();
        const res = [];
        for (var i = 0; i < HyprlandKeybinds.categories.length; i++) {
            const c = HyprlandKeybinds.categories[i];
            const binds = c.binds.filter(b => ("" + b.key_combo).toLowerCase().indexOf(f) >= 0
                || ("" + b.description).toLowerCase().indexOf(f) >= 0
                || ("" + c.name).toLowerCase().indexOf(f) >= 0);
            if (binds.length > 0) res.push({ name: c.name, binds: binds });
        }
        return res;
    }

    // Balance categories into N columns by estimated height (bind count).
    readonly property var columns: {
        const n = root.numCols;
        const cols = [];
        const h = [];
        for (var i = 0; i < n; i++) { cols.push([]); h.push(0); }
        const cats = root.shownCategories;
        for (var j = 0; j < cats.length; j++) {
            var m = 0;
            for (var k = 1; k < n; k++) if (h[k] < h[m]) m = k;
            cols[m].push(cats[j]);
            h[m] += cats[j].binds.length + 2;
        }
        return cols;
    }

    panelContent: Item {
        id: pc
        anchors.fill: parent
        readonly property real contentPreferredWidth: Math.round(1100 * Style.uiScaleRatio)
        readonly property real contentPreferredHeight: Math.round(740 * Style.uiScaleRatio)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            // header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM
                NIcon { icon: "keyboard"; pointSize: 26; color: Color.mPrimary }
                NText { text: "Keybindings"; pointSize: Style.fontSizeXL; font.weight: Style.fontWeightBold; color: Color.mOnSurface }
                NText { text: HyprlandKeybinds.keybinds.length + " binds"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
                Item { Layout.fillWidth: true }
                NTextInput {
                    Layout.preferredWidth: Math.round(260 * Style.uiScaleRatio)
                    label: ""
                    placeholderText: "Filter…"
                    inputIconName: "search"
                    onTextChanged: root.filter = text
                }
                NIconButton { icon: "x"; tooltipText: "Close"; onClicked: root.close() }
            }

            // masonry columns
            NScrollView {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true

                Row {
                    id: colsRow
                    width: scroll.width - Style.marginM
                    spacing: Style.marginM
                    readonly property real colWidth: (width - (root.numCols - 1) * spacing) / root.numCols

                    Repeater {
                        model: root.columns
                        delegate: Column {
                            id: col
                            required property var modelData
                            width: colsRow.colWidth
                            spacing: Style.marginM

                            Repeater {
                                model: col.modelData
                                delegate: Rectangle {
                                    id: catCard
                                    required property var modelData
                                    width: col.width
                                    height: cardCol.implicitHeight + Style.marginM * 2
                                    color: Color.mSurfaceVariant
                                    radius: Style.radiusM

                                    Column {
                                        id: cardCol
                                        x: Style.marginM
                                        y: Style.marginM
                                        width: parent.width - Style.marginM * 2
                                        spacing: Style.marginXS

                                        NText {
                                            width: parent.width
                                            text: catCard.modelData.name
                                            pointSize: Style.fontSizeM
                                            font.weight: Style.fontWeightBold
                                            color: Color.mPrimary
                                            bottomPadding: Style.marginXXS
                                        }

                                        Repeater {
                                            model: catCard.modelData.binds
                                            delegate: Item {
                                                id: bindRow
                                                required property var modelData
                                                width: cardCol.width
                                                height: Math.max(chips.height, desc.height)

                                                // key combo chips (left, sized to content, capped)
                                                Row {
                                                    id: chips
                                                    width: Math.min(implicitWidth, bindRow.width * 0.55)
                                                    spacing: 2
                                                    Repeater {
                                                        model: ("" + bindRow.modelData.key_combo).split(" + ")
                                                        delegate: Row {
                                                            id: keyChip
                                                            required property var modelData
                                                            required property int index
                                                            spacing: 2
                                                            NText {
                                                                visible: keyChip.index > 0
                                                                text: "+"
                                                                pointSize: Style.fontSizeXS
                                                                color: Color.mOnSurfaceVariant
                                                                anchors.verticalCenter: parent.verticalCenter
                                                            }
                                                            Rectangle {
                                                                implicitWidth: keyT.implicitWidth + 10
                                                                implicitHeight: keyT.implicitHeight + 4
                                                                radius: Style.radiusXS
                                                                color: Color.mSurface
                                                                border.color: Color.mOutline
                                                                border.width: 1
                                                                NText {
                                                                    id: keyT
                                                                    anchors.centerIn: parent
                                                                    text: root.prettyKey(keyChip.modelData)
                                                                    pointSize: Style.fontSizeXS
                                                                    font.weight: Style.fontWeightMedium
                                                                    color: Color.mOnSurface
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // full description (fills the rest, wraps)
                                                NText {
                                                    id: desc
                                                    anchors.left: chips.right
                                                    anchors.leftMargin: Style.marginS
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    text: bindRow.modelData.description
                                                    pointSize: Style.fontSizeXS
                                                    color: Color.mOnSurfaceVariant
                                                    wrapMode: Text.Wrap
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
