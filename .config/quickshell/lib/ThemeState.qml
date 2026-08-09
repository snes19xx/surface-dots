pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string scriptPath:
        Qt.resolvedUrl("../utils/theme-mode.sh").toString().replace("file://", "")
    readonly property string statePath:
        Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"

    property bool isDarkMode: true

    // The script rewrites the state file, which would echo back and undo an
    // in-flight toggle, so ignore the watcher until the write has settled
    property bool _toggling: false

    function _read() {
        if (root._toggling) return
        root.isDarkMode = String(watcher.text() || "").trim().toLowerCase() !== "light"
    }

    function toggle() {
        var next = root.isDarkMode ? "light" : "dark"
        root._toggling = true
        root.isDarkMode = next === "dark"
        Quickshell.execDetached(["bash", root.scriptPath, next])
        settle.restart()
    }

    FileView {
        id: watcher
        path: root.statePath
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onTextChanged: root._read()
        onLoaded: root._read()
        onLoadFailed: root.isDarkMode = true
    }

    Timer {
        id: settle
        interval: 500
        onTriggered: root._toggling = false
    }
}
