pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string _dir: ""
    property int _max: 0
    property int _raw: -1

    readonly property string dir: _dir
    readonly property int maxValue: _max
    readonly property bool available: dir !== "" && maxValue > 0 && _raw >= 0
    readonly property int percent: available ? Math.round(_raw * 100 / maxValue) : -1

    function set(pct) {
        if (!root.available) return
        // Floor of 1 so a drag can't black out the screen
        const p = Math.max(1, Math.min(100, Math.round(pct)))
        Quickshell.execDetached(["brightnessctl", "set", p + "%"])
    }

    // First backlight device, not hard-coded
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = String(this.text).trim()
                if (n !== "") root._dir = "/sys/class/backlight/" + n
            }
        }
    }

    FileView {
        id: maxFile
        path: root.dir !== "" ? root.dir + "/max_brightness" : ""
        preload: true
        onTextChanged: root._max = parseInt(String(text()).trim(), 10) || 0
    }

    // actual_brightness often fires no inotify, brightness does
    FileView {
        id: curFile
        path: root.dir !== "" ? root.dir + "/brightness" : ""
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onTextChanged: {
            const v = parseInt(String(text()).trim(), 10)
            root._raw = isNaN(v) ? -1 : v
        }
    }
}
