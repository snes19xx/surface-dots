import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../lib" as Lib

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
    implicitHeight: 160
    color:          "transparent"
    visible:        false  

    // State 
    property int  volume:     80
    property bool muted:      false
    property bool isDragging: false
    property bool osdVisible: false
    property bool _ready:     false
    property bool isHeadphones: false

    // Headphone / bluetooth sink 
    Lib.CommandPoll {
        id: sinkPoll
        interval: 6000
        running: true
        command: ["bash", "-lc", "pactl get-default-sink 2>/dev/null || echo ''"]
        parse: function(o) {
            var s = String(o).trim().toLowerCase()
            return s.indexOf("bluez")      !== -1
                || s.indexOf("headphone")  !== -1
                || s.indexOf("headset")    !== -1
        }
        onUpdated: root.isHeadphones = Boolean(value)
    }

    // File watcher
    FileView {
        id: volWatcher
        path:         Quickshell.env("HOME") + "/.cache/quickshell/volume"
        watchChanges: true
        preload:      true
        onFileChanged: reload()
        onLoaded:      root._ready = true
        onTextChanged: root._handleVol(text())
    }

    function _handleVol(raw) {
        if (!root._ready) return
        if (root.isDragging) return
        var parts = raw.trim().split(":")
        if (parts.length < 2) return
        var v = parseInt(parts[0], 10)
        if (isNaN(v)) return
        root.volume     = Math.max(0, Math.min(100, v))
        root.muted      = (parts[1].trim() === "true")
        root.osdVisible = true
        hideTimer.restart()
    }

    // Pamixer (drag)
    Process {
        id: setVolProc
        running: false
    }

    Process {
        id: muteProc
        command: ["pamixer", "-t"]
        running: false
    }

    Timer {
        id: setVolThrottle
        interval: 40
        property int pendingVol: -1
        onTriggered: {
            if (pendingVol < 0) return
            setVolProc.command = ["pamixer", "--set-volume", pendingVol.toString()]
            setVolProc.running = true
            cacheWriter.setText(pendingVol + ":" + (root.muted ? "true" : "false") + "\n")
            cacheWriter.save()
            pendingVol = -1
        }
    }

    FileView {
        id: cacheWriter
        path: Quickshell.env("HOME") + "/.cache/quickshell/volume"
    }

    function _setVolume(v) {
        v = Math.max(0, Math.min(100, v))
        root.volume = v
        // mute state only changes via _toggleMute()
        setVolThrottle.pendingVol = v
        if (!setVolThrottle.running) setVolThrottle.start()
    }

    function _toggleMute() {
        muteProc.running = true
        root.muted      = !root.muted
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

    // Slider color
    readonly property color sliderColor: {
        var t  = Math.max(0, Math.min(1, (root.volume - 50) / 50.0))
        var c1 = Qt.color(root.theme.accentSlider)
        var c2 = Qt.color(root.theme.accentSlider2)
        return Qt.rgba(
            c1.r + (c2.r - c1.r) * t,
            c1.g + (c2.g - c1.g) * t,
            c1.b + (c2.b - c1.b) * t,
            1.0
        )
    }

    // Icon helper
    function volumeIcon(vol, muted) {
        if (muted || vol === 0) return "󰝟"
        if (vol < 35)           return "󰕿"
        if (vol < 70)           return "󰖀"
        return "󰕾"
    }

    // OSD 
    Item {
        anchors.fill: parent

        Item {
            id: card
            width:  300
            height: 110
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom:           parent.bottom
            anchors.bottomMargin:     48

            opacity: root.osdVisible ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration:    root.osdVisible ? 160 : 320
                    easing.type: root.osdVisible ? Easing.OutQuad : Easing.InCubic
                }
            }
            transform: Translate {
                y: root.osdVisible ? 0 : 22
                Behavior on y {
                    NumberAnimation {
                        duration:    root.osdVisible ? 240 : 340
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
                border.color: Qt.rgba(0, 0, 0, root.theme.isDarkMode ? 0.28 : 0.12)
                opacity: 0.6
            }

            // Background
            Rectangle {
                anchors.fill: parent
                radius:       root.theme.radiusOuter
                color:        root.theme.bgCard
                border.width: 1
                border.color: root.theme.outline

                Rectangle {
                    anchors { fill: parent; margins: 1 }
                    radius: root.theme.radiusOuter - 1
                    color: Qt.rgba(
                        Qt.color(root.theme.accentBlue).r,
                        Qt.color(root.theme.accentBlue).g,
                        Qt.color(root.theme.accentBlue).b,
                        root.muted ? 0.0 :
                        (root.volume / 100) * (root.theme.isDarkMode ? 0.05 : 0.03)
                    )
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }

            // Content 
            RowLayout {
                anchors {
                    fill:         parent
                    leftMargin:   22
                    rightMargin:  22
                }
                spacing: 18

                // Left: icon + percent — click to mute
                Item {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth:    48
                    implicitHeight:   60

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        // Icon — glyph when speakers, SVG when headphones
                        Item {
                            id: volIconWrapper
                            implicitWidth:  34
                            implicitHeight: 34
                            Layout.alignment: Qt.AlignHCenter

                            // Pulse animation 
                            SequentialAnimation {
                                id: volIconPulse
                                NumberAnimation {
                                    target:   volIconWrapper
                                    property: "scale"
                                    to:       1.22
                                    duration: 80
                                    easing.type: Easing.OutQuad
                                }
                                NumberAnimation {
                                    target:   volIconWrapper
                                    property: "scale"
                                    to:       1.0
                                    duration: 180
                                    easing.type: Easing.OutElastic
                                }
                            }

                            // Nerd-font glyph (speakers / muted)
                            Text {
                                id: volIcon
                                anchors.centerIn: parent
                                visible:          !root.isHeadphones
                                text:             root.volumeIcon(root.volume, root.muted)
                                font.family:      root.theme.iconFont
                                font.pixelSize:   28
                                color:            root.muted
                                                  ? root.theme.accentRed
                                                  : root.sliderColor
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            // SVG headphone icon 
                            Item {
                                id: hpIcon
                                anchors.centerIn: parent
                                width:  30
                                height: 30
                                visible: root.isHeadphones

                                Image {
                                    id: hpImg
                                    anchors.fill: parent
                                    source:       Qt.resolvedUrl("vol_headphones.svg")
                                    sourceSize:   Qt.size(30, 30)
                                    smooth:       true
                                    mipmap:       true
                                    visible:      false
                                }
                                ColorOverlay {
                                    anchors.fill: hpImg
                                    source:       hpImg
                                    color:        root.muted
                                                  ? root.theme.accentRed
                                                  : root.sliderColor
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }

                        Text {
                            text:             root.muted ? "muted" : root.volume + "%"
                            font.family:      root.theme.textFont
                            font.pixelSize:   11
                            font.weight:      Font.Bold
                            color:            root.muted
                                              ? root.theme.accentRed
                                              : root.theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                            opacity:          0.85
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    root._toggleMute()
                    }
                }

                // Right: label + bar
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 10

                    Text {
                        text:           "Volume"
                        font.family:    root.theme.textFont
                        font.pixelSize: 11
                        font.weight:    Font.Medium
                        color:          root.theme.textSecondary
                        opacity:        0.7
                    }

                    Item {
                        id: barArea
                        Layout.fillWidth: true
                        height: 20
                        opacity: root.muted ? 0.35 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Rectangle {
                            id:     barTrack
                            width:  parent.width
                            height: root.isDragging ? 10 : 8
                            anchors.verticalCenter: parent.verticalCenter
                            radius: height / 2
                            color:  root.theme.bgItem
                            Behavior on height {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }
                        }

                        Rectangle {
                            height: barTrack.height
                            width:  Math.max(barTrack.radius * 2,
                                             barTrack.width * (root.volume / 100.0))
                            radius: barTrack.radius
                            anchors.verticalCenter: barTrack.verticalCenter

                            color: root.sliderColor
                            Behavior on color {
                                ColorAnimation { duration: 400; easing.type: Easing.OutQuad }
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration:    root.isDragging ? 0 : 120
                                    easing.type: Easing.OutQuad
                                }
                            }

                            Rectangle {
                                width:  root.isDragging ? 18 : 14
                                height: width
                                radius: width / 2
                                anchors {
                                    right:          parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Qt.lighter(root.sliderColor,
                                                  root.theme.isDarkMode ? 1.4 : 1.1)
                                Behavior on width {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                }
                                Rectangle {
                                    width: 7; height: 7; radius: 3.5
                                    anchors.centerIn: parent
                                    color:   "white"
                                    opacity: root.theme.isDarkMode ? 0.75 : 0.5
                                }
                            }
                        }

                        Repeater {
                            model: [0.25, 0.5, 0.75]
                            delegate: Rectangle {
                                required property var modelData
                                x:       barTrack.width * modelData - 0.5
                                y:       (barTrack.height - height) / 2
                                         + (barArea.height - barTrack.height) / 2
                                width:   1
                                height:  barTrack.height
                                color:   root.theme.isDarkMode
                                         ? Qt.rgba(1,1,1,0.12)
                                         : Qt.rgba(0,0,0,0.10)
                                visible: (root.volume / 100) < modelData
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor

                            function volFromX(mx) {
                                return Math.round(Math.max(0, Math.min(100,
                                    (mx / barTrack.width) * 100)))
                            }

                            onPressed: mouse => {
                                root.isDragging = true
                                root.osdVisible = true
                                hideTimer.stop()
                                root._setVolume(volFromX(mouse.x))
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return
                                root._setVolume(volFromX(mouse.x))
                            }
                            onReleased: {
                                root.isDragging = false
                                hideTimer.restart()
                            }
                            onWheel: wheel => {
                                var delta = wheel.angleDelta.y > 0 ? 5 : -5
                                root._setVolume(root.volume + delta)
                                root.osdVisible = true
                                hideTimer.restart()
                            }
                        }
                    }
                }
            }
        }

        Connections {
            target: root
            function onVolumeChanged() { volIconPulse.restart() }
            function onMutedChanged()  { volIconPulse.restart() }
        }
    }
}
