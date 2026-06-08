import qs.modules.common
import qs.modules.common.widgets
import "./cards"
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

StyledPopup {
    id: root

    contentItem: Item {
        id: content
        implicitWidth:  320
        implicitHeight: mainLayout.implicitHeight

        function formatKB(kb)  { return (kb / (1024 * 1024)).toFixed(1) + " GB" }
        function usageColor(r) {
            if (r < 0.60) return Appearance.colors.colSuccess;
            if (r < 0.80) return Appearance.colors.colWarning;
            return Appearance.colors.colError;
        }
        function tempColor(t) {
            if (t <= 65) return Appearance.colors.colSuccess;
            if (t <= 80) return Appearance.colors.colWarning;
            return Appearance.colors.colError;
        }

        property string cpuFreq: "…"
        readonly property string cpuTemp: ResourceUsage.cpuTempString
        readonly property real cpuTempVal: ResourceUsage.cpuTemp
        property string diskUsed:"…"; property string diskFree:"…"; property string diskTotal:"…"; property real diskRatio: 0
        property string gpuLoad:"…"; property string gpuVramUsed:"…"; property string gpuTemp:"…"
        property real   gpuRatio: 0; property real gpuTempVal: 0; property real gpuUsage: 0

        QtObject {
            id: backend
            property var cpuFreqProc: Process {
                command: ["bash","-c","awk '/cpu MHz/{sum+=$4;n++} END{printf \"%.0f\",sum/n}' /proc/cpuinfo"]
                running: true
                stdout: SplitParser { onRead: (l) => { const v=parseFloat(l); if(!isNaN(v)) content.cpuFreq=(v/1000).toFixed(2)+" GHz"; }}
            }
            property var cpuTimer: Timer { interval:3000;repeat:true;running:root.open
                onTriggered: backend.cpuFreqProc.running = true
            }
            property var gpuProc: Process {
                command: ["bash","-c","nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.free,memory.total,temperature.gpu --format=csv,noheader,nounits"]
                running: true
                stdout: SplitParser { onRead: (l) => {
                    const p=l.trim().split(/,\s*/);
                    if(p.length>=5){
                        const load=parseFloat(p[0]),vU=parseFloat(p[1]),vF=parseFloat(p[2]),vT=parseFloat(p[3]),t=parseFloat(p[4]);
                        content.gpuUsage=load/100; content.gpuLoad=load+"%";
                        content.gpuVramUsed=(vU/1024).toFixed(1)+" GB"; content.gpuTemp=t.toFixed(1)+" °C";
                        content.gpuTempVal=t; if(vT>0) content.gpuRatio=vU/vT;
                    }
                }}
            }
            property var gpuTimer: Timer { interval:3000;repeat:true;running:root.open; onTriggered:backend.gpuProc.running=true }
            property var diskProc: Process {
                command: ["bash","-c","df -k / | awk 'NR==2{print $2,$3,$4}'"]
                running: true
                stdout: SplitParser { onRead: (l) => {
                    const p=l.trim().split(/\s+/);
                    if(p.length>=3){
                        const total=parseInt(p[0]),used=parseInt(p[1]),free=parseInt(p[2]);
                        if(total>0){
                            content.diskTotal=(total/(1024*1024)).toFixed(1)+" GB";
                            content.diskUsed=(used/(1024*1024)).toFixed(1)+" GB";
                            content.diskFree=(free/(1024*1024)).toFixed(1)+" GB";
                            content.diskRatio=used/total;
                        }
                    }
                }}
            }
            property var diskTimer: Timer { interval:10000;repeat:true;running:root.open; onTriggered:backend.diskProc.running=true }
        }

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            spacing: 12

            HeroCard {
                icon: "memory"
                title: Math.round(ResourceUsage.cpuUsage * 100) + "%"
                subtitle: "CPU · RAM " + Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
                compactMode: true
                adaptiveWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

            InfoPill {
                icon: "memory"
                text: Translation.tr("RAM: ") + content.formatKB(ResourceUsage.memoryUsed) + " / " + content.formatKB(ResourceUsage.memoryTotal)
                containerColor: Appearance.colors.colSecondaryContainer
                shapeColor: Appearance.m3colors.sapphire
                symbolColor: Appearance.colors.colOnSecondary
                textColor: Appearance.colors.colOnSecondaryContainer
            }
            InfoPill {
                visible: Config.options.bar.tooltips.showSwap && ResourceUsage.swapTotal > 0
                icon: "swap_horiz"
                text: Translation.tr("Swap: ") + content.formatKB(ResourceUsage.swapUsed) + " / " + content.formatKB(ResourceUsage.swapTotal)
                containerColor: Appearance.m3colors.m3primaryContainer
                shapeColor: Appearance.m3colors.mauve
                symbolColor: Appearance.m3colors.m3onPrimary
                textColor: Appearance.m3colors.m3onPrimaryContainer
            }
            InfoPill {
                icon: "speed"
                text: Translation.tr("CPU: ") + Math.round(ResourceUsage.cpuUsage * 100) + "% · " + content.cpuFreq + " · " + content.cpuTemp
                containerColor: Appearance.colors.colTertiaryContainer
                shapeColor: Appearance.m3colors.peach
                symbolColor: Appearance.colors.colOnTertiary
                textColor: Appearance.colors.colOnTertiaryContainer
            }
            InfoPill {
                icon: "manufacturing"
                text: Translation.tr("GPU: ") + content.gpuLoad + " · " + content.gpuVramUsed + " · " + content.gpuTemp
                containerColor: Appearance.m3colors.m3successContainer
                shapeColor: Appearance.m3colors.teal
                symbolColor: Appearance.m3colors.m3onSuccess
                textColor: Appearance.m3colors.m3onSuccessContainer
            }
            InfoPill {
                icon: "storage"
                text: Translation.tr("Disk: ") + content.diskUsed + " / " + content.diskTotal
                containerColor: Appearance.m3colors.m3successContainer
                shapeColor: Appearance.m3colors.green
                symbolColor: Appearance.m3colors.m3onSuccess
                textColor: Appearance.m3colors.m3onSuccessContainer
            }
        }
    }
    }
}
