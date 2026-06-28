import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import "."

ColumnLayout {
    id: root

    readonly property var installedList: {
        let list = []
        for (let id in ExtensionManager.installedExtensions) {
            if (!ExtensionAudit.blockedIds[id]) {
                list.push(ExtensionManager.installedExtensions[id])
            }
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        return list
    }

    property int _updateAllCount: 0
    property int _updateAllDone: 0

    function updateAll() {
        let toUpdate = []
        for (let id in ExtensionManager.installedExtensions) {
            let ext = ExtensionManager.installedExtensions[id]
            if (ext.repoUrl && ext.repoUrl.length > 0 && ext.enabled) {
                let state = ExtensionManager.updateStates[id] || {}
                if (state.updateAvailable) {
                    toUpdate.push(id)
                }
            }
        }
        if (toUpdate.length === 0) return
        root._updateAllCount = toUpdate.length
        root._updateAllDone = 0
        _updateNext(toUpdate)
    }

    function _updateNext(queue) {
        if (queue.length === 0) return
        let id = queue.shift()
        ExtensionManager.updateExtension(id)

        let checkDone = function(extId, available, error) {
            if (extId === id) {
                ExtensionManager.updateCheckDone.disconnect(checkDone)
                root._updateAllDone++
                Qt.callLater(function() { _updateNext(queue) })
            }
        }
        ExtensionManager.updateCheckDone.connect(checkDone)

        let timer = Qt.createQmlObject("import QtQuick; Timer { interval: 30000; repeat: false }", root, "updateTimer")
        timer.triggered.connect(function() {
            timer.destroy()
            ExtensionManager.updateCheckDone.disconnect(checkDone)
            root._updateAllDone++
            Qt.callLater(function() { _updateNext(queue) })
        })
        timer.start()
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: Translation.tr("Installed") + " (" + root.installedList.length + ")"
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer0
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                implicitHeight: 28
                padding: 10
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Check updates")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSecondaryContainer
                }
                onClicked: ExtensionManager.checkAllUpdates()
            }

            RippleButton {
                implicitHeight: 28
                padding: 10
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Update All")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimaryContainer
                }
                onClicked: root.updateAll()
            }

            RippleButton {
                implicitHeight: 28
                padding: 10
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colTertiaryContainer
                colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Clear errors")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnTertiaryContainer
                }
                visible: Object.keys(ExtensionManager.pluginErrors).length > 0
                onClicked: ExtensionManager.clearAllPluginErrors()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: ExtensionManager.error.length > 0
            text: ExtensionManager.error
            color: Appearance.colors.colError
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.installedList
            delegate: InstalledExtensionCard {
                listCount: root.installedList.length
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 40
            visible: root.installedList.length === 0
            text: Translation.tr("No extensions installed. Browse the Available tab to find some.")
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.normal
        }
    }
}
