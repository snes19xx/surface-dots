pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper palettes from utils/palette-gen.sh
Scope {
    id: root

    readonly property string scriptPath:
        Qt.resolvedUrl("../utils/palette-gen.sh").toString().replace("file://", "")
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell"
    readonly property string changedPath: cacheDir + "/wallpaper_changed"

    property bool _available: false
    property bool _busy: false
    property bool _again: false
    property int  _cycle: 0
    property bool _warned: false
    property bool _watchReady: false
    property bool _loadRequested: false
    property var  _data: null
    property string _wallpaper: ""

    readonly property bool available: _available
    readonly property bool busy: _busy
    readonly property bool ready: _data !== null
    readonly property string wallpaper: _wallpaper
    readonly property var seeds: _data ? _data.seeds : []
    readonly property int seedIndex: _data ? _data.seed : 0

    readonly property var schemeIds: ["tonal-spot", "vibrant", "expressive", "fidelity",
        "content", "neutral", "monochrome", "rainbow", "fruit-salad"]

    function schemeName(id) {
        var s = String(id).replace(/-/g, " ")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    function colors(schemeId, dark) {
        if (!_data || !_data.schemes || !_data.schemes[schemeId]) return ({})
        return _data.schemes[schemeId][dark ? "dark" : "light"] || ({})
    }

    // "" means the caller should use its own colour
    function role(name, dark) {
        if (!ready) return ""
        var ov = (Configuration.paletteOverrides || ({}))[dark ? "dark" : "light"]
        if (ov && /^#[0-9a-fA-F]{6}$/.test(String(ov[name]))) return ov[name]
        var c = colors(Configuration.paletteScheme, dark)[name]
        if (c === undefined) c = colors("tonal-spot", dark)[name]
        return c === undefined ? "" : c
    }

    // the palette panel wants previews even when the feature is off
    function ensureLoaded() {
        _loadRequested = true
        if (_available && !ready) refresh()
    }

    function refresh() {
        if (!_available) return
        // a process that's still exiting counts as busy, otherwise its late output looks like this run's
        if (_busy || wpProc.running || genProc.running) { _again = true; return }
        _busy = true
        _cycle++
        guard.restart()
        wpProc.cycle = _cycle
        wpProc.running = true
    }

    function _retry() {
        if (_again && !_busy && !wpProc.running && !genProc.running) {
            _again = false
            refresh()
        }
    }

    function _fail(msg) {
        if (!_warned) console.warn("[PaletteService]", msg)
        _warned = true
    }

    function _finish() {
        _busy = false
        guard.stop()
        _retry()
    }

    // FileView can only watch a file that exists, so this creates it too
    Process {
        id: ensureProc
        command: ["bash", "-c",
            "mkdir -p '" + root.cacheDir + "'; [ -e '" + root.changedPath + "' ] || touch '" + root.changedPath + "'; " +
            "command -v matugen >/dev/null && command -v jq >/dev/null"]
        onExited: (code) => {
            root._available = code === 0
            root._watchReady = true
            if (root._available && (Configuration.useWallpaperColors || root._loadRequested)) root.refresh()
        }
    }

    Process {
        id: wpProc
        // wallpaper on the focused monitor, or the first one if that doesn't match
        command: ["bash", "-c",
            "mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null | head -1); " +
            "q=$(awww query 2>/dev/null); " +
            "p=$(printf '%s\\n' \"$q\" | grep -F -- \": $mon:\" | sed -n 's/.*image: //p' | head -1); " +
            "[ -n \"$p\" ] || p=$(printf '%s\\n' \"$q\" | sed -n 's/.*image: //p' | head -1); " +
            "printf '%s\\n' \"$p\""]
        property int cycle: -1
        onExited: root._retry()
        stdout: StdioCollector {
            onStreamFinished: {
                if (wpProc.cycle !== root._cycle) return
                var path = String(this.text || "").trim()
                if (path === "") {
                    root._fail("no wallpaper path from awww")
                    root._finish()
                    return
                }
                root._wallpaper = path
                genProc.command = [root.scriptPath, path, String(Configuration.paletteSeed)]
                genProc.cycle = root._cycle
                genProc.running = true
            }
        }
    }

    Process {
        id: genProc
        property int cycle: -1
        onExited: root._retry()
        stdout: StdioCollector {
            onStreamFinished: {
                if (genProc.cycle !== root._cycle) return
                var d = null
                try { d = JSON.parse(String(this.text || "").trim()) } catch (e) { d = null }
                if (d && d.schemes && d.seeds && d.seeds.length > 0) {
                    root._data = d
                    root._warned = false
                } else {
                    // keep whatever palette is already loaded
                    root._fail("palette-gen.sh failed for " + root._wallpaper)
                }
                root._finish()
            }
        }
    }

    // a stuck matugen would otherwise block every refresh after it.
    // bumping _cycle means whatever the killed processes still print gets ignored
    Timer {
        id: guard
        interval: 20000
        onTriggered: {
            root._cycle++
            wpProc.running = false
            genProc.running = false
            root._fail("palette generation timed out")
            root._busy = false
            root._retry()
        }
    }

    FileView {
        path: root._watchReady ? root.changedPath : ""
        watchChanges: true
        onFileChanged: debounce.restart()
    }

    // the file gets touched right as awww switches, so wait a bit before asking it
    Timer {
        id: debounce
        interval: 300
        onTriggered: if (Configuration.useWallpaperColors || root.ready) root.refresh()
    }

    Connections {
        target: Configuration
        function onUseWallpaperColorsChanged() {
            if (Configuration.useWallpaperColors) root.refresh()
        }
        function onPaletteSeedChanged() {
            // the seed also changes when settings load, that shouldn't wake it up
            if (Configuration.useWallpaperColors || root.ready) root.refresh()
        }
    }

    Component.onCompleted: ensureProc.running = true
}
