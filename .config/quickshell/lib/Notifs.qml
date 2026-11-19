pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification server, also keeps a short history for the hub
Scope {
    id: root

    readonly property bool active: !_foreignOwner
    // hides toasts but the history still fills, critical ones always show
    property bool dnd: false
    readonly property var popups: _popups
    // one row per app, newest first: { key, nId (-1 once gone), app,
    // summary, body (plain text), iconSource, image, time, count }
    readonly property ListModel history: _history
    property int historyRevision: 0
    property double clock: Date.now()
    // newest first: { key, nid, more }
    readonly property var stacks: _stacksOf(_popups)

    readonly property int maxPopups: 4
    readonly property int maxHistory: 50
    readonly property int defaultTimeoutMs: 5000
    // Cap on sender timeouts
    readonly property int maxTimeoutMs: 10000
    // Covered toast expiry delay
    readonly property int previewMs: 2000

    property var _popups: []
    property var _arrived: ({})
    // Arrivals since the card appeared
    property var _burst: ({})
    property bool _foreignOwner: false

    ListModel { id: _history }

    function dismissPopup(id) {
        var n = find(id)
        _dropPopup(id)
        if (n) n.dismiss()
    }

    // expire instead of dismiss, otherwise the sender thinks the user closed it
    function expirePopup(id) {
        var n = find(id)
        _dropPopup(id)
        if (n) n.expire()
    }

    function dismissStack(id) {
        var ids = _stackMates(id)
        for (var i = 0; i < ids.length; i++) dismissPopup(ids[i])
    }

    function expireStack(id) {
        var ids = _stackMates(id)
        for (var i = 0; i < ids.length; i++) expirePopup(ids[i])
    }

    function dismissKey(key) {
        for (var i = 0; i < _history.count; i++) {
            if (_history.get(i).key === key) { _history.remove(i); break }
        }
        _historyChanged()
        var live = _popups.filter(p => stackKey(p) === key)
        for (var k = 0; k < live.length; k++) dismissPopup(live[k].id)
    }

    // "now", "5m", "2h", "3d"
    function ageText(time) {
        var m = Math.floor((clock - time) / 60000)
        if (m < 1) return "now"
        if (m < 60) return m + "m"
        if (m < 1440) return Math.floor(m / 60) + "h"
        return Math.floor(m / 1440) + "d"
    }

    function clearAll() {
        _history.clear()
        _historyChanged()
        var live = _popups
        _burst = {}
        _arrived = {}
        _popups = []
        for (var i = 0; i < live.length; i++) live[i].dismiss()
    }

    function find(id) {
        for (var i = 0; i < _popups.length; i++) {
            if (_popups[i].id === id) return _popups[i]
        }
        return null
    }

    // ms, 0 for never
    function popupTimeout(n) {
        if (!n || n.urgency === NotificationUrgency.Critical) return 0
        return n.expireTimeout > 0
            ? Math.min(Math.round(n.expireTimeout * 1000), maxTimeoutMs)
            : defaultTimeoutMs
    }

    // Critical ones never stack
    function stackKey(n) {
        if (n.urgency === NotificationUrgency.Critical) return "critical:" + n.id
        return n.appName !== "" ? n.appName : "System"
    }

    function _stacksOf(list) {
        var out = []
        var at = {}
        for (var i = 0; i < list.length; i++) {
            var key = stackKey(list[i])
            if (at[key] !== undefined) continue
            at[key] = out.length
            // Counts arrivals, not live popups
            out.push({ key: key, nid: list[i].id, more: Math.max(0, (_burst[key] || 1) - 1) })
        }
        return out
    }

    function _stackMates(id) {
        var n = find(id)
        if (!n) return [id]
        var key = stackKey(n)
        return _popups.filter(p => stackKey(p) === key).map(p => p.id)
    }

    function _expireCovered() {
        var tops = stacks.map(s => s.nid)
        var now = Date.now()
        var live = _popups.slice()
        for (var i = 0; i < live.length; i++) {
            var id = live[i].id
            if (tops.indexOf(id) < 0 && now - (_arrived[id] || 0) >= previewMs) expirePopup(id)
        }
    }

    function plainText(s) {
        return String(s || "")
            .replace(/<br\s*\/?>/gi, " ")
            .replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'")
            .replace(/&amp;/g, "&")
            .replace(/\s+/g, " ").trim()
    }

    function _dropPopup(id) {
        var n = find(id)
        if (n === null) return
        var key = stackKey(n)
        delete _arrived[id]
        var rest = _popups.filter(p => p.id !== id)
        if (!rest.some(p => stackKey(p) === key)) delete _burst[key]
        _popups = rest
    }

    // Skips pixel data, freed on close
    function _iconFor(n) {
        var name = n.appIcon
        if (name.charAt(0) === "/") return "file://" + name
        if (name.indexOf("file://") === 0) return name
        if (name !== "" && name.indexOf("://") < 0) {
            var themed = Quickshell.iconPath(name, true)
            if (themed !== "") return themed
        }
        var entry = null
        if (n.desktopEntry !== "") entry = DesktopEntries.byId(n.desktopEntry)
        if (!entry && n.appName !== "") entry = DesktopEntries.heuristicLookup(n.appName)
        if (entry && entry.icon !== "") return Quickshell.iconPath(entry.icon, true)
        return ""
    }

    function _imageFor(n) {
        var src = n.image
        if (src.charAt(0) === "/") return "file://" + src
        return src.indexOf("file://") === 0 ? src : ""
    }

    function _historyEntry(n, count) {
        return {
            key: stackKey(n),
            nId: n.id,
            app: n.appName !== "" ? n.appName : "SYSTEM",
            summary: n.summary !== "" ? n.summary : "Notification",
            body: plainText(n.body),
            iconSource: _iconFor(n),
            image: _imageFor(n),
            time: Date.now(),
            count: count
        }
    }

    // apps can update a notification that's still up, the history row follows it
    function _syncHistory(n) {
        for (var i = 0; i < _history.count; i++) {
            var row = _history.get(i)
            if (row.nId === n.id) {
                _history.set(i, _historyEntry(n, row.count))
                _historyChanged()
                return
            }
        }
    }

    function _historyChanged() {
        historyRevision++
        saveTimer.restart()
    }

    // critical ones are never dropped
    function _trimPopups() {
        while (stacks.length > maxPopups) {
            var all = stacks
            var at = -1
            for (var i = all.length - 1; i >= 0; i--) {
                if (all[i].key.indexOf("critical:") !== 0) { at = i; break }
            }
            if (at < 0) return
            expireStack(all[at].nid)
        }
    }

    // One pass, never rescanned, so split fragments can't form a tag.
    readonly property var _allowedTag: /^(<\/?[biu]>|<br\s*\/?>|<\/a>|<a\s+href\s*=\s*(["'])(https?:\/\/|mailto:)[^"'<>]*\2\s*>)/i

    function safeBody(s) {
        s = String(s || "")
        var out = ""
        for (var i = 0; i < s.length; i++) {
            var ch = s.charAt(i)
            if (ch !== "<") { out += ch; continue }
            var m = _allowedTag.exec(s.slice(i, i + 600))
            if (m) { out += m[0]; i += m[0].length - 1 }
            else out += "&lt;"
        }
        return out
    }

    function _watch(n) {
        var id = n.id
        n.closed.connect(() => root._dropPopup(id))
        n.summaryChanged.connect(() => root._syncHistory(n))
        n.bodyChanged.connect(() => root._syncHistory(n))
        n.appNameChanged.connect(() => root._syncHistory(n))
        n.appIconChanged.connect(() => root._syncHistory(n))
        n.imageChanged.connect(() => root._syncHistory(n))
    }

    function _pushHistory(n) {
        // reused id moves to top
        var key = stackKey(n)
        var count = 1
        for (var i = 0; i < _history.count; i++) {
            var row = _history.get(i)
            if (row.key === key || row.nId === n.id) {
                count = row.nId === n.id ? row.count : row.count + 1
                _history.remove(i)
                break
            }
        }
        _history.insert(0, _historyEntry(n, count))
        while (_history.count > maxHistory) _history.remove(_history.count - 1)
        _historyChanged()
    }

    function _onNotification(n) {
        n.tracked = true
        var id = n.id
        var critical = n.urgency === NotificationUrgency.Critical

        _pushHistory(n)

        if (dnd && !critical) {
            // nothing is going to show it, so let the sender know it's gone
            n.expire()
            return
        }

        _watch(n)
        _arrived[id] = Date.now()

        // reused id keeps its slot
        for (var i = 0; i < _popups.length; i++) {
            if (_popups[i].id === id) {
                var next = _popups.slice()
                next[i] = n
                _popups = next
                return
            }
        }

        var key = stackKey(n)
        _burst[key] = (_burst[key] || 0) + 1
        _popups = [n].concat(_popups)
        _trimPopups()
    }

    // Notifications survive a reload, so they go back to history without toasts.
    function _restore() {
        var live = server.trackedNotifications.values
        var liveIds = live.map(n => n.id)
        for (var i = 0; i < live.length; i++) {
            var n = live[i]
            _watch(n)
            var known = false
            for (var k = 0; k < _history.count; k++) {
                if (_history.get(k).nId === n.id) { known = true; break }
            }
            if (!known) _pushHistory(n)
            n.expire()
        }
        // Ids restart with the daemon
        for (var r = 0; r < _history.count; r++) {
            if (liveIds.indexOf(_history.get(r).nId) < 0) _history.setProperty(r, "nId", -1)
        }
    }

    function _loadHistory() {
        var rows = []
        try { rows = JSON.parse(historyFile.text() || "[]") } catch (e) { rows = [] }
        if (!Array.isArray(rows)) return
        _history.clear()
        for (var i = 0; i < rows.length && i < maxHistory; i++) {
            var r = rows[i]
            if (!r || typeof r.key !== "string") continue
            _history.append({
                key: r.key,
                nId: typeof r.nId === "number" ? r.nId : -1,
                app: String(r.app || "SYSTEM"),
                summary: String(r.summary || "Notification"),
                body: String(r.body || ""),
                iconSource: String(r.iconSource || ""),
                image: String(r.image || ""),
                time: Number(r.time) || Date.now(),
                count: Math.max(1, Number(r.count) || 1)
            })
        }
    }

    function _saveHistory() {
        var rows = []
        for (var i = 0; i < _history.count; i++) {
            var r = _history.get(i)
            rows.push({ key: r.key, nId: r.nId, app: r.app, summary: r.summary, body: r.body,
                        iconSource: r.iconSource, image: r.image, time: r.time, count: r.count })
        }
        historyFile.setText(JSON.stringify(rows))
    }

    Component.onCompleted: {
        _loadHistory()
        _restore()
        _historyChanged()
    }

    FileView {
        id: historyFile
        path: Quickshell.statePath("notification-history.json")
        blockLoading: true
        printErrors: false
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: root._saveHistory()
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.clock = Date.now()
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        // safeBody drops img tags
        bodyImagesSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => root._onNotification(n)
    }

    // quickshell doesn't say when registering fails, so compare the bus name owner's pid with ours
    Process {
        id: probe
        command: ["bash", "-c",
            'call() { busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus "$@" 2>/dev/null; }; '
            + 'owner=$(call GetNameOwner s org.freedesktop.Notifications | cut -d\\" -f2); '
            + '[ -n "$owner" ] || exit 0; '
            + 'pid=$(call GetConnectionUnixProcessID s "$owner" | cut -d" " -f2); '
            + '[ "$pid" = "$1" ] && echo self || echo other',
            "sh", String(Quickshell.processId)]
        stdout: StdioCollector {
            onStreamFinished: {
                var other = this.text.trim() === "other"
                if (other && !root._foreignOwner)
                    console.warn("[Notifs] another notification daemon owns the bus name, stop it (dunst?) to get toasts here")
                root._foreignOwner = other
            }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root._popups.length > root.stacks.length
        onTriggered: root._expireCovered()
    }

    // one check after startup, then poll only while someone else owns the name
    Timer {
        interval: 1500
        running: true
        onTriggered: probe.running = true
    }
    Timer {
        interval: 5000
        repeat: true
        running: root._foreignOwner
        onTriggered: { probe.running = false; probe.running = true }
    }
}
