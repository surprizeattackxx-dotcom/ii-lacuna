import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property var taskList
    readonly property int taskMargin: 5
    property bool showPopup: false
    
    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38
    implicitHeight: 38
    toggled: (isToday == 1)
    buttonRadius: Appearance.rounding.small
    
    Rectangle {
        width: 8
        height: 8
        radius: Appearance.rounding.full
        color: (taskList.length > 0 && isToday !== -1 && !bold) ? 
               toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary : "transparent"
        anchors {
            top: parent.top
            left: parent.left
            margins: 4
        }
    }
    
    Loader {
        id: popupLoader
        active: button.showPopup
        
        sourceComponent: Item {
            parent: button.QsWindow?.contentItem
            anchors.fill: parent
            
            CalendarPopup {
                id: popup
                
                x: {
                    if (!button.QsWindow) return 0;
                    const buttonPos = button.QsWindow.contentItem.mapFromItem(button, 0, 0);
                    const centeredX = buttonPos.x + (button.width / 2) - (popup.width / 2);
                    return Math.max(0, Math.min(centeredX, parent.width - popup.width));
                }
                
                y: {
                    if (!button.QsWindow) return 0;
                    const buttonPos = button.QsWindow.contentItem.mapFromItem(button, 0, 0);
                    return buttonPos.y - popup.height - 4;
                }
            }
            
        }
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            if (button.taskList.length > 0 && button.isToday !== -1 && !button.bold) {
                button.showPopup = true
            }
        }
        onExited: button.showPopup = false
    }
    
    StyledText {
        anchors.centerIn: parent
        text: day
        horizontalAlignment: Text.AlignHCenter
        font.weight: bold ? Font.DemiBold : Font.Normal
        color: (isToday == 1) ? Appearance.m3colors.m3onPrimary : (isToday == 0) ? Appearance.colors.colOnLayer1 : Appearance.colors.colOutlineVariant
    }
}
