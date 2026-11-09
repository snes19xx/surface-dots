pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history on cliphist, also runs the wl-paste watchers
Scope {
    id: root

    readonly property bool available: _available
    // Newest first: [{ id, preview, isImage, thumb, kind, label, detail, host, rest, swatch }]
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
        _failed = ({})
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
            // the drawer's ListModel wants every field on every entry
            out.push(Object.assign({ id: id, preview: preview, isImage: isImage,
                       thumb: (isImage && _decoded[id]) ? _thumbUrl(id) : "" },
                       isImage ? _imageInfo(preview) : _classify(preview)))
        }
        return out
    }

    // kind is one of image, link, color, path, code, text. all of it is guessed
    // from the preview text, nothing in there ever gets run
    function _info(kind, label, detail) {
        return { kind: kind, label: label, detail: detail, host: "", rest: "", swatch: "" }
    }

    // "[[ binary data 12 KiB png 800x600 ]]"
    function _imageInfo(p) {
        var m = /^\[\[ binary data (\d+ \w+) (\w+) (\d+)x(\d+) \]\]$/.exec(p)
        if (m) return _info("image", m[2].toUpperCase(), m[3] + " x " + m[4] + " · " + m[1])
        m = /^\[\[ binary data (\d+ \w+)/.exec(p)
        return _info("image", "Image", m ? m[1] : "")
    }

    function _classify(p) {
        var t = p.trim()
        // cliphist cuts previews at 100 chars and puts an ellipsis on the end
        var chars = /…$/.test(p) ? "100+ chars" : t.length + (t.length === 1 ? " char" : " chars")
        var o = _info("text", "Text", chars)
        var m

        if ((m = /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.exec(t))) {
            var h = m[1]
            if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
            if (h.length === 8) h = h.substring(6) + h.substring(0, 6)   // css rrggbbaa to qt aarrggbb
            o = _info("color", "Colour", "")
            o.swatch = "#" + h
        } else if ((m = /^(?:https?|ftp):\/\/([^\/?#\s]+)(\S*)$/i.exec(t))) {
            o = _info("link", "Link", chars)
            o.host = m[1]
            o.rest = m[2]
        } else if (/^(?:~|\.\.?)?\/[\w.\-~@+%\/ ,\[\]]+$/.test(t) && t.length > 1) {
            o = _info("path", "Path", chars)
        } else if (/[{}]|=>|&&|\|\||\$\(|;$|<\/?\w+>|\(\)|::|\b(?:def|function|const|let|var|import|return|class|SELECT)\b|^(?:sudo|git|cd|ls|npm|npx|pip|pacman|yay|paru|systemctl|docker|curl|wget|ssh|rm|mv|cp|cat|grep|mamba|conda|python3?|node|cargo|make|chmod|hyprctl|qs)\s|^\.\/|^\$ /.test(t)) {
            o = _info("code", "Code", chars)
        }
        return o
    }

    // Encoded so a HOME with # or % still loads
    function _thumbUrl(id) {
        return "file://" + _thumbDir.split("/").map(encodeURIComponent).join("/") + "/" + id + ".png"
    }

    // polling reloads every second or so, so the decode job only runs when
    // there's a new image or a minute has passed
    property double _lastDecode: 0
    property var _requested: []
    // ids that failed last time, so they aren't retried on every poll
    property var _failed: ({})

    function _decodeThumbs() {
        var ids = []
        var fresh = false
        for (var i = 0; i < _entries.length && ids.length < _thumbLimit; i++) {
            if (!_entries[i].isImage) continue
            ids.push(_entries[i].id)
            if (!_decoded[_entries[i].id] && !_failed[_entries[i].id]) fresh = true
        }
        if (ids.length === 0) return
        if (!fresh && Date.now() - _lastDecode < 60000) return
        _lastDecode = Date.now()
        _requested = ids
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
                var next = root._parse(this.text)
                // keep the old array if nothing changed, so bindings on entries stay quiet
                if (JSON.stringify(next) !== JSON.stringify(root._entries)) root._entries = next
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
                var bad = Object.assign({}, root._failed)
                for (var r = 0; r < root._requested.length; r++)
                    if (!map[root._requested[r]]) bad[root._requested[r]] = true
                root._failed = bad
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
