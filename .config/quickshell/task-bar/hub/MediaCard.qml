import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Services.Mpris

import "../lib" as Lib

Rectangle {
    id: root
    Lib.ThemeEngine { id: theme }

    // Bind local state to the engine
    property bool isDark: theme.isDarkMode 

    // Sizing / visibility
    property int baseHeight: 120
    property real animH: root.active ? root.baseHeight : 0

    signal closeRequested()

    implicitHeight: animH
    Behavior on animH { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    visible: animH > 1
    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 170 } }

    radius: 24
    color: theme.bgCard 
    clip: true

    // Mask only while visible
    layer.enabled: root.visible
    layer.smooth: true
    layer.effect: OpacityMask {
        maskSource: Rectangle { width: root.width; height: root.height; radius: root.radius }
    }


    // Active player
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


    // Pause grace period
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
        root.syncMetadata()
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


    // Metadata 
    property string title: "Not Playing"
    property string artist: "System Audio"
    property string artUrl: ""                 // raw from player
    property string lastGoodArtUrl: ""         // sticky
    property string effectiveArtUrl: (root.artUrl && root.artUrl.length > 0) ? root.artUrl : root.lastGoodArtUrl

    // Firefox Fallback Process
    Process {
        id: firefoxFallbackProc
        command: ["bash", "-c", "LATEST=$(ls -1t $HOME/.mozilla/firefox/firefox-mpris/* 2>/dev/null | head -n 1); if [ -n \"$LATEST\" ]; then cp \"$LATEST\" /tmp/now_playing_firefox.png; fi"]
        running: false
        onRunningChanged: {
            if (!running) {
                // Cache
                root.artUrl = "file:///tmp/now_playing_firefox.png?t=" + Date.now()
            }
        }
    }

    function syncMetadata() {
        if (!root.player) {
            root.title = "Not Playing"
            root.artist = "System Audio"
            root.artUrl = ""
            return
        }

        root.title = root.player.trackTitle || "Not Playing"
        root.artist = root.player.trackArtist || "System Audio"

        var nu = root.player.trackArtUrl || ""
        var pName = (root.player.name || "") + " " + (root.player.identity || "")
        var isFirefox = pName.toLowerCase().indexOf("firefox") !== -1

        if (nu !== "") {
            root.artUrl = nu
        } else if (isFirefox) {
            firefoxFallbackProc.running = false
            firefoxFallbackProc.running = true
        } else {
            root.artUrl = ""
        }
    }

    onArtUrlChanged: {
        // only accept non-empty URLs
        if (root.artUrl && root.artUrl.length > 0)
            root.lastGoodArtUrl = root.artUrl
    }

    // Play/pause UI state
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

        function onTrackTitleChanged()  { root.syncMetadata(); root.resetTimeFromPlayer(true) }
        function onTrackArtistChanged() { root.syncMetadata(); root.resetTimeFromPlayer(true) }
        function onTrackArtUrlChanged() { root.syncMetadata() }

        function onLengthChanged() { root.resetTimeFromPlayer(true) }
        function onPositionChanged() { /* no-op*/ }
    }


    // Time tracking 
    property real lenSec: 0
    property real displayPos: 0

    // divisors
    property real lenDiv: 1000000
    property real posDiv: 1000000

    // track identity used to decide when to hard-reset
    property string trackKey: ""

    // for "position rewind" detection
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
        running: root.visible && root.hasPlayer
        triggeredOnStart: true
        onTriggered: {
            if (!root.player) {
                root.displayPos = 0
                root.lenSec = 0
                root.trackKey = ""
                root.prevRawPos = -1
                return
            }

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

            // Update inferred length
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


    // Palette sampling 
    // HELPER: Mix colors
    function mix(a,b,t) {
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            1
        )
    }

    // Store the raw dominant color (Default: Dark Grey)
    property color dominantColor: Qt.rgba(0.2, 0.2, 0.2, 1)
        
    // Accent: In Dark mode, mix with White. In Light mode, mix with Black 
    property color accentColor: root.isDark 
        ? root.mix(root.dominantColor, Qt.rgba(1,1,1,1), 0.55)
        : root.mix(root.dominantColor, Qt.rgba(0,0,0,1), 0.25)
    
    // Text Colors:
    property color titleColor: root.isDark
        ? root.mix(root.accentColor, Qt.rgba(1,1,1,1), 0.85) // DarkMode: White-ish
        : root.mix(root.accentColor, Qt.rgba(0,0,0,1), 0.85) // LightMode: Black-ish

    property color artistColor: root.isDark
        ? Qt.rgba(root.titleColor.r, root.titleColor.g, root.titleColor.b, 0.70)
        : Qt.rgba(root.titleColor.r, root.titleColor.g, root.titleColor.b, 0.70)

    property color timeColor: root.isDark
        ? Qt.rgba(root.titleColor.r, root.titleColor.g, root.titleColor.b, 0.50)
        : Qt.rgba(root.titleColor.r, root.titleColor.g, root.titleColor.b, 0.55)

    
    // Color cache 
    property var colorCache: ({})
    property string lastExtractedUrl: ""
    
    Behavior on dominantColor { ColorAnimation { duration: 400 } }


    // Use Canvas to extract colors from the image
    Canvas {
        id: colorCanvas
        width: 100
        height: 100
        visible: false
        
        property string imageUrl: ""
        
        onImageUrlChanged: {
            if (!imageUrl || imageUrl === "") return
            
            // Check cache first
            if (root.colorCache[imageUrl]) {
                var cached = root.colorCache[imageUrl]
                root.dominantColor = cached.dominant
                root.lastExtractedUrl = imageUrl
                return
            }
            
            loadImage(imageUrl)
        }
        
        onImageLoaded: {
            requestPaint()
        }
        
        onPaint: {
            if (!imageUrl || imageUrl === "") return
            if (root.colorCache[imageUrl]) return  // Already cached
            
            var ctx = getContext("2d")
            if (!ctx) return
            
            // Draw the image
            ctx.drawImage(imageUrl, 0, 0, width, height)
            
            // Sample pixels
            var r=0, g=0, b=0, n=0
            var samples = 10
            
            for (var yy=0; yy<samples; yy++) {
                for (var xx=0; xx<samples; xx++) {
                    var px = Math.floor((xx+0.5)*width/samples)
                    var py = Math.floor((yy+0.5)*height/samples)
                    
                    var imgData = ctx.getImageData(px, py, 1, 1)
                    if (imgData && imgData.data && imgData.data.length >= 3) {
                        r += imgData.data[0] / 255.0
                        g += imgData.data[1] / 255.0
                        b += imgData.data[2] / 255.0
                        n++
                    }
                }
            }
            
            if (n > 0) {
                var avg = Qt.rgba(r/n, g/n, b/n, 1)
                
                // Update State 
                root.dominantColor = avg
                
                // Cache the extracted color
                var cache = root.colorCache
                cache[imageUrl] = { dominant: avg }
                root.colorCache = cache
                root.lastExtractedUrl = imageUrl
            }
        }
        
        Component.onCompleted: {
            if (root.effectiveArtUrl && root.effectiveArtUrl !== "") {
                imageUrl = root.effectiveArtUrl
            }
        }
    }

    
    onEffectiveArtUrlChanged: {
        if (root.effectiveArtUrl && root.effectiveArtUrl !== "" && root.effectiveArtUrl !== root.lastExtractedUrl) {
            colorCanvas.imageUrl = root.effectiveArtUrl
        } else if (root.effectiveArtUrl && root.effectiveArtUrl !== "" && root.colorCache[root.effectiveArtUrl]) {
            // Restore from cache if URL is the same but colors got reset
            var cached = root.colorCache[root.effectiveArtUrl]
            root.dominantColor = cached.dominant
        }
    }


    // Dominant Color Background 
    Item {
        anchors.fill: parent

        Rectangle { 
            anchors.fill: parent
            color: root.dominantColor
            Behavior on color { ColorAnimation { duration: 400 } }
        }

        // Texture/Grain
        Rectangle { 
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.1)
        }
        
        // Mode Overlay: 
        // Dark Mode: Darkens the art (#1e2327) at 55%
        // Light Mode: Whitewashes the art (#ffffff) at 75%
        Rectangle { 
            anchors.fill: parent
            color: root.isDark ? "#1e2327" : "#ffffff"
            opacity: root.isDark ? 0.55 : 0.75
            
            Behavior on color { ColorAnimation { duration: 400 } }
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["bash", "-lc", "/home/snes/.config/quickshell/task-bar/now_playing/now_playing"])
            root.closeRequested()
        }
    }


    // UI

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Item {
            Layout.preferredWidth: 92
            Layout.preferredHeight: 92
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: visibleAlbumArt
                anchors.centerIn: parent
                width: 96
                height: 96
                source: root.effectiveArtUrl
                fillMode: Image.PreserveAspectCrop

                // Mask only while visible and only if art exists
                layer.enabled: root.visible && root.effectiveArtUrl !== ""
                layer.smooth: true
                layer.effect: OpacityMask { maskSource: Rectangle { width: 96; height: 96; radius: 8 } }

                cache: true
                asynchronous: true
                sourceSize.width: 256
                sourceSize.height: 256
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
                    font.family: theme.textFont  
                    font.pixelSize: 15
                    font.weight: 600
                    color: root.titleColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.artist
                    font.family: theme.textFont 
                    font.pixelSize: 13
                    font.weight: 500
                    color: root.artistColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.fmt(root.displayPos) + " / " + root.fmtLen()
                    font.family: theme.textFont 
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
                    Layout.leftMargin: -10
                    Layout.rightMargin: -10
                    
                    Layout.preferredHeight: 10
                    value: (root.lenSec > 0.5) ? (root.displayPos / root.lenSec) : 0

                    // Stop animation loop when hidden or paused
                    active: root.uiPlaying && root.visible
                    color: root.accentColor
                    trackColor: root.isDark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.10)
                    
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

            radius: 8
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
                    font.family: theme.iconFont 
                    font.pixelSize: 20
                    color: root.titleColor
                    opacity: root.uiPlaying ? 0.0 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰏤"
                    font.family: theme.iconFont 
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