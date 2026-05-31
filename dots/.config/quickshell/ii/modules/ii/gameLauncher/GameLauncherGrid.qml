import qs.modules.common
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

    GridView {
        id: gridView
        anchors.fill: parent
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
}
