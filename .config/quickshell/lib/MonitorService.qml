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
    property var order: []                 // screens, left to right
    property var pendingPair: null         // awaiting a pair choice
    property bool _placeAfter: false
    property var _lastGood: ({})           // last mode seen per output
    property double _quietUntil: 0         // ignore our own toggles

    signal pairConnected(var mons)
    signal guestConnected(var mon)
    signal monitorGone(string name)
    signal knownConnected(var mon)
    signal confirmNeeded(var mon, string layout)
    signal toast(string msg)

    // Descriptions treated as configured screens. 
    property var knownPatterns: []
    property var remembered: ({})          // description -> layout
    property var screens: ({})             // description -> mode, scale
    property var setups: ({})              // setup key -> order, transforms
    // Description substrings, left to right
    property var leftToRight: []

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

    function _slotRank(name) {
        if (name === root.laptopOutput) return -1
        var m = root.monitorFor(name)
        var d = m ? (m.description || "") : ""
        for (var i = 0; i < root.leftToRight.length; i++)
            if (d.indexOf(root.leftToRight[i]) !== -1) return i
        return Infinity
    }

    // one key per desk setup
    function _setupKey(list) {
        return Layout.pairKey((list || root.monitors).map(function (m) { return root.keyFor(m) }))
    }

    function _namesFor(descs, list) {
        var out = []
        for (var i = 0; i < descs.length; i++)
            for (var j = 0; j < list.length; j++)
                if (root.keyFor(list[j]) === descs[i]) { out.push(list[j].name); break }
        return out
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
                for (var k = 0; k < list.length; k++) names.push(list[k].name)
                var setChanged = !root._primed || names.length !== Object.keys(root._seen).length
                for (var s = 0; s < list.length; s++)
                    if (root._seen[list[s].name] !== list[s].description) setChanged = true
                var prev = root.order
                // returning laptop goes leftmost
                if (names.indexOf(root.laptopOutput) !== -1 && prev.indexOf(root.laptopOutput) === -1)
                    prev = [root.laptopOutput].concat(prev)
                // saved order beats leftToRight
                var setup = root.setups[root._setupKey(list)]
                if (setChanged && setup && setup.order) prev = root._namesFor(setup.order, list)
                root.order = Layout.reconcileOrder(prev, names, root._slotRank)
                if (ext.length < 2) root.pendingPair = null

                var good = root._lastGood
                for (var g = 0; g < list.length; g++)
                    good[list[g].name] = {
                        mode: list[g].width + "x" + list[g].height + "@" + Number(list[g].refreshRate).toFixed(2),
                        scale: list[g].scale, transform: list[g].transform
                    }

                var fresh = {}
                var arrived = []
                var quiet = Date.now() < root._quietUntil
                for (var i = 0; i < list.length; i++) {
                    var m = list[i]
                    fresh[m.name] = m.description
                    if (!root._primed) continue
                    if (root._seen[m.name] === m.description) continue
                    if (m.name === root.laptopOutput) continue
                    if (quiet) continue

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
                    if (saved) {
                        root.applyAll(saved, false)
                        if (wasPrimed) root.toast("Displays set to " + saved)
                    } else if (!wasPrimed) {
                        // reload keeps this login's layout
                        if (root.monitorFor(root.laptopOutput)) root.applyAll("externals", false)
                        else root.placeAll()
                    } else {
                        root.pendingPair = ext
                        root.pairConnected(ext)
                    }
                } else if (root._placeAfter || changed) {
                    // hotplug re-applies the laptop rule
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
            // reload resets every screen
            if (ev.name === "configreloaded") {
                root._placeAfter = true
                settle.restart()
            }
        }
    }

    // Hyprland applies its own monitor rules first; reading too early reports
    // the pre-rule mode
    Timer {
        id: settle
        interval: 600
        onTriggered: root.refresh()
    }

    // Hyprland re-applies rules 500ms after login
    Component.onCompleted: root.refreshSoon()

    // APPLY
    function _shortName(m) {
        var d = String(m.description || m.name)
        return d.length > 28 ? d.substring(0, 28) : d
    }

    function _spec(spec) {
        var parts = ['output = "' + spec.output + '"']
        if (spec.mode      !== undefined) parts.push('mode = "' + spec.mode + '"')
        if (spec.position  !== undefined) parts.push('position = "' + spec.position + '"')
        if (spec.scale     !== undefined) parts.push("scale = " + spec.scale)
        if (spec.mirror    !== undefined) parts.push('mirror = "' + spec.mirror + '"')
        if (spec.transform !== undefined) parts.push("transform = " + spec.transform)
        if (spec.disabled  !== undefined) parts.push("disabled = " + (spec.disabled ? "true" : "false"))
        return "hl.monitor({ " + parts.join(", ") + " })"
    }

    function _mon(spec) {
        Quickshell.execDetached(["hyprctl", "eval", root._spec(spec)])
    }

    // one eval, no overlap mid-swap
    function _monBatch(specs) {
        if (!specs.length) return
        Quickshell.execDetached(["hyprctl", "eval", specs.map(root._spec).join("; ")])
    }

    // preferred may exceed the cable
    function _onSpec(output) {
        var g = root._lastGood[output]
        if (g) return { output: output, mode: g.mode, position: "auto", scale: g.scale, transform: g.transform, disabled: false }
        return { output: output, mode: "preferred", position: "auto", scale: 1, disabled: false }
    }
    function _on(output) { _mon(root._onSpec(output)) }
    function _off(output) { _mon({ output: output, disabled: true }) }

    function _allExternals() {
        var out = []
        for (var i = 0; i < root.allMonitors.length; i++)
            if (root.allMonitors[i].name !== root.laptopOutput) out.push(root.allMonitors[i])
        return out
    }

    function _snapshot() {
        var screens = []
        for (var i = 0; i < root.allMonitors.length; i++) {
            var m = root.allMonitors[i]
            screens.push({
                name: m.name, disabled: m.disabled === true, mirrorOf: m.mirrorOf,
                mode: m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2),
                position: m.x + "x" + m.y, scale: m.scale, transform: m.transform
            })
        }
        return { guest: root.pending ? root.pending.name : "", screens: screens }
    }

    // layout: extend | duplicate | laptop | external
    function apply(layout, mon, needsConfirm) {
        if (!mon) return
        if (needsConfirm === undefined) needsConfirm = true
        root.revertSnapshot = root._snapshot()
        root._quietUntil = Date.now() + 3000

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

    // unmirrored screens, in order
    function _row() {
        var list = []
        for (var i = 0; i < root.order.length; i++) {
            var m = root.monitorFor(root.order[i])
            if (m && m.mirrorOf === "none") list.push(m)
        }
        return list
    }

    function placeAll() {
        var turns = (root.setups[root._setupKey()] || {}).transforms || {}
        var list = root._row().map(function (m) {
            var key = root.keyFor(m)
            return Layout.target(m, root.screens[key], turns[key])
        })
        var spots = Layout.place(list, 0)
        var specs = []
        for (var i = 0; i < list.length; i++) {
            var t = list[i]
            specs.push({
                output:    t.name,
                mode:      t.mode,
                position:  spots[i].x + "x" + spots[i].y,
                scale:     t.scale,
                transform: t.transform
            })
        }
        _monBatch(specs)
        refreshSoon()
    }

    // two or more externals
    function applyAll(layout, needsConfirm) {
        // includes off ones for Extend
        var all = root._allExternals()
        if (all.length === 0) return
        if (needsConfirm === undefined) needsConfirm = true
        root.revertSnapshot = root._snapshot()
        root._quietUntil = Date.now() + 3000

        var wake = function () {
            for (var w = 0; w < all.length; w++) if (all[w].disabled) _on(all[w].name)
        }

        switch (layout) {
        case "externals":
            wake()
            _off(root.laptopOutput)
            break
        case "extend":
            wake()
            _on(root.laptopOutput)
            break
        case "duplicate":
            wake()
            _off(root.laptopOutput)
            for (var i = 1; i < all.length; i++)
                _mon({ output: all[i].name, mode: "preferred", position: "auto", scale: 1, mirror: all[0].name })
            break
        case "laptop":
            _on(root.laptopOutput)
            for (var j = 0; j < all.length; j++) _off(all[j].name)
            break
        default:
            return
        }

        root.appliedLayout = layout
        root.pendingPair = null
        root._placeAfter = true
        settle.restart()
        if (needsConfirm) root.confirmNeeded(all[0], layout)
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

    function moveTo(name, slot) {
        root.order = Layout.moveTo(root.order, name, slot)
        var descs = []
        for (var i = 0; i < root.order.length; i++) {
            var m = root.monitorFor(root.order[i])
            if (m) descs.push(root.keyFor(m))
        }
        root._editSetup(function (s) { s.order = descs })
        root.placeAll()
    }

    // rotation is per setup, not per screen
    function saveScreen(m, mode, scale, transform) {
        var key = root.keyFor(m)
        var next = JSON.parse(JSON.stringify(root.screens))
        next[key] = { mode: mode, scale: scale }
        root.screens = next
        root._editSetup(function (s) {
            s.transforms = s.transforms || {}
            s.transforms[key] = transform
        })
    }

    function _editSetup(fn) {
        var next = JSON.parse(JSON.stringify(root.setups))
        var key = root._setupKey()
        var s = next[key] || {}
        fn(s)
        next[key] = s
        root.setups = next
        save()
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
        root._quietUntil = Date.now() + 3000
        var specs = []
        for (var i = 0; i < snap.screens.length; i++) {
            var s = snap.screens[i]
            if (s.disabled || s.name === snap.guest) {
                specs.push({ output: s.name, disabled: true })
            } else {
                specs.push({
                    output: s.name, mode: s.mode, position: s.position, scale: s.scale,
                    transform: s.transform, mirror: s.mirrorOf === "none" ? "" : s.mirrorOf,
                    disabled: false
                })
            }
        }
        _monBatch(specs)
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
            remembered:    root.remembered,
            screens:       root.screens,
            setups:        root.setups
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
                if (j.screens)       root.screens       = j.screens
                if (j.setups)        root.setups        = j.setups
            } catch (e) { }
        }
    }
}
