import QtQuick
import QtQuick.Layouts
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
    implicitHeight: 160
    color:          "transparent"
    visible:        false

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

    // Helpers 
    function brightnessIcon(p) {
        if (p >= 75) return "󰃠"
        if (p >= 40) return "󰃟"
        if (p >= 10) return "󰃞"
        return "󰃝"
    }

    // --- OSD--------------------------------------------------------------------------
    Item {
        anchors.fill: parent

        Item {
            id: card
            width:  300
            height: 110
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom:           parent.bottom
            anchors.bottomMargin:     40

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

                // inner glow
                Rectangle {
                    anchors { fill: parent; margins: 1 }
                    radius: root.theme.radiusOuter - 1
                    color:  Qt.rgba(
                        Qt.color(root.theme.accentSlider).r,
                        Qt.color(root.theme.accentSlider).g,
                        Qt.color(root.theme.accentSlider).b,
                        (root.percent / 100) * (root.theme.isDarkMode ? 0.06 : 0.04)
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

                // Left: icon + percent
                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: iconText
                        text:             root.brightnessIcon(root.percent)
                        font.family:      root.theme.iconFont
                        font.pixelSize:   28 + Math.round((root.percent / 100) * 6)
                        color:            root.theme.accentSlider
                        Layout.alignment: Qt.AlignHCenter

                        Behavior on font.pixelSize {
                            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                        }

                        SequentialAnimation {
                            id: iconPulse
                            NumberAnimation { target: iconText; property: "scale"; to: 1.18; duration: 90;  easing.type: Easing.OutQuad }
                            NumberAnimation { target: iconText; property: "scale"; to: 1.0;  duration: 180; easing.type: Easing.OutElastic }
                        }
                    }

                    Text {
                        text:             root.percent + "%"
                        font.family:      root.theme.textFont
                        font.pixelSize:   13
                        font.weight:      Font.Bold
                        color:            root.theme.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                        opacity:          0.85
                    }
                }

                // Right: label + bar
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 10

                    Text {
                        text:           "Brightness"
                        font.family:    root.theme.textFont
                        font.pixelSize: 11
                        font.weight:    Font.Medium
                        color:          root.theme.textSecondary
                        opacity:        0.7
                    }

                    // bar
                    Item {
                        id: barArea
                        Layout.fillWidth: true
                        height: 20       

                        // Track
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

                        // Fill
                        Rectangle {
                            height: barTrack.height
                            width:  Math.max(barTrack.radius * 2,
                                             barTrack.width * (root.percent / 100.0))
                            radius: barTrack.radius
                            anchors.verticalCenter: barTrack.verticalCenter

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: Qt.darker(root.theme.accentSlider,
                                                     root.theme.isDarkMode ? 1.15 : 1.05)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Qt.lighter(root.theme.accentSlider,
                                                      root.theme.isDarkMode ? 1.25 : 1.15)
                                }
                            }

                            Behavior on width {
                                NumberAnimation { duration: root.isDragging ? 0 : 120; easing.type: Easing.OutQuad }
                            }

                            // Thumb — pops out while dragging
                            Rectangle {
                                id: thumb
                                width:  root.isDragging ? 18 : 14
                                height: width
                                radius: width / 2
                                anchors {
                                    right:          parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Qt.lighter(root.theme.accentSlider,
                                                  root.theme.isDarkMode ? 1.4 : 1.1)

                                Behavior on width {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                }

                                Rectangle {
                                    width:   7; height: 7; radius: 3.5
                                    anchors.centerIn: parent
                                    color:   "white"
                                    opacity: root.theme.isDarkMode ? 0.75 : 0.5
                                }
                            }
                        }

                        // Tick marks at 25 / 50 / 75
                        Repeater {
                            model: [0.25, 0.50, 0.75]
                            delegate: Rectangle {
                                required property var modelData
                                x:       barTrack.width * modelData - width / 2
                                y:       (barTrack.height - height) / 2
                                         + (barArea.height - barTrack.height) / 2
                                width:   1
                                height:  barTrack.height
                                color:   root.theme.isDarkMode
                                         ? Qt.rgba(1,1,1,0.12)
                                         : Qt.rgba(0,0,0,0.10)
                                visible: (root.percent / 100) < modelData
                            }
                        }

                        // Mouse interaction
                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor

                            function percentFromX(mx) {
                                return Math.round(Math.max(1, Math.min(100,
                                    (mx / barTrack.width) * 100)))
                            }

                            onPressed: mouse => {
                                root.isDragging = true
                                root.osdVisible = true
                                hideTimer.stop()
                                root._setBrightness(percentFromX(mouse.x))
                            }

                            onPositionChanged: mouse => {
                                if (!pressed) return
                                root._setBrightness(percentFromX(mouse.x))
                            }

                            onReleased: {
                                root.isDragging = false
                                localHold.restart()
                                hideTimer.restart()
                            }

                            // Scroll wheel on the bar too
                            onWheel: wheel => {
                                var delta = wheel.angleDelta.y > 0 ? 5 : -5
                                root._setBrightness(root.percent + delta)
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
            function onPercentChanged() { iconPulse.restart() }
        }
    }
}
