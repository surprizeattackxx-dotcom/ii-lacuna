pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property string activeProfile: ""
    property list<string> profiles: []

    function update() {
        getActiveProc.running = true;
        getProfilesProc.running = true;
    }

    function setProfile(name) {
        setProc.exec(["powerprofilesctl", "set", name]);
    }

    Process {
        id: setProc
        onExited: getActiveProc.running = true
    }

    Process {
        id: getActiveProc
        running: true
        command: ["powerprofilesctl", "get"]
        onExited: (exitCode, exitStatus) => {
            root.available = exitCode === 0;
        }
        stdout: StdioCollector {
            onStreamFinished: root.activeProfile = text.trim()
        }
    }

    Process {
        id: getProfilesProc
        running: true
        command: ["bash", "-c", "powerprofilesctl list | grep -oP '(?<=[ *] )[a-z-]+(?=:)'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.profiles = text.trim().split("\n").filter(l => l.length > 0);
            }
        }
    }
}
