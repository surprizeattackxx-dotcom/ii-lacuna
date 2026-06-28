import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import "."

Item {
    id: root
    required property var modelData
    required property int index

    readonly property var plugin: modelData
    readonly property bool alreadyInstalled: !!ExtensionManager.installedExtensions[plugin.id]
    readonly property bool currentlyInstalling: ExtensionManager.loading
    readonly property string sourceBadgeText: {
        if (plugin.source && plugin.source.url === ExtensionManager.defaultSourceUrl) return Translation.tr("Official")
        if (plugin.sourceName) return plugin.sourceName
        return ""
    }

    Layout.fillWidth: true
    implicitHeight: 90

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1

        RowLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 12

            MaterialShape {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                shapeString: plugin.shapeString || ""
                color: Appearance.colors.colPrimaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: plugin.icon || "extension"
                    iconSize: 28
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    StyledText {
                        text: plugin.displayName || plugin.name
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }
                    ExtensionBadge {
                        label: sourceBadgeText
                        tooltip: Translation.tr("Source: ") + (plugin.source?.url || "")
                        visible: sourceBadgeText.length > 0 && sourceBadgeText !== "Official"
                    }
                    ExtensionBadge {
                        label: Translation.tr("Official")
                        tooltip: sourceBadgeText === "Official" ? Translation.tr("From the default extensions repository") : ""
                        visible: sourceBadgeText === "Official"
                    }
                    ExtensionBadge {
                        label: Translation.tr("Installed")
                        bgColor: Appearance.m3colors.m3successContainer
                        fgColor: Appearance.m3colors.m3success
                        visible: alreadyInstalled
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: plugin.description || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    spacing: 6
                    StyledText {
                        text: "v" + (plugin.version || "?") + " by " + (plugin.author || "unknown")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        visible: plugin.sourceName && plugin.sourceName.length > 0
                        text: "• " + plugin.sourceName
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colTertiary
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            ColumnLayout {
                Layout.fillHeight: true
                spacing: 4

                RippleButton {
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: 80
                    implicitHeight: 28
                    padding: 0
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: Translation.tr("Info")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    onClicked: {
                        let url = plugin.htmlUrl || plugin.repository || plugin.repoUrl || (plugin.source ? plugin.source.url : "") || ""
                        if (url) Qt.openUrlExternally(url)
                    }
                }

                RippleButton {
                    Layout.alignment: Qt.AlignRight
                    enabled: Config.options.extensions.enable && !alreadyInstalled && !currentlyInstalling
                    implicitWidth: 80
                    implicitHeight: 28
                    padding: 0
                    buttonRadius: Appearance.rounding.full
                    colBackground: alreadyInstalled ? Appearance.colors.colLayer3 : Appearance.colors.colPrimaryContainer
                    colBackgroundHover: alreadyInstalled ? Appearance.colors.colLayer3Hover : Appearance.colors.colPrimaryContainerHover
                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: alreadyInstalled ? Translation.tr("Installed") : (currentlyInstalling ? "..." : Translation.tr("Install"))
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: alreadyInstalled ? Appearance.colors.colSubtext : Appearance.colors.colOnPrimaryContainer
                    }
                    onClicked: {
                        let repoUrl = plugin.repository || plugin.repoUrl || (plugin.source ? plugin.source.url : "") || ""
                        let id = plugin.id || ""
                        if (repoUrl) {
                            let htmlUrl = plugin.htmlUrl || (repoUrl + "/tree/main/" + id)
                            ExtensionManager.installExtension(repoUrl, id, plugin.defaultBranch || "main", htmlUrl)
                        }
                    }
                }
            }
        }
    }
}
