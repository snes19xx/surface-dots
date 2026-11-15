import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var theme

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "theme-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true

    exclusiveZone:  0
    // headroom for the shadow
    implicitHeight: 190
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

    // OSD payload
    property string glyph:       ""   // nerd-font icon
    property string labelText:   ""   // e.g. "Theme"
    property string sublabel:    ""   // e.g. "Dark"
    property color  accentColor: root.theme.accentBlue
    property bool   osdVisible:       false
    property bool   _readyTheme:      false
    property bool   _readyReading:    false
    property bool   _readyNightLight: false

    // File watchers ─
    FileView {
        id: themeWatcher
        path:         Quickshell.env("HOME") + "/.cache/quickshell/theme_osd"
        watchChanges: true
        preload:      true
        onFileChanged: reload()
        onLoaded:      root._readyTheme = true
        onTextChanged: root._handleTheme(text())
    }

    FileView {
        id: readingWatcher
        path:         Quickshell.env("HOME") + "/.cache/quickshell/reading_mode"
        watchChanges: true
        preload:      true
        onFileChanged: reload()
        onLoaded:      root._readyReading = true
        onTextChanged: root._handleReading(text())
    }

    FileView {
        id: nightLightWatcher
        path:         Quickshell.env("HOME") + "/.cache/quickshell/night_light"
        watchChanges: true
        preload:      true
        onFileChanged: reload()
        onLoaded:      root._readyNightLight = true
        onTextChanged: root._handleNightLight(text())
    }


    // Handlers
    function _show() {
        root.osdVisible = true
        hideTimer.restart()
    }

    function _handleTheme(raw) {
        if (!root._readyTheme) return
        var v = raw.trim().toLowerCase()
        if (v !== "light" && v !== "dark") return
        if (v === "light") {
            root.glyph       = String.fromCodePoint(0xF0599)
            root.sublabel    = "Light"
            root.accentColor = root.theme.accentBlue
        } else {
            root.glyph       = String.fromCodePoint(0xF0594)
            root.sublabel    = "Dark"
            root.accentColor = root.theme.accent
        }
        root.labelText = "Theme"
        _show()
    }

    function _handleReading(raw) {
        if (!root._readyReading) return
        var v = raw.trim().toLowerCase()
        if (v !== "on" && v !== "off") return
        if (v === "on") {
            root.glyph       = String.fromCodePoint(0xF00BD)
            root.labelText   = "Reading Mode"
            root.sublabel    = "On"
            root.accentColor = root.theme.accentSlider
        } else {
            root.glyph       = String.fromCodePoint(0xF1694)
            root.labelText   = "Reading Mode"
            root.sublabel    = "Off"
            root.accentColor = root.theme.textSecondary
        }
        _show()
    }

    function _handleNightLight(raw) {
        if (!root._readyNightLight) return
        var v = raw.trim().toLowerCase()
        if (v !== "on" && v !== "off") return
        if (v === "on") {
            root.glyph       = String.fromCodePoint(0xF1A4C)
            root.labelText   = "Night Light"
            root.sublabel    = "On"
            root.accentColor = root.theme.accentRed
        } else {
            root.glyph       = String.fromCodePoint(0xF1A4D)
            root.labelText   = "Night Light"
            root.sublabel    = "Off"
            root.accentColor = root.theme.textSecondary
        }
        _show()
    }

    // Timers
    Timer {
        id: hideTimer
        interval: 5000
        onTriggered: root.osdVisible = false
    }

    // Unmap window after fade-out completes
    Timer {
        id: windowHideTimer
        interval: 240
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

    OsdCard {
        id: osdCard
        theme: root.theme
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     52

        shown: root.osdVisible
        fadeInMs: 140
        fadeOutMs: 230
        slideY: 20
        label: root.labelText
        value: root.sublabel
        accentColor: root.accentColor
        glyph: root.glyph
    }

    Connections {
        target: root
        function onGlyphChanged() { osdCard.swap() }
    }
}
