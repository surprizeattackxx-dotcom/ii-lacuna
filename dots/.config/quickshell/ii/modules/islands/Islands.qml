import QtQuick
import Quickshell

Scope {
    TopBar {}

    Variants {
        model: Quickshell.screens
        delegate: Component {
            DynamicIsland {
                required property var modelData
                screen: modelData
            }
        }
    }
}
