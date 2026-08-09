pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root

    // STATE
    readonly property string laptopOutput: "eDP-1"
    property var monitors: []              // parsed hyprctl monitors -j
    property var pending: null             // guest waiting for a choice
    property string appliedLayout: ""      // layout awaiting confirm
    property var revertSnapshot: null
    property int revertSeconds: 0

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

    // DETECTION
    property var _seen: ({})
    property bool _primed: false

    Process {
        id: query
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list = []
                try { list = JSON.parse(this.text || "[]") } catch (e) { return }
                root.monitors = list

                var fresh = {}
                for (var i = 0; i < list.length; i++) {
                    var m = list[i]
                    fresh[m.name] = m.description
                    if (!root._primed) continue
                    if (root._seen[m.name] === m.description) continue
                    if (m.name === root.laptopOutput) continue

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
                for (var name in root._seen)
                    if (fresh[name] === undefined) root.monitorGone(name)

                root._seen = fresh
                root._primed = true
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
        if (spec.disabled  !== undefined) parts.push("disabled = " + (spec.disabled ? "true" : "false"))
        Quickshell.execDetached(["hyprctl", "eval", "hl.monitor({ " + parts.join(", ") + " })"])
    }

    function _on(output) {
        _mon({ output: output, mode: "preferred", position: "auto", scale: 1, disabled: false })
    }
    function _off(output) { _mon({ output: output, disabled: true }) }

    function _snapshot() {
        var laptop = root.monitorFor(root.laptopOutput)
        return {
            laptopDisabled: laptop === null,
            guest: root.pending ? root.pending.name : ""
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
        settle.restart()
        if (needsConfirm) root.confirmNeeded(mon, layout)
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

    // Put the guest back the way it was found and wake the laptop panel
    function revert() {
        var snap = root.revertSnapshot
        if (!snap) return
        if (snap.guest) _off(snap.guest)
        if (!snap.laptopDisabled) _on(root.laptopOutput)
        root.appliedLayout = ""
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
