pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history on cliphist, also runs the wl-paste watchers
Scope {
    id: root

    readonly property bool available: _available
    // Newest first: [{ id, preview, isImage, thumb }]
    readonly property var entries: _entries

    property bool _available: false
    property bool _watch: false
    property var _entries: []
    // ids with a png on disk, kept across reloads so thumbs don't flicker
    property var _decoded: ({})

    readonly property string _thumbDir: Quickshell.env("HOME") + "/.cache/quickshell/clip"
    readonly property int _thumbLimit: 30
    readonly property var _idRe: /^\d+$/

    function reload() {
        if (!_available) return
        lister.running = false
        lister.running = true
    }

    // Ids go in as argv, never spliced into the script
    function copy(id) {
        id = String(id)
        if (!_idRe.test(id)) return
        Quickshell.execDetached(["bash", "-c", 'cliphist decode "$1" | wl-copy', "sh", id])
    }

    function remove(id) {
        id = String(id)
        if (!_idRe.test(id)) return
        _entries = _entries.filter(e => e.id !== id)
        // delete wants list lines, only reads the id before the tab
        job.createObject(root, { command: ["bash", "-c",
            'printf "%s\\t\\n" "$1" | cliphist delete; rm -f "$2/$1.png"', "sh", id, _thumbDir] })
    }

    function wipe() {
        _entries = []
        _decoded = ({})
        job.createObject(root, { command: ["bash", "-c",
            'cliphist wipe; rm -rf "$1"', "sh", _thumbDir] })
    }

    // "<id>\t<preview>", the id is digits so the first tab is the separator
    function _parse(text) {
        var out = []
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            var tab = line.indexOf("\t")
            if (tab <= 0) continue
            var id = line.substring(0, tab)
            if (!_idRe.test(id)) continue
            var preview = line.substring(tab + 1)
            var isImage = /^\[\[ binary data .* \]\]$/.test(preview)
            out.push({ id: id, preview: preview, isImage: isImage,
                       thumb: (isImage && _decoded[id]) ? _thumbUrl(id) : "" })
        }
        return out
    }

    // Encoded so a HOME with # or % still loads
    function _thumbUrl(id) {
        return "file://" + _thumbDir.split("/").map(encodeURIComponent).join("/") + "/" + id + ".png"
    }

    function _decodeThumbs() {
        var ids = []
        for (var i = 0; i < _entries.length && ids.length < _thumbLimit; i++)
            if (_entries[i].isImage) ids.push(_entries[i].id)
        if (ids.length === 0) return
        decoder.command = ["bash", "-c",
            'd=$1; shift; mkdir -p "$d"; find "$d" -type f -mtime +7 -delete; '
            + 'for id; do [ -s "$d/$id.png" ] || cliphist decode "$id" > "$d/$id.png"; '
            + '[ -s "$d/$id.png" ] && echo "$id"; done', "sh", _thumbDir].concat(ids)
        decoder.running = false
        decoder.running = true
    }

    // Exit 0: start our watchers. 3: someone else runs one. 2: tools missing
    // (^|/) since Quickshell runs /usr/bin/wl-paste and exec-once runs plain wl-paste
    Process {
        id: probe
        command: ["bash", "-c",
            "command -v cliphist >/dev/null && command -v wl-paste >/dev/null "
            + "&& command -v wl-copy >/dev/null || exit 2; "
            + "pgrep -f '(^|/)wl-paste .*--watch cliphist' >/dev/null && exit 3; exit 0"]
        onExited: (code, status) => {
            root._available = (code === 0 || code === 3)
            if (code === 0) root._watch = true
            // On a hot reload the old watchers die right after the first probe, so look again
            else if (code === 3 && !root._rechecked) recheck.start()
            if (root._available) root.reload()
        }
    }

    property bool _rechecked: false
    Timer {
        id: recheck
        interval: 1500
        onTriggered: { root._rechecked = true; probe.running = true }
    }

    Process {
        id: textWatch
        running: root._watch
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
    }

    Process {
        id: imageWatch
        running: root._watch
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._entries = root._parse(this.text)
                root._decodeThumbs()
            }
        }
    }

    Process {
        id: decoder
        stdout: StdioCollector {
            onStreamFinished: {
                var done = String(this.text).split("\n").filter(s => s.length > 0)
                var map = ({})
                for (var i = 0; i < done.length; i++) map[done[i]] = true
                root._decoded = map
                root._entries = root._entries.map(e => {
                    if (!e.isImage) return e
                    var t = map[e.id] ? root._thumbUrl(e.id) : ""
                    return t === e.thumb ? e : Object.assign({}, e, { thumb: t })
                })
            }
        }
    }

    Component {
        id: job
        Process {
            id: j
            running: true
            onExited: { root.reload(); j.destroy() }
        }
    }

    Component.onCompleted: probe.running = true
}
