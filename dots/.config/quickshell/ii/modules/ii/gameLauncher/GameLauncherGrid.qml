import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import Quickshell

Item {
    id: root

    property var model: []
    property int currentIndex: -1
    property bool navActive: false
    signal launchRequested(var gameData)
    signal contextRequested(var gameData, real globalX, real globalY)

    function focusSearch() {}
    function selectFirst() {
        gridView.currentIndex = 0
        gridView.focus = true
    }
    function ensureSelected() {
        root.navActive = true
        if (gridView.currentIndex < 0) gridView.currentIndex = 0
    }
    function navUp() { root.navActive = true; gridView.moveCurrentIndexUp() }
    function navDown() { root.navActive = true; gridView.moveCurrentIndexDown() }
    function navLeft() { root.navActive = true; gridView.moveCurrentIndexLeft() }
    function navRight() { root.navActive = true; gridView.moveCurrentIndexRight() }
    function activate() {
        var it = root.model[gridView.currentIndex]
        if (it) root.launchRequested(it)
    }
    function selectedGame() { return root.model[gridView.currentIndex] }

    function letterOf(name) {
        if (!name || name.length === 0) return "#"
        var c = name.charAt(0).toUpperCase()
        return (c >= "A" && c <= "Z") ? c : "#"
    }
    function jumpToLetter(L) {
        for (var i = 0; i < root.model.length; i++) {
            if (root.letterOf(root.model[i].name) === L) {
                root.navActive = true
                gridView.currentIndex = i
                gridView.positionViewAtIndex(i, GridView.Beginning)
                return
            }
        }
    }

    readonly property var letters: "#ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("")
    readonly property bool showIndex: root.model.length > 25
    readonly property int columns: Math.max(1, Math.floor(gridView.width / gridView.cellWidth))
    readonly property int topIndex: Math.floor(gridView.contentY / gridView.cellHeight) * root.columns
    readonly property int refIndex: (root.navActive && gridView.currentIndex >= 0) ? gridView.currentIndex : root.topIndex
    readonly property string currentLetter: {
        if (root.model.length === 0) return ""
        var i = Math.min(Math.max(root.refIndex, 0), root.model.length - 1)
        return root.model[i] ? root.letterOf(root.model[i].name) : ""
    }
    readonly property var letterSet: {
        var s = ({})
        for (var i = 0; i < root.model.length; i++)
            s[root.letterOf(root.model[i].name)] = true
        return s
    }

    GridView {
        id: gridView
        anchors.fill: parent
        anchors.rightMargin: root.showIndex ? 26 : 0
        clip: true

        readonly property int cellW: 200
        readonly property int cellH: 320
        cellWidth: cellW
        cellHeight: cellH

        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        focus: true

        model: root.model

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
            required property var modelData
            required property int index

            width: gridView.cellWidth
            height: gridView.cellHeight

            GameCard {
                anchors.centerIn: parent
                gameData: modelData
                externalSelected: (root.navActive || gridView.activeFocus) && gridView.currentIndex === parent.index
                onClicked: root.launchRequested(modelData)
                onContextRequested: (gx, gy) => root.contextRequested(modelData, gx, gy)
            }
        }

        highlight: Item {}
        highlightMoveDuration: 0
        keyNavigationEnabled: true
        keyNavigationWraps: false

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Up && gridView.currentIndex < (gridView.width / gridView.cellWidth)) {
                root.focusSearch()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                var item = root.model[gridView.currentIndex]
                if (item) root.launchRequested(item)
                event.accepted = true
            }
        }

        onCurrentIndexChanged: root.currentIndex = gridView.currentIndex
    }

    // ---- A-Z fast-scroll index ----
    property bool bubbleVisible: false
    Timer { id: bubbleHide; interval: 900; onTriggered: root.bubbleVisible = false }
    function flashBubble() { root.bubbleVisible = true; bubbleHide.restart() }

    Connections {
        target: gridView
        function onContentYChanged() { if (root.showIndex) root.flashBubble() }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: alphaColumn.height + 12
        radius: Appearance.rounding.full
        color: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainerHigh, 0.25)
        visible: root.showIndex
    }

    Column {
        id: alphaColumn
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        visible: root.showIndex

        Repeater {
            model: root.letters

            delegate: Item {
                required property string modelData
                width: 22
                height: Math.max(15, (gridView.height - 12) / root.letters.length)

                readonly property bool present: root.letterSet[modelData] === true
                readonly property bool current: root.currentLetter === modelData

                StyledText {
                    anchors.centerIn: parent
                    text: parent.modelData
                    font.pixelSize: parent.current ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.smallest
                    font.weight: parent.current ? Font.Bold : Font.Normal
                    color: parent.current
                        ? Appearance.m3colors.m3primary
                        : (parent.present ? Appearance.m3colors.m3onSurfaceVariant : Appearance.m3colors.m3outlineVariant)
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.present
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.jumpToLetter(parent.modelData)
                }
            }
        }
    }

    // ---- big current-letter bubble (flashes while scrolling) ----
    Rectangle {
        anchors.centerIn: parent
        width: 104
        height: 104
        radius: Appearance.rounding.large
        color: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainerHighest, 0.1)
        visible: opacity > 0
        opacity: (root.showIndex && root.bubbleVisible && root.currentLetter.length > 0) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        StyledText {
            anchors.centerIn: parent
            text: root.currentLetter
            color: Appearance.m3colors.m3primary
            font.pixelSize: 56
            font.weight: Font.Bold
        }
    }
}
