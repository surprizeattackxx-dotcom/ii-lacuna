import QtQuick
import "./widgets"

DockIcon {
    id: iconContainer
    appId: root.appToplevel?.appId ?? ""
    isRunning: root.appIsRunning
    width: root.buttonSize
    height: root.buttonSize
    anchors.centerIn: parent
}