//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root

    width: 980
    height: 720
    minimumWidth: 760
    minimumHeight: 560
    visible: true
    title: "Quickshell Learning Project" // EDIT ME: change this title to anything you want

    // WHAT THIS MEANS:
    // A property is a value the window can keep track of.
    // When the value changes, the screen updates by itself.
    property bool darkMode: true
    property int clickCount: 0
    property string greeting: "Hello"
    property string learnerName: "friend"

    color: darkMode ? "#171717" : "#f6f2ea" // EDIT ME: try different background colors here

    Rectangle {
        anchors.fill: parent
        anchors.margins: 24
        radius: 24
        color: darkMode ? "#222222" : "#ffffff"
        border.width: 1
        border.color: darkMode ? "#3a3a3a" : "#d7d0c6"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Quickshell learning project"
                        color: darkMode ? "#f3efe7" : "#241f1a"
                        font.pixelSize: 30
                        font.bold: true
                    }

                    Text {
                        text: "Built for someone starting from zero."
                        color: darkMode ? "#c1b9ad" : "#665c51"
                        font.pixelSize: 15
                    }
                }

                Button {
                    text: darkMode ? "Switch to light" : "Switch to dark"
                    onClicked: darkMode = !darkMode
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 20
                color: darkMode ? "#2c2c2c" : "#f3ede3"
                border.width: 1
                border.color: darkMode ? "#444" : "#ddd2c4"
                implicitHeight: contentColumn.implicitHeight + 28

                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    Text {
                        text: "Step 1: change one word"
                        color: darkMode ? "#f3efe7" : "#241f1a"
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Text {
                        text: "Try editing the greeting text in the file. If you change it to your name, the window updates when you reopen it." // TRY THIS
                        color: darkMode ? "#d6d0c5" : "#4f463c"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Label {
                            text: "Greeting:" // EDIT ME: change this label
                            color: darkMode ? "#d6d0c5" : "#4f463c"
                        }

                        TextField {
                            Layout.fillWidth: true
                            text: greeting
                            placeholderText: "Type a word"
                            onTextEdited: greeting = text
                        }
                    }

                    Text {
                        text: greeting + ", " + learnerName + "."
                        color: darkMode ? "#ffffff" : "#1e1711"
                        font.pixelSize: 24
                        font.bold: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 20
                color: darkMode ? "#2c2c2c" : "#f8f4ef"
                border.width: 1
                border.color: darkMode ? "#444" : "#ddd2c4"
                implicitHeight: lessonColumn.implicitHeight + 28

                ColumnLayout {
                    id: lessonColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    Text {
                        text: "Step 2: watch a number change"
                        color: darkMode ? "#f3efe7" : "#241f1a"
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Text {
                        text: "A button can change a number. In QML, that number is called a property. When the property changes, the text changes too." // WHAT THIS MEANS
                        color: darkMode ? "#d6d0c5" : "#4f463c"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Button {
                            text: "Click me" // TRY THIS: change the button label
                            onClicked: clickCount = clickCount + 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Clicked " + clickCount + " time" + (clickCount === 1 ? "" : "s")
                            color: darkMode ? "#f3efe7" : "#241f1a"
                            font.pixelSize: 18
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 20
                color: darkMode ? "#242424" : "#f3ede3"
                border.width: 1
                border.color: darkMode ? "#444" : "#ddd2c4"
                implicitHeight: tipColumn.implicitHeight + 28

                ColumnLayout {
                    id: tipColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10

                    Text {
                        text: "Step 3: what to edit"
                        color: darkMode ? "#f3efe7" : "#241f1a"
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Text {
                        text: "1. Change the window title.\n2. Change the colors.\n3. Change the greeting text.\n4. Change the button label.\n5. Change the number that starts the counter."
                        color: darkMode ? "#d6d0c5" : "#4f463c"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "If you want to learn Quickshell next, we can turn this into a tiny panel with a live clock, a command button, and a status indicator."
                        color: darkMode ? "#c1b9ad" : "#665c51"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
