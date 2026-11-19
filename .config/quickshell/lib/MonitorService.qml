pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "MonitorLayout.js" as Layout

Scope {
    id: root

    // STATE
    readonly property string laptopOutput: "eDP-1"
    property var monitors: []              // enabled only
    property var allMonitors: []           // plus switched-off ones
    property var pending: null             // guest waiting for a choice
    property string appliedLayout: ""      // layout awaiting confirm
    property var revertSnapshot: null
    property int revertSeconds: 0
    property var order: []                 // externals, left to right
    property var pendingPair: null         // awaiting a pair choice
    property bool _placeAfter: false

    signal pairConnected(var mons)
    signal guestConnected(var mon)
    signal monitorGone(string name)
    signal knownConnected(var mon)
    signal confirmNeeded(var mon, string layout)
    signal toast(string msg)

    // Descriptions treated as configured screens. 
    property var knownPatterns: []
    property var remembered: ({})          // description -> layout

    // Where the prompt shows. The laptop panel normally, but it is switched off
    // while the monitor is docked, so fall back to whatever screen is focused.
    readonly property string promptOutput: {
        for (var i = 0; i < root.monitors.length; i++)
            if (root.monitors[i].name === root.laptopOutput) return root.laptopOutput
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
            return Hyprland.focusedMonitor.name
        return root.monitors.length ? root.monitors[0].name : root.laptopOutput
    }

    // Descriptions are the stable id, but some screens report an empty one
    function keyFor(m) {
        if (!m) return ""
        return String(m.description || "").length ? m.description : m.name
    }

    function isKnown(desc) {
        var d = String(desc || "")
        for (var i = 0; i < root.knownPatterns.length; i++)
            if (d.indexOf(root.knownPatterns[i]) !== -1) return true
        return false
    }

    function monitorFor(name) {
        for (var i = 0; i < root.monitors.length; i++)
            if (root.monitors[i].name === name) return root.monitors[i]
        return null
    }

    function externals() {
        var out = []
        for (var i = 0; i < root.monitors.length; i++)
            if (root.monitors[i].name !== root.laptopOutput) out.push(root.monitors[i])
        return out
    }

    // DETECTION
    property var _seen: ({})
    property bool _primed: false

    Process {
        id: query
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list = []
                try { list = JSON.parse(this.text || "[]") } catch (e) { return }
                root.allMonitors = list
                list = list.filter(function (m) { return !m.disabled })
                root.monitors = list

                var ext = root.externals()
                var names = []
                for (var k = 0; k < ext.length; k++) names.push(ext[k].name)
                root.order = Layout.reconcileOrder(root.order, names)

                var fresh = {}
                var arrived = []
                for (var i = 0; i < list.length; i++) {
                    var m = list[i]
                    fresh[m.name] = m.description
                    if (!root._primed) continue
                    if (root._seen[m.name] === m.description) continue
                    if (m.name === root.laptopOutput) continue

                    if (ext.length >= 2) { arrived.push(m); continue }

                    var key = root.keyFor(m)
                    if (root.isKnown(m.description)) {
                        root.knownConnected(m)
                    } else if (root.remembered[key]) {
                        root.apply(root.remembered[key], m, false)
                        root.toast(root._shortName(m) + " set to " + root.remembered[key])
                    } else {
                        root.pending = m
                        root.guestConnected(m)
                    }
                }
                var changed = false
                for (var name in root._seen)
                    if (fresh[name] === undefined) { root.monitorGone(name); changed = true }
                for (var n2 in fresh)
                    if (root._seen[n2] === undefined) changed = true

                var wasPrimed = root._primed
                root._seen = fresh
                root._primed = true

                if (ext.length >= 2 && (arrived.length > 0 || !wasPrimed)) {
                    var pkey = Layout.pairKey(ext.map(function (e) { return root.keyFor(e) }))
                    var saved = root.remembered[pkey]
                    if (saved || !wasPrimed) {
                        root.applyAll(saved || "externals", false)
                        if (saved && wasPrimed) root.toast("Displays set to " + saved)
                    } else {
                        root.pendingPair = ext
                        root.pairConnected(ext)
                    }
                } else if (root._placeAfter || (changed && ext.length >= 1)) {
                    root._placeAfter = false
                    root.placeAll()
                }
            }
        }
    }

    function refresh() { query.running = false; query.running = true }
    function refreshSoon() { settle.restart() }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev || !ev.name) return
            if (ev.name === "monitoradded" || ev.name === "monitorremoved"
                || ev.name === "monitoraddedv2")
                settle.restart()
        }
    }

    // Hyprland applies its own monitor rules first; reading too early reports
    // the pre-rule mode
    Timer {
        id: settle
        interval: 600
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    // APPLY
    function _shortName(m) {
        var d = String(m.description || m.name)
        return d.length > 28 ? d.substring(0, 28) : d
    }

    function _mon(spec) {
        var parts = ['output = "' + spec.output + '"']
        if (spec.mode      !== undefined) parts.push('mode = "' + spec.mode + '"')
        if (spec.position  !== undefined) parts.push('position = "' + spec.position + '"')
        if (spec.scale     !== undefined) parts.push("scale = " + spec.scale)
        if (spec.mirror    !== undefined) parts.push('mirror = "' + spec.mirror + '"')
        if (spec.transform !== undefined) parts.push("transform = " + spec.transform)
        if (spec.disabled  !== undefined) parts.push("disabled = " + (spec.disabled ? "true" : "false"))
        Quickshell.execDetached(["hyprctl", "eval", "hl.monitor({ " + parts.join(", ") + " })"])
    }

    function _on(output) {
        _mon({ output: output, mode: "preferred", position: "auto", scale: 1, disabled: false })
    }
    function _off(output) { _mon({ output: output, disabled: true }) }

    function _snapshot() {
        var laptop = root.monitorFor(root.laptopOutput)
        var on = []
        var ext = root.externals()
        for (var i = 0; i < ext.length; i++) on.push(ext[i].name)
        return {
            laptopDisabled: laptop === null,
            guest: root.pending ? root.pending.name : "",
            extOn: on
        }
    }

    // layout: extend | duplicate | laptop | external
    function apply(layout, mon, needsConfirm) {
        if (!mon) return
        if (needsConfirm === undefined) needsConfirm = true
        root.revertSnapshot = root._snapshot()

        var name = mon.name
        switch (layout) {
        case "extend":
            _on(name)
            _on(root.laptopOutput)
            break
        case "duplicate":
            // Mirror the screen actually in use, which is not the laptop panel
            // while the monitor has it switched off
            _on(root.promptOutput)
            _mon({ output: name, mode: "preferred", position: "auto", scale: 1, mirror: root.promptOutput })
            break
        case "laptop":
            _on(root.laptopOutput)
            _off(name)
            break
        case "external":
            _on(name)
            _off(root.laptopOutput)
            break
        default:
            return
        }

        root.appliedLayout = layout
        root._placeAfter = true
        settle.restart()
        if (needsConfirm) root.confirmNeeded(mon, layout)
    }

    // unmirrored screens, laptop first
    function _row() {
        var list = []
        var laptop = root.monitorFor(root.laptopOutput)
        if (laptop && laptop.mirrorOf === "none") list.push(laptop)
        for (var i = 0; i < root.order.length; i++) {
            var m = root.monitorFor(root.order[i])
            if (m && m.mirrorOf === "none") list.push(m)
        }
        return list
    }

    function placeAll() {
        var list = root._row()
        var spots = Layout.place(list, 0)
        for (var i = 0; i < list.length; i++) {
            var m = list[i]
            _mon({
                output:    m.name,
                mode:      m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2),
                position:  spots[i].x + "x" + spots[i].y,
                scale:     m.scale,
                transform: m.transform
            })
        }
        refreshSoon()
    }

    // two or more externals
    function applyAll(layout, needsConfirm) {
        var ext = root.externals()
        if (ext.length === 0) return
        if (needsConfirm === undefined) needsConfirm = true
        root.revertSnapshot = root._snapshot()

        switch (layout) {
        case "externals":
            _off(root.laptopOutput)
            break
        case "extend":
            _on(root.laptopOutput)
            break
        case "duplicate":
            _off(root.laptopOutput)
            for (var i = 1; i < ext.length; i++)
                _mon({ output: ext[i].name, mode: "preferred", position: "auto", scale: 1, mirror: ext[0].name })
            break
        case "laptop":
            _on(root.laptopOutput)
            for (var j = 0; j < ext.length; j++) _off(ext[j].name)
            break
        default:
            return
        }

        root.appliedLayout = layout
        root.pendingPair = null
        root._placeAfter = true
        settle.restart()
        if (needsConfirm) root.confirmNeeded(ext[0], layout)
    }

    function setTransform(name, transform) {
        var m = root.monitorFor(name)
        if (!m) return
        _mon({
            output:    name,
            mode:      m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2),
            position:  m.x + "x" + m.y,
            scale:     m.scale,
            transform: transform
        })
        root._placeAfter = true
        settle.restart()
    }

    function move(name, dir) {
        root.order = Layout.move(root.order, name, dir)
        root.placeAll()
    }

    function remember(desc, layout) {
        var next = {}
        for (var k in root.remembered) next[k] = root.remembered[k]
        next[desc] = layout
        root.remembered = next
        save()
    }

    function forget(desc) {
        var next = {}
        for (var k in root.remembered) if (k !== desc) next[k] = root.remembered[k]
        root.remembered = next
        save()
    }

    // Put the screens back the way they were found and wake the laptop panel
    function revert() {
        var snap = root.revertSnapshot
        if (!snap) return
        if (snap.guest) _off(snap.guest)
        var ext = root.externals()
        for (var i = 0; i < ext.length; i++)
            if (snap.extOn.indexOf(ext[i].name) === -1) _off(ext[i].name)
        if (!snap.laptopDisabled) _on(root.laptopOutput)
        root.appliedLayout = ""
        root._placeAfter = true
        settle.restart()
    }

    // PERSISTENCE
    readonly property string statePath:
        Qt.resolvedUrl("monitors.json").toString().replace("file://", "")

    function save() { writeTimer.restart() }

    Timer {
        id: writeTimer
        interval: 60
        onTriggered: stateFile.setText(JSON.stringify({
            knownPatterns: root.knownPatterns,
            remembered:    root.remembered
        }, null, 2))
    }

    FileView {
        id: stateFile
        path: root.statePath
        preload: true
        onLoaded: {
            try {
                var j = JSON.parse(text() || "{}")
                if (j.knownPatterns) root.knownPatterns = j.knownPatterns
                if (j.remembered)    root.remembered    = j.remembered
            } catch (e) { }
        }
    }
}
