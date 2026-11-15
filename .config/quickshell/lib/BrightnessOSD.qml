import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var theme

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "brightness-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true

    exclusiveZone:  0
    // headroom for the shadow
    implicitHeight: 210
    color:          "transparent"
    visible:        false

    // shadow padding is click-through
    mask: Region { item: osdCard }

    // State
    property bool osdVisible: false
    property bool isDragging: false
    // Drag and wheel steps build on this until the file watch catches up
    property int  localPercent: -1
    readonly property int percent: localPercent >= 0 ? localPercent : Math.max(0, Brightness.percent)
    Timer {
        id: localHold
        interval: 400
        onTriggered: if (!root.isDragging) root.localPercent = -1
    }

    // Scripts like reading mode stay silent
    Connections {
        target: Brightness
        function onUserChanged() {
            if (root.isDragging) return
            root.osdVisible = true
            hideTimer.restart()
        }
    }

    // Throttle: only fire every 40ms during drag
    Timer {
        id: setThrottle
        interval: 40
        property int pendingPercent: -1
        onTriggered: {
            if (pendingPercent < 0) return
            Brightness.set(pendingPercent)
            pendingPercent = -1
        }
    }

    function _setBrightness(p) {
        p = Math.max(1, Math.min(100, p))
        root.localPercent = p
        localHold.restart()
        setThrottle.pendingPercent = p
        if (!setThrottle.running) setThrottle.start()
    }

    // Hide timer
    Timer {
        id: hideTimer
        interval: 2600
        onTriggered: if (!root.isDragging) root.osdVisible = false
    }

    Timer {
        id: windowHideTimer
        interval: 350
        onTriggered: root.visible = false
    }

    onOsdVisibleChanged: {
        if (osdVisible) {
            root.visible = true
            windowHideTimer.stop()
        } else {
            windowHideTimer.restart()
        }
    }

    // nerd-font brightness glyphs
    function brightnessIcon(p) {
        if (p >= 75) return String.fromCodePoint(0xF00E0)
        if (p >= 40) return String.fromCodePoint(0xF00DF)
        if (p >= 10) return String.fromCodePoint(0xF00DE)
        return String.fromCodePoint(0xF00DD)
    }

    OsdCard {
        id: osdCard
        theme: root.theme
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     40

        shown: root.osdVisible
        label: "Brightness"
        value: root.percent + "%"
        glyph: root.brightnessIcon(root.percent)

        showLevel: true
        level: root.percent / 100.0
        dragging: root.isDragging

        onLevelPressed: frac => {
            root.isDragging = true
            root.osdVisible = true
            hideTimer.stop()
            root._setBrightness(Math.round(frac * 100))
        }
        onLevelMoved: frac => root._setBrightness(Math.round(frac * 100))
        onLevelReleased: {
            root.isDragging = false
            localHold.restart()
            hideTimer.restart()
        }
        onLevelWheeled: delta => {
            root._setBrightness(root.percent + delta)
            root.osdVisible = true
            hideTimer.restart()
        }
    }

    Connections {
        target: root
        function onPercentChanged() { osdCard.pulse() }
    }
}
