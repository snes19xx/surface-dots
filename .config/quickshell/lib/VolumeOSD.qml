import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var theme

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "volume-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true

    exclusiveZone:  0
    // headroom for the shadow
    implicitHeight: 220
    color:          "transparent"
    visible:        false

    // shadow padding is click-through
    mask: Region { item: maskRect }
    // untransformed, so slide can't shift
    Item {
        id: maskRect
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     osdCard.anchors.bottomMargin
        width:  osdCard.width
        height: osdCard.height
    }

    // State
    property bool isDragging: false
    property bool osdVisible: false
    // Drag and wheel steps build on this until pipewire catches up
    property int  localVolume: -1
    readonly property int  volume: localVolume >= 0 ? localVolume : Math.round(Audio.volume * 100)
    Timer {
        id: localHold
        interval: 400
        onTriggered: if (!root.isDragging) root.localVolume = -1
    }
    readonly property bool muted:  Audio.muted
    readonly property bool isHeadphones: Audio.bluetoothName !== ""
        || /headphone|headset/i.test(Audio.sinkName)

    // A sink appearing or switching changes the volume too, those are ignored
    property bool _armed: false
    property var  _seenSink: null
    Timer {
        id: armTimer
        interval: 500
        onTriggered: root._armed = Audio.ready
    }
    Connections {
        target: Audio
        function onReadyChanged() {
            root._armed = false
            if (Audio.ready) armTimer.restart()
        }
        function onSinkChanged()   { root._checkSink() }
        function onVolumeChanged() { root._show() }
        function onMutedChanged()  { root._show() }
    }
    Component.onCompleted: {
        root._seenSink = Audio.sink
        if (Audio.ready) armTimer.restart()
    }

    function _checkSink() {
        if (Audio.sink === root._seenSink) return false
        root._seenSink = Audio.sink
        root._armed = false
        armTimer.restart()
        return true
    }

    function _show() {
        if (root._checkSink()) return
        if (!root._armed || !Audio.ready || root.isDragging) return
        root.osdVisible = true
        hideTimer.restart()
    }

    function _setVolume(v) {
        v = Math.max(0, Math.min(100, v))
        root.localVolume = v
        localHold.restart()
        Audio.setVolume(v / 100)
    }

    function _toggleMute() {
        Audio.toggleMute()
        root.osdVisible = true
        hideTimer.restart()
    }

    // Auto-hide
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
            root.visible = true       // map window before fade-in starts
            windowHideTimer.stop()
        } else {
            windowHideTimer.restart() // unmap after fade-out finishes
        }
    }

    // nerd-font speaker glyphs
    function volumeIcon(vol, muted) {
        if (muted || vol === 0) return String.fromCodePoint(0xF075F)
        if (vol < 35)           return String.fromCodePoint(0xF057F)
        if (vol < 70)           return String.fromCodePoint(0xF0580)
        return String.fromCodePoint(0xF057E)
    }

    OsdCard {
        id: osdCard
        theme: root.theme
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     48

        shown: root.osdVisible
        label: "Volume"
        value: root.muted ? "Muted" : root.volume + "%"
        secondary: Audio.bluetoothName
        // muted looks like critical toast
        accentColor: root.muted ? root.theme.accentRed : root.theme.accent
        glyph: root.volumeIcon(root.volume, root.muted)
        iconSource: root.isHeadphones ? Qt.resolvedUrl("vol_headphones.svg") : ""
        iconClickable: true
        onIconClicked: root._toggleMute()

        showLevel: true
        level: root.volume / 100.0
        dimLevel: root.muted
        dragging: root.isDragging

        onLevelPressed: frac => {
            root.isDragging = true
            root.osdVisible = true
            hideTimer.stop()
            root._setVolume(Math.round(frac * 100))
        }
        onLevelMoved: frac => root._setVolume(Math.round(frac * 100))
        onLevelReleased: {
            root.isDragging = false
            localHold.restart()
            hideTimer.restart()
        }
        onLevelWheeled: delta => {
            root._setVolume(root.volume + delta)
            root.osdVisible = true
            hideTimer.restart()
        }
    }

    Connections {
        target: root
        function onVolumeChanged() { osdCard.pulse() }
        function onMutedChanged()  { osdCard.pulse() }
    }
}
