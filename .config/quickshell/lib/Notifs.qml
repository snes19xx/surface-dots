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
    // newest first: { nId, app, summary, body (plain text), icon, image, time }
    readonly property ListModel history: _history

    readonly property int maxPopups: 5
    readonly property int maxHistory: 50
    readonly property int defaultTimeoutMs: 5000

    property var _popups: []
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

    function dismiss(id) {
        for (var i = 0; i < _history.count; i++) {
            if (_history.get(i).nId === id) { _history.remove(i); break }
        }
        dismissPopup(id)
    }

    function clearAll() {
        _history.clear()
        var live = _popups
        _popups = []
        for (var i = 0; i < live.length; i++) live[i].dismiss()
    }

    function find(id) {
        for (var i = 0; i < _popups.length; i++) {
            if (_popups[i].id === id) return _popups[i]
        }
        return null
    }

    function popupTimeout(n) {
        if (!n || n.urgency === NotificationUrgency.Critical) return 0
        return n.expireTimeout > 0 ? Math.round(n.expireTimeout * 1000) : defaultTimeoutMs
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
        if (find(id) === null) return
        _popups = _popups.filter(p => p.id !== id)
    }

    function _historyEntry(n) {
        return {
            nId: n.id,
            app: n.appName !== "" ? n.appName : "SYSTEM",
            summary: n.summary !== "" ? n.summary : "Notification",
            body: plainText(n.body),
            icon: n.appIcon,
            image: n.image,
            time: Date.now()
        }
    }

    // apps can update a notification that's still up, the history row follows it
    function _syncHistory(n) {
        var e = _historyEntry(n)
        for (var i = 0; i < _history.count; i++) {
            if (_history.get(i).nId === e.nId) {
                _history.set(i, e)
                return
            }
        }
    }

    function _trimPopups() {
        while (_popups.length > maxPopups) {
            var at = _popups.length - 1
            for (var i = _popups.length - 1; i >= 0; i--) {
                if (_popups[i].urgency !== NotificationUrgency.Critical) { at = i; break }
            }
            expirePopup(_popups[at].id)
        }
    }

    function _onNotification(n) {
        n.tracked = true
        var id = n.id
        var critical = n.urgency === NotificationUrgency.Critical

        _history.insert(0, _historyEntry(n))
        while (_history.count > maxHistory) _history.remove(_history.count - 1)

        if (dnd && !critical) {
            // nothing is going to show it, so let the sender know it's gone
            n.expire()
            return
        }

        n.closed.connect(() => root._dropPopup(id))
        n.summaryChanged.connect(() => root._syncHistory(n))
        n.bodyChanged.connect(() => root._syncHistory(n))
        n.appNameChanged.connect(() => root._syncHistory(n))
        n.appIconChanged.connect(() => root._syncHistory(n))
        n.imageChanged.connect(() => root._syncHistory(n))

        _popups = [n].concat(_popups)
        _trimPopups()
    }

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        // the toast strips img tags, so don't advertise inline images
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
