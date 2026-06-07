pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

Column {
    id: root
    required property string categoryName
    readonly property bool isCategorized: categoryName?.length > 0
    property int maxBindWidth: 0
    property real columnSpacing: 20
    property real titleSpacing: 4

    // Excellent symbol explaination and source :
    // http://xahlee.info/comp/unicode_computing_symbols.html
    // https://www.nerdfonts.com/cheat-sheet
    property var macSymbolMap: ({
        "Ctrl": "󰘴",
        "Alt": "󰘵",
        "Shift": "󰘶",
        "Space": "󱁐",
        "Tab": "↹",
        "Equal": "󰇼",
        "Minus": "",
        "Print": "",
        "BackSpace": "󰭜",
        "Delete": "⌦",
        "Return": "󰌑",
        "Period": ".",
        "Escape": "⎋"
      })
    property var functionSymbolMap: ({
        "F1":  "󱊫",
        "F2":  "󱊬",
        "F3":  "󱊭",
        "F4":  "󱊮",
        "F5":  "󱊯",
        "F6":  "󱊰",
        "F7":  "󱊱",
        "F8":  "󱊲",
        "F9":  "󱊳",
        "F10": "󱊴",
        "F11": "󱊵",
        "F12": "󱊶",
    })

    property var mouseSymbolMap: ({
        "mouse_up": "󱕐",
        "mouse_down": "󱕑",
        "mouse:272": "L󰍽",
        "mouse:273": "R󰍽",
        "Scroll ↑/↓": "󱕒",
        "Page_↑/↓": "⇞/⇟",
    })

    property var keyBlacklist: ["SUPER_L", "SUPER_R"]
    property var keySubstitutions: Object.assign({
        "Super": "",
        "Mouse_up": "Scroll ↓",    // ikr, weird
        "Mouse_down": "Scroll ↑",  // trust me bro
        "Mouse:272": "LMB",
        "Mouse:273": "RMB",
        "Mouse:275": "MouseBack",
        "Slash": "/",
        "Hash": "#",
        "Return": "Enter",
        // "Shift": "",
      },
      !!Config.options.cheatsheet.superKey ? {
          "Super": Config.options.cheatsheet.superKey,
      }: {},
      Config.options.cheatsheet.useMacSymbol ? macSymbolMap : {},
      Config.options.cheatsheet.useFnSymbol ? functionSymbolMap : {},
      Config.options.cheatsheet.useMouseSymbol ? mouseSymbolMap : {},
    )

    function modMaskToStringList(modMask: int): list<string> {
        var list = [];
        // Funny mathematical order but we wanna have this natural user-facing order
        if (modMask & (1 << 2)) { list.push("Ctrl"); }
        if (modMask & (1 << 6)) { list.push("Super"); }
        if (modMask & (1 << 0)) { list.push("Shift"); }
        if (modMask & (1 << 3)) { list.push("Alt"); }
        if (modMask & (1 << 1)) { list.push("Caps"); }
        if (modMask & (1 << 4)) { list.push("Mod2"); }
        if (modMask & (1 << 5)) { list.push("Mod3"); }
        if (modMask & (1 << 7)) { list.push("Mod5"); }
        return list;
    }

    spacing: titleSpacing

    StyledText {
        text: root.isCategorized ? root.categoryName : "Uncategorized"
        font.pixelSize: Appearance.font.pixelSize.title
    }

    function _isDigitKey(k) {
        return k && k.length === 1 && k >= "0" && k <= "9";
    }

    function formatKeyRange(keys) {
        var nums = keys.filter(k => _isDigitKey(k)).map(k => parseInt(k === "0" ? 10 : k));
        nums.sort((a, b) => a - b);
        if (nums.length === 0) return keys.join(",");
        var ranges = [];
        var start = nums[0];
        var end = nums[0];
        for (var i = 1; i < nums.length; i++) {
            if (nums[i] === end + 1) {
                end = nums[i];
            } else {
                ranges.push(start === end ? _rangeLabel(start) : _rangeLabel(start) + "-" + _rangeLabel(end));
                start = nums[i];
                end = nums[i];
            }
        }
        ranges.push(start === end ? _rangeLabel(start) : _rangeLabel(start) + "-" + _rangeLabel(end));
        return "{" + ranges.join(",") + "}";
    }

    function _rangeLabel(n) { return n === 10 ? "0" : String(n); }

    function collapseBinds(binds) {
        if (!binds) return [];
        var groupsMap = {};
        for (var i = 0; i < binds.length; i++) {
            var b = binds[i];
            var key = b.modmask + "|" + b.description;
            if (!groupsMap[key]) groupsMap[key] = [];
            groupsMap[key].push(b);
        }
        var groupKeys = Object.keys(groupsMap);
        var result = [];
        for (var gk = 0; gk < groupKeys.length; gk++) {
            var g = groupsMap[groupKeys[gk]];
            if (g.length > 2 && g.every(x => _isDigitKey(x.key))) {
                var rangeKeys = g.map(x => x.key);
                var collapsed = {
                    modmask: g[0].modmask,
                    key: formatKeyRange(rangeKeys),
                    description: g[0].description,
                    category: g[0].category,
                    _grouped: true,
                };
                result.push(collapsed);
            } else {
                for (var j = 0; j < g.length; j++) {
                    result.push(g[j]);
                }
            }
        }
        return result;
    }

    Column {
        spacing: 2
        Repeater {
            model: {
                var filtered;
                if (!root.isCategorized) {
                    filtered = HyprlandKeybinds.keybinds.filter(bind => !bind.category);
                } else {
                    filtered = HyprlandKeybinds.keybinds.filter(bind => bind.category === root.categoryName);
                }
                return root.collapseBinds(filtered);
            }
            delegate: BindLine {
                required property var modelData
                keyData: modelData
                categoryName: root.categoryName
            }
        }
    }

    component BindLine: Row {
        id: bindLine
        required property var keyData
        property string categoryName: ""

        Row {
            spacing: 16
            Row {
                id: modRow
                Component.onCompleted: root.maxBindWidth = Math.max(root.maxBindWidth, implicitWidth)
                width: root.maxBindWidth
                spacing: 4
                Repeater {
                    model: {
                        const modList = root.modMaskToStringList(bindLine.keyData.modmask).map(mod => root.keySubstitutions[mod] || mod)
                        if (modList.length == 0) return []
                        if (Config.options.cheatsheet.splitButtons) return modList;
                        return [modList.join(" ")]
                    }
                    delegate: KeyboardKey {
                        required property var modelData
                        key: modelData
                        pixelSize: Config.options.cheatsheet.fontSize.key
                    }
                }
                StyledText {
                    id: keybindPlus
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !keyBlacklist.includes(bindLine.keyData.key) && bindLine.keyData.modmask > 0
                    text: "+"
                }
                KeyboardKey {
                    id: keybindKey
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !keyBlacklist.includes(bindLine.keyData.key)
                    key: {
                        const k = StringUtils.toTitleCase(bindLine.keyData.key)
                        return root.keySubstitutions[k] || k
                    }
                    pixelSize: Config.options.cheatsheet.fontSize.key
                    color: Appearance.colors.colOnLayer0
                }
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: commentText.implicitWidth + root.columnSpacing
                implicitHeight: commentText.implicitHeight
                StyledText {
                    id: commentText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    font.pixelSize: Config.options.cheatsheet.fontSize.comment || Appearance.font.pixelSize.smaller
                    text: bindLine.keyData.description || ""
                }
            }
        }
    }
}