import qs.modules.common.widgets
import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string text: ""
    property string icon
    property alias value: spinBoxWidget.value
    property alias stepSize: spinBoxWidget.stepSize
    property alias from: spinBoxWidget.from
    property alias to: spinBoxWidget.to
    
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight

    HighlightOverlay {
        id: highlightOverlay
        anchors.fill: parent
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 0

        /// Search Registry ///
        Component.onCompleted: {
            if (page?.register == false) return
            let section = SearchRegistry.findSection(root)
            if (section && text) section.addKeyword(text)
        }

        readonly property string currentSearch: SearchRegistry.currentSearch
        onCurrentSearchChanged: {
            if (SearchRegistry.currentSearch.toLowerCase() === root.text.toLowerCase()) {
                highlightOverlay.startAnimation()
                SearchRegistry.currentSearch = ""
            }
        }

        RowLayout {
            spacing: 10
            OptionalMaterialSymbol {
                icon: root.icon
                opacity: root.enabled ? 1 : 0.4
            }
            StyledText {
                id: labelWidget
                Layout.fillWidth: true
                text: root.text
                color: Appearance.colors.colOnSecondaryContainer
                opacity: root.enabled ? 1 : 0.4
            }
        }

        StyledSpinBox {
            id: spinBoxWidget
            Layout.fillWidth: false
            value: root.value
        }
    }
}
