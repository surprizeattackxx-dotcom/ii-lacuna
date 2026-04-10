import qs.modules.common
import qs.modules.common.widgets
import "./cards"
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    // Helper function to format KB to GB
    function formatGB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 12

        HeroCard {
            id: resourcesHero
            Layout.fillWidth: true
            icon: "developer_board"
            title: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
            subtitle: Translation.tr("CPU Load")
            pillText: Translation.tr("System")
            pillIcon: "memory"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: Appearance.colors.colSurfaceContainerHighest
            radius: 1
        }

        RowLayout {
            Layout.fillWidth: true
            ResourceCard {
                title: Translation.tr("CPU")
                icon: "speed"
                shapeString: "Slanted"
                shapeColor: Appearance.colors.colPrimaryContainer
                symbolColor: Appearance.colors.colOnPrimaryContainer

                resourceName: Translation.tr("Load")
                resourceValueText: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                resourcePercentage: ResourceUsage.cpuUsage
                highlightColor: Appearance.colors.colPrimary

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        height: tempRow.implicitHeight + 16
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colSurfaceContainerHigh

                        RowLayout {
                            id: tempRow
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            MaterialSymbol { text: "thermometer"; iconSize: 14; color: Appearance.colors.colPrimary }
                            StyledText { text: Translation.tr("Temp: ") + ResourceUsage.cpuTemp; font.weight: Font.DemiBold; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnSurfaceVariant }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: freqRow.implicitHeight + 16
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colSurfaceContainerHigh

                        RowLayout {
                            id: freqRow
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            MaterialSymbol { text: "bolt"; iconSize: 14; color: Appearance.colors.colPrimary }
                            StyledText { text: Translation.tr("Freq: ") + ResourceUsage.cpuFreq; font.weight: Font.DemiBold; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnSurfaceVariant }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: modelRow.implicitHeight + 16
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colSurfaceContainerHigh

                        RowLayout {
                            id: modelRow
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            MaterialSymbol { text: "memory"; iconSize: 14; color: Appearance.colors.colPrimary }
                            StyledText { text: ResourceUsage.cpuModel; font.weight: Font.DemiBold; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnSurfaceVariant; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1 }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                ResourceCard {
                    title: Translation.tr("RAM")
                    icon: "memory"
                    shapeString: "Clover4Leaf"
                    shapeColor: Appearance.colors.colSecondaryContainer
                    symbolColor: Appearance.colors.colOnSecondaryContainer

                    resourceName: Translation.tr("Used") 
                    resourceValueText: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`
                    resourcePercentage: ResourceUsage.memoryUsedPercentage
                    highlightColor: Appearance.colors.colSecondary
                }
                ResourceCard {
                    title: Translation.tr("Storage")
                    icon: "hard_drive"
                    shapeString: "Cookie9Sided"
                    shapeColor: Appearance.colors.colTertiaryContainer
                    symbolColor: Appearance.colors.colOnTertiaryContainer

                    resourceName: Translation.tr("Disk")
                    resourceValueText: `${root.formatGB(ResourceUsage.diskUsed).split(" ")[0]} / ${root.formatGB(ResourceUsage.diskTotal)}`
                    resourcePercentage: ResourceUsage.diskUsedPercentage
                    highlightColor: Appearance.colors.colTertiary
                }

                
            }
        }
    }
}
