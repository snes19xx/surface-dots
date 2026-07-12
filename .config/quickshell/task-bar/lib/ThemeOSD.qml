import QtQuick
import QtQuick.Layouts
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
    implicitHeight: 180
    color:          "transparent"
    visible:        false

    // OSD payload 
    property string iconPath:    ""   
    property string labelText:   ""   // e.g. "Dark Mode"
    property string sublabel:    ""   // e.g. "Activated"
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
            root.iconPath    = Qt.resolvedUrl("lightmode.svg")
            root.labelText   = "Light Mode"
            root.accentColor = root.theme.accentBlue
        } else {
            root.iconPath    = Qt.resolvedUrl("darkmode.svg")
            root.labelText   = "Dark Mode"
            root.accentColor = root.theme.accent
        }
        root.sublabel = "Activated"
        _show()
    }

    function _handleReading(raw) {
        if (!root._readyReading) return
        var v = raw.trim().toLowerCase()
        if (v !== "on" && v !== "off") return
        if (v === "on") {
            root.iconPath    = Qt.resolvedUrl("readon.svg")
            root.labelText   = "Reading Mode"
            root.sublabel    = "On"
            root.accentColor = root.theme.accentSlider
        } else {
            root.iconPath    = Qt.resolvedUrl("readoff.svg")
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
            root.iconPath    = Qt.resolvedUrl("nl_on.svg")
            root.labelText   = "Night Light"
            root.sublabel    = "On"
            root.accentColor = root.theme.accentRed
        } else {
            root.iconPath    = Qt.resolvedUrl("nl_off.svg")
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

    // OSD Visual 
    Item {
        anchors.fill: parent

        Item {
            id: card
            width:  290
            height: 90
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom:           parent.bottom
            anchors.bottomMargin:     52

            // Fade
            opacity: root.osdVisible ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration:    root.osdVisible ? 140 : 230
                    easing.type: root.osdVisible ? Easing.OutQuad : Easing.InCubic
                }
            }

            // Slide
            transform: Translate {
                y: root.osdVisible ? 0 : 20
                Behavior on y {
                    NumberAnimation {
                        duration:    root.osdVisible ? 200 : 260
                        easing.type: root.osdVisible ? Easing.OutCubic : Easing.InCubic
                    }
                }
            }

            // Shadow 
            Rectangle {
                anchors.centerIn: parent
                width:  parent.width  + 2
                height: parent.height + 2
                radius: root.theme.radiusOuter + 2
                color:  "transparent"
                border.width: 8
                border.color: Qt.rgba(0, 0, 0, root.theme.isDarkMode ? 0.30 : 0.13)
                opacity: 0.55
            }

            // Background
            Rectangle {
                anchors.fill: parent
                radius:       root.theme.radiusOuter
                color:        root.theme.bgCard
                border.width: 1
                border.color: root.theme.outline

                // Accent tint that morphs with mode color
                Rectangle {
                    anchors { fill: parent; margins: 1 }
                    radius: root.theme.radiusOuter - 1
                    color:  Qt.rgba(
                        root.accentColor.r,
                        root.accentColor.g,
                        root.accentColor.b,
                        root.theme.isDarkMode ? 0.08 : 0.05
                    )
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }

            // Content 
            RowLayout {
                anchors {
                    fill:         parent
                    leftMargin:   20
                    rightMargin:  20
                }
                spacing: 16

                Item {
                    implicitWidth:  64
                    implicitHeight: 64
                    Layout.alignment: Qt.AlignVCenter

                    // Circle behind icon
                    Rectangle {
                        anchors.centerIn: parent
                        width:  54
                        height: 54
                        radius: 27
                        color:  Qt.rgba(
                            root.accentColor.r,
                            root.accentColor.g,
                            root.accentColor.b,
                            root.theme.isDarkMode ? 0.15 : 0.10
                        )
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    // The SVG itself — sourceSize forces high-res rasterisation
                    Image {
                        id:               modeIcon
                        anchors.centerIn: parent
                        source:           root.iconPath
                        sourceSize:       Qt.size(40, 40)
                        width:            40
                        height:           40
                        smooth:           true
                        antialiasing:     true
                        fillMode:         Image.PreserveAspectFit

                        // Tint the SVG with the accent color via ColorOverlay-style layer
                        //layer.enabled: true
                        //layer.effect: null  // SVGs with own colors — keep as-is

                        // Pop in when icon changes
                        SequentialAnimation {
                            id: iconSwap
                            running: false
                            NumberAnimation {
                                target: modeIcon; property: "scale"
                                from: 0.7; to: 1.0; duration: 220
                                easing.type: Easing.OutBack; easing.overshoot: 1.4
                            }
                        }
                    }

                    // Trigger pop animation on source change
                    Connections {
                        target: root
                        function onIconPathChanged() { iconSwap.restart() }
                    }
                }

                // Text column
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing:          3

                    Text {
                        text:              root.labelText
                        font.family:       root.theme.textFont
                        font.pixelSize:    17
                        font.weight:       Font.Bold
                        color:             root.theme.textPrimary
                        Layout.fillWidth:  true
                        elide:             Text.ElideRight
                    }

                    Text {
                        text:             root.sublabel
                        font.family:      root.theme.textFont
                        font.pixelSize:   13
                        font.weight:      Font.Medium
                        color:            root.accentColor
                        Layout.fillWidth: true
                        opacity:          0.90

                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }
    }
}