import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "./cards"

StyledPopup {
    id: root

    property bool clipboardActive: false
    open: clipboardActive || popupHovered
    signal closeRequested

    readonly property string previewText: {
        if (Cliphist.entries.length === 0) return Translation.tr("Empty")
        const entry = Cliphist.entries[0].replace(/^\d+\t/, "")
        return entry.length > 40 ? entry.substring(0, 37) + "…" : entry
    }

    contentItem: HeroCard {
        anchors.centerIn: parent
        adaptiveWidth: true
        margins: 20
        iconSize: 100
        icon: "content_paste"
        title: Cliphist.entries.length.toString()
        subtitle: root.previewText
    }
}
