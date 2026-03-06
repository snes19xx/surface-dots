import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Services.Mpris

import "../lib" as Lib
import "../theme.js" as Theme

Rectangle {
    id: root

    // =========================
    // Sizing / visibility
    // =========================
    property int baseHeight: 120
    property real animH: root.active ? root.baseHeight : 0

    signal closeRequested()

    implicitHeight: animH
    Behavior on animH { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    visible: animH > 1
    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 170 } }

    radius: 24
    color: Theme.bgCard
    clip: true

    // Mask only while visible
    layer.enabled: root.visible
    layer.smooth: true
    layer.effect: OpacityMask {
        maskSource: Rectangle { width: root.width; height: root.height; radius: root.radius }
    }

    // =========================
    // Active player
    // =========================
    property var players: Mpris.players.values
    property MprisPlayer player: null

    function pickPlayer() {
        var ps = root.players || []
        if (ps.length === 0) { root.player = null; return }

        for (var i = 0; i < ps.length; i++)
            if (ps[i] && ps[i].isPlaying) { root.player = ps[i]; return }

        for (var j = 0; j < ps.length; j++)
            if (ps[j] && ps[j].playbackState === MprisPlaybackState.Paused) { root.player = ps[j]; return }

        root.player = ps[0]
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.pickPlayer()
    }

    property bool hasPlayer: root.player !== null
    property bool isPlaying: root.player ? root.player.isPlaying : false

    // =========================
    // Pause grace period
    // =========================
    property real nowMs: 0
    property real lastPlayingMs: 0

    Timer {
        interval: 1000
        repeat: true
        running: root.hasPlayer && root.visible   // do not tick when hidden
        triggeredOnStart: true
        onTriggered: root.nowMs = Date.now()
    }

    onPlayerChanged: {
        if (root.player && root.player.isPlaying) root.lastPlayingMs = Date.now()
        root.prevRawPos = -1
        root.resetTimeFromPlayer(true)
        root.syncMetadata(true)
    }

    onIsPlayingChanged: {
        if (root.isPlaying) root.lastPlayingMs = Date.now()
        if (!root.pendingToggle) root.uiPlaying = root.isPlaying
    }

    property bool recentlyPaused: root.hasPlayer
                                  && root.lastPlayingMs > 0
                                  && ((root.nowMs - root.lastPlayingMs) < 60000)

    // Only show if a player exists and it is playing or recently paused
    property bool active: root.hasPlayer && (root.isPlaying || root.recentlyPaused)

    // =========================
    // Metadata 
    // =========================
    property string title: "Not Playing"
    property string artist: "System Audio"
    property string artUrl: ""                 // raw from player
    property string lastGoodArtUrl: ""         // sticky
    property string effectiveArtUrl: (root.artUrl && root.artUrl.length > 0) ? root.artUrl : root.lastGoodArtUrl

    function syncMetadata(force) {
        if (!root.player) {
            root.title = "Not Playing"
            root.artist = "System Audio"
            root.artUrl = ""
            return
        }

        var nt = root.player.trackTitle || "Not Playing"
        var na = root.player.trackArtist || "System Audio"
        var nu = root.player.trackArtUrl || ""

        if (force || nt !== root.title) root.title = nt
        if (force || na !== root.artist) root.artist = na

        // Update raw artUrl
        if (force || nu !== root.artUrl) root.artUrl = nu
    }

    onArtUrlChanged: {
        // only accept non-empty URLs
        if (root.artUrl && root.artUrl.length > 0)
            root.lastGoodArtUrl = root.artUrl
    }

    // =========================
    // Play/pause UI state
    // =========================
    property bool uiPlaying: root.isPlaying
    property bool pendingToggle: false

    Timer {
        id: pendingTimer
        interval: 1400
        repeat: false
        onTriggered: root.pendingToggle = false
    }

    // Listen to player events
    Connections {
        target: root.player

        function onPlaybackStateChanged() {
            if (!root.pendingToggle && root.player) {
                root.uiPlaying = root.player.isPlaying
                if (root.player.isPlaying) root.lastPlayingMs = Date.now()
            }
        }

        function onTrackTitleChanged()  { root.syncMetadata(true); root.resetTimeFromPlayer(true) }
        function onTrackArtistChanged() { root.syncMetadata(true); root.resetTimeFromPlayer(true) }
        function onTrackArtUrlChanged() { root.syncMetadata(true) }

        function onLengthChanged() { root.resetTimeFromPlayer(true) }
        function onPositionChanged() { /* no-op*/ }
    }

    // =========================
    // Time tracking 
    // =========================
    property real lenSec: 0
    property real displayPos: 0

    // divisors
    property real lenDiv: 1000000
    property real posDiv: 1000000

    // track identity used to decide when to hard-reset
    property string trackKey: ""

    // for “position rewind” detection
    property real prevRawPos: -1

    function makeTrackKey() {
        if (!root.player) return ""
        return (root.player.trackTitle || "") + "|" +
               (root.player.trackArtist || "") + "|" +
               (root.player.trackArtUrl || "")
    }

    function pickTimeDiv(raw) {
        var n = Number(raw) || 0
        if (!isFinite(n) || n <= 0) return 1000000

        var divs = [1, 1000, 1000000, 1000000000] // s, ms, us, ns
        var best = 1000000
        var bestScore = -1e9

        for (var i = 0; i < divs.length; i++) {
            var d = divs[i]
            var s = n / d
            if (!isFinite(s) || s <= 0) continue

            var score = 0
            // plausible window: 0.2s..48h
            if (s >= 0.2 && s <= 172800) score += 80
            else score -= 100

            // common window: 30s..6h
            if (s >= 30 && s <= 21600) score += 60

            // prefer spec
            if (d === 1000000) score += 10

            if (score > bestScore) { bestScore = score; best = d }
        }
        return best
    }

    function pickPosDiv(rawPos, lenSeconds, preferredDiv) {
        var p = Number(rawPos) || 0
        if (!isFinite(p) || p <= 0) return preferredDiv || 1000000

        if (!(lenSeconds > 0)) return pickTimeDiv(p)

        var divs = [1, 1000, 1000000, 1000000000]
        var best = preferredDiv || 1000000
        var bestScore = -1e9

        for (var i = 0; i < divs.length; i++) {
            var d = divs[i]
            var ps = p / d
            if (!isFinite(ps) || ps < 0) continue

            var score = 0
            if (ps <= lenSeconds * 1.2) score += 120
            else score -= 150

            var ratio = ps / Math.max(1, lenSeconds)
            if (ratio >= 0 && ratio <= 1.2) score += 20
            if (ratio >= 0.001) score += 10

            if (d === 1000000) score += 8

            if (score > bestScore) { bestScore = score; best = d }
        }
        return best
    }

    function resetTimeFromPlayer(forceKeyReset) {
        if (!root.player) {
            root.lenSec = 0
            root.displayPos = 0
            root.trackKey = ""
            root.lenDiv = 1000000
            root.posDiv = 1000000
            root.prevRawPos = -1
            return
        }

        var rawLen = Number(root.player.length) || 0
        var rawPos = Number(root.player.position) || 0

        // infer length divisor from length if present else position
        var basis = (rawLen > 0) ? rawLen : rawPos
        root.lenDiv = pickTimeDiv(basis)

        root.lenSec = (rawLen > 0) ? (rawLen / root.lenDiv) : 0

        root.posDiv = pickPosDiv(rawPos, root.lenSec, root.lenDiv)

        var ps = (rawPos > 0) ? (rawPos / root.posDiv) : 0
        root.displayPos = (root.lenSec > 0)
            ? Math.max(0, Math.min(root.lenSec, ps))
            : Math.max(0, ps)

        if (forceKeyReset)
            root.trackKey = makeTrackKey()
    }

    function readLenSec() {
        if (!root.player) return 0
        var raw = Number(root.player.length) || 0
        if (!isFinite(raw) || raw <= 0) return 0
        return raw / root.lenDiv
    }

    function readPosSec() {
        if (!root.player) return 0
        var raw = Number(root.player.position) || 0
        if (!isFinite(raw) || raw < 0) return 0
        return raw / root.posDiv
    }

    // Smooth updates timer
    Timer {
        interval: 300
        repeat: true
        running: root.visible && root.hasPlayer   // NOTHING runs when hidden
        triggeredOnStart: true
        onTriggered: {
            if (!root.player) {
                root.displayPos = 0
                root.lenSec = 0
                root.trackKey = ""
                root.prevRawPos = -1
                return
            }

            // keep metadata fresh
            root.syncMetadata(false)

            if (root.player.isPlaying) root.lastPlayingMs = Date.now()

            var rawLen = Number(root.player.length) || 0
            var rawPos = Number(root.player.position) || 0

            // 1) Track key change
            var k = root.makeTrackKey()
            if (k !== root.trackKey) {
                root.resetTimeFromPlayer(true)
                root.trackKey = k
                root.prevRawPos = rawPos
                return
            }

            // If position jumps backwards a lot, it's almost certainly a new video/track.
            if (root.prevRawPos >= 0 && rawPos >= 0) {
                var rewind = root.prevRawPos - rawPos
                if (rewind > 30000) {
                    root.resetTimeFromPlayer(true)
                    root.trackKey = root.makeTrackKey()
                    root.prevRawPos = rawPos
                    return
                }
            }
            root.prevRawPos = rawPos

            // Update inferred length)
            if (rawLen > 0) {
                var newLenDiv = root.pickTimeDiv(rawLen)
                var newLenSec = rawLen / newLenDiv

                // If length changes massively, accept new divisor/length
                if (Math.abs(newLenSec - root.lenSec) > 2) {
                    root.lenDiv = newLenDiv
                    root.lenSec = newLenSec
                } else {
                    root.lenSec = root.readLenSec()
                }
            } else {
                // Keep existing lenSec instead of nuking, unless it was already 0.
                if (!(root.lenSec > 0)) root.lenSec = 0
            }

            // Re-check pos divisor
            root.posDiv = root.pickPosDiv(rawPos, root.lenSec, root.lenDiv)

            var p = root.readPosSec()
            root.displayPos = (root.lenSec > 0)
                ? Math.max(0, Math.min(root.lenSec, p))
                : Math.max(0, p)
        }
    }

    function fmt(s) {
        if (isNaN(s) || s < 0) return "0:00"
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var ss = Math.floor(s % 60)
        var secStr = (ss < 10 ? "0" : "") + ss
        if (h > 0) {
            var minStr = (m < 10 ? "0" : "") + m
            return h + ":" + minStr + ":" + secStr
        }
        return m + ":" + secStr
    }

    function fmtLen() { return (root.lenSec > 0.5) ? root.fmt(root.lenSec) : "--:--" }

    // =========================
    // Palette sampling 
    // =========================
    property color accentColor: Qt.rgba(0.85, 0.85, 0.85, 1)
    property color titleColor: Qt.rgba(1, 1, 1, 0.95)
    property color artistColor: Qt.rgba(1, 1, 1, 0.65)
    property color timeColor: Qt.rgba(1, 1, 1, 0.45)
    property color bgTint: Qt.rgba(1, 1, 1, 0.06)

    function mix(a,b,t) {
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            1
        )
    }

    Image {
        id: artSample
        x: -1000; y: -1000
        width: 32; height: 32
        source: root.effectiveArtUrl
        sourceSize.width: 32
        sourceSize.height: 32
        fillMode: Image.PreserveAspectCrop
        visible: false
        opacity: 0.0
        cache: true
        asynchronous: true

        onStatusChanged: {
            if (!root.visible) return
            if (!root.effectiveArtUrl || root.effectiveArtUrl === "") return
            if (status !== Image.Ready) return

            artSample.grabToImage(function(res) {
                if (!res || !res.image || !res.image.pixelColor) return
                var img = res.image
                var w = img.width, h = img.height
                if (w <= 0 || h <= 0) return

                var r=0,g=0,b=0,n=0
                for (var yy=0; yy<6; yy++) for (var xx=0; xx<6; xx++) {
                    var px = Math.floor((xx+0.5)*w/6)
                    var py = Math.floor((yy+0.5)*h/6)
                    var c = img.pixelColor(px, py)
                    r += c.r; g += c.g; b += c.b; n++
                }
                if (n <= 0) return

                var avg = Qt.rgba(r/n, g/n, b/n, 1)
                var lifted = mix(avg, Qt.rgba(1,1,1,1), 0.55)

                root.accentColor = lifted
                root.titleColor = mix(lifted, Qt.rgba(1,1,1,1), 0.4)
                root.artistColor = Qt.rgba(lifted.r, lifted.g, lifted.b, 0.75)
                root.timeColor = Qt.rgba(lifted.r, lifted.g, lifted.b, 0.55)
                root.bgTint = Qt.rgba(avg.r, avg.g, avg.b, 0.08)
            })
        }
    }

    // =========================
    // Blurred Background 
    // =========================
    Item {
        anchors.fill: parent

        Image {
            id: bgArt
            anchors.fill: parent
            source: root.effectiveArtUrl
            fillMode: Image.PreserveAspectCrop
            visible: false
            cache: true
            asynchronous: true
            // Downsample for blur
            sourceSize.width: 256
            sourceSize.height: 256
        }

        FastBlur {
            anchors.fill: bgArt
            source: bgArt
            radius: 80
            visible: root.visible && root.effectiveArtUrl !== ""
            cached: true
        }

        Rectangle { anchors.fill: parent; color: (root.effectiveArtUrl !== "") ? Qt.rgba(0,0,0,0.65) : Theme.bgCard }
        Rectangle { anchors.fill: parent; color: root.bgTint }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["bash", "-lc", "/home/snes/.config/quickshell/snes-hub/now_playing/now_playing"])
            root.closeRequested()
        }
    }

    // =========================
    // UI
    // =========================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Item {
            Layout.preferredWidth: 92
            Layout.preferredHeight: 92
            Layout.alignment: Qt.AlignVCenter

            Image {
                anchors.centerIn: parent
                width: 92
                height: 92
                source: root.effectiveArtUrl
                fillMode: Image.PreserveAspectCrop

                // Mask only while visible and only if art exists
                layer.enabled: root.visible && root.effectiveArtUrl !== ""
                layer.smooth: true
                layer.effect: OpacityMask { maskSource: Rectangle { width: 92; height: 92; radius: 12 } }

                cache: true
                asynchronous: true
                sourceSize.width: 128
                sourceSize.height: 128
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.title
                    font.family: Theme.textFont
                    font.pixelSize: 15
                    font.weight: 600
                    color: root.titleColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.artist
                    font.family: Theme.textFont
                    font.pixelSize: 13
                    font.weight: 500
                    color: root.artistColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.fmt(root.displayPos) + " / " + root.fmtLen()
                    font.family: Theme.textFont
                    font.pixelSize: 12
                    font.weight: 600
                    color: root.timeColor
                    Layout.topMargin: 2
                }
            }

            Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Lib.MediaButton {
                    icon: "󰒮"
                    size: 26
                    tint: root.accentColor
                    onClicked: { if (root.player && root.player.canGoPrevious) root.player.previous() }
                }

                Lib.WavyProgress {
                    Layout.fillWidth: true

                    // Control the width (smaller = wider)
                    Layout.leftMargin: -10
                    Layout.rightMargin: -10
                    
                    Layout.preferredHeight: 10
                    value: (root.lenSec > 0.5) ? (root.displayPos / root.lenSec) : 0

                    // Stop animation loop when hidden or paused
                    active: root.uiPlaying && root.visible

                    color: root.accentColor
                    trackColor: Qt.rgba(1, 1, 1, 0.15)
                    fps: 24
                    speed: 1.0
                    amplitude: 2.5
                    frequency: 0.15
                    lineWidth: 2.5
                    gap: 6       // Controls gap between the wave(progrss) and the static line (remaining progress)
                }

                Lib.MediaButton {
                    icon: "󰒭"
                    size: 26
                    tint: root.accentColor
                    onClicked: { if (root.player && root.player.canGoNext) root.player.next() }
                }
            }

            Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
        }

        Rectangle {
            id: playBtn
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            Layout.alignment: Qt.AlignVCenter

            radius: 21
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b,
                           playArea.containsMouse ? 0.20 : 0.12)
            Behavior on color { ColorAnimation { duration: 140 } }

            Item {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: "󰐊"
                    font.family: Theme.iconFont
                    font.pixelSize: 20
                    color: root.titleColor
                    opacity: root.uiPlaying ? 0.0 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰏤"
                    font.family: Theme.iconFont
                    font.pixelSize: 20
                    color: root.titleColor
                    opacity: root.uiPlaying ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }

            MouseArea {
                id: playArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.player || !root.player.canTogglePlaying) return
                    root.pendingToggle = true
                    pendingTimer.restart()
                    root.uiPlaying = !root.uiPlaying
                    root.player.togglePlaying()
                }
            }

            scale: playArea.pressed ? 0.90 : 1.0
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        }
    }
}
