import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: win

    required property var theme

    signal moreOptionsRequested()

    WlrLayershell.layer:     WlrLayer.Overlay
    WlrLayershell.namespace: "monitor-prompt"
    WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    focusable: visible

    anchors { bottom: true; left: true; right: true }
    exclusiveZone:  0
    implicitHeight: 300
    color:          "transparent"
    visible:        false

    // STATE
    property var    mon: null
    property string phase: "pick"      // pick | confirm
    property string chosen: ""
    property bool   rememberOn: false
    property int    countdown: 10
    property bool   shown: false

    readonly property string monTitle: mon ? (mon.description || mon.name) : ""
    readonly property string monSub: mon
        ? (mon.name + "  ·  " + mon.width + "x" + mon.height)
        : ""

    function open(m) {
        win.mon        = m
        win.phase      = "pick"
        win.chosen     = ""
        win.rememberOn = false
        win.visible    = true
        win.shown      = true
        toastTimer.stop()
        root.forceActiveFocus()
    }

    // Configured screens apply their own rules. This just says so,
    // and offers the picker for the times you want something different.
    function notify(m) {
        if (win.phase === "pick" || win.phase === "confirm") return
        win.mon     = m
        win.phase   = "toast"
        win.visible = true
        win.shown   = true
        toastTimer.restart()
    }

    function close() {
        win.shown = false
        win.phase = "pick"
        hideTimer.restart()
    }

    function choose(layout) {
        if (!win.mon) return
        win.chosen = layout
        if (win.rememberOn) MonitorService.remember(MonitorService.keyFor(win.mon), layout)
        MonitorService.apply(layout, win.mon, true)
        win.phase = "confirm"
        win.countdown = 10
        countdownTimer.restart()
    }

    function keep() {
        countdownTimer.stop()
        MonitorService.appliedLayout = ""
        win.close()
    }

    function revert() {
        countdownTimer.stop()
        if (win.rememberOn && win.mon) MonitorService.forget(MonitorService.keyFor(win.mon))
        MonitorService.revert()
        win.phase = "pick"
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            win.countdown -= 1
            if (win.countdown <= 0) win.revert()
        }
    }

    Timer {
        id: hideTimer
        interval: 260
        onTriggered: win.visible = false
    }

    Timer {
        id: toastTimer
        interval: 5000
        onTriggered: if (win.phase === "toast") win.close()
    }

    Item {
        id: root
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: win.phase === "pick" ? win.close() : win.revert()
        Keys.onPressed: (event) => {
            if (win.phase !== "pick") return
            if      (event.key === Qt.Key_1) { win.choose("extend");    event.accepted = true }
            else if (event.key === Qt.Key_2) { win.choose("duplicate"); event.accepted = true }
            else if (event.key === Qt.Key_3) { win.choose("laptop");    event.accepted = true }
            else if (event.key === Qt.Key_4) { win.choose("external");  event.accepted = true }
        }

        Rectangle {
            id: card
            width:  win.phase === "toast" ? 340 : 470
            height: win.phase === "pick" ? 196 : (win.phase === "confirm" ? 150 : 64)
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            radius: win.theme.radiusOuter
            color:  win.theme.bgCard
            border.width: 1
            border.color: win.theme.outline

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom:           parent.bottom
            anchors.bottomMargin:     52

            Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            opacity: win.shown ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration:    win.shown ? 280 : 230
                    easing.type: win.shown ? Easing.OutCubic : Easing.InCubic
                }
            }

            transform: [
                Scale {
                    xScale: win.shown ? 1.0 : 0.97
                    yScale: win.shown ? 1.0 : 0.97
                    origin.x: card.width / 2
                    origin.y: card.height
                    Behavior on xScale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on yScale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                },
                Translate {
                    y: win.shown ? 0 : card.height
                    Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                }
            ]

            // PICKER
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                opacity: win.phase === "pick" ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "New display connected"
                        font.family:    win.theme.textFont
                        font.pixelSize: 15
                        font.weight:    Font.Bold
                        color:          win.theme.textPrimary
                    }
                    Text {
                        text: win.monTitle
                        font.family:    win.theme.textFont
                        font.pixelSize: 12
                        color:          win.theme.textSecondary
                        elide:          Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { key: "extend",    label: "Extend",   icon: "mon_extend.svg" },
                            { key: "duplicate", label: "Duplicate", icon: "mon_duplicate.svg" },
                            { key: "laptop",    label: "Laptop",   icon: "mon_laptop.svg" },
                            { key: "external",  label: "External", icon: "mon_external.svg" }
                        ]

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 84
                            radius: win.theme.radiusOuter - 4
                            color:  tileHover.hovered ? win.theme.bgItemHover : win.theme.bgItem
                            Behavior on color { ColorAnimation { duration: 200 } }

                            scale: tileHover.hovered ? 1.017 : 1.0
                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                            HoverHandler { id: tileHover }
                            TapHandler { onTapped: win.choose(modelData.key) }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 40
                                    implicitHeight: 30

                                    Image {
                                        id: tileIcon
                                        anchors.centerIn: parent
                                        source:     Qt.resolvedUrl(modelData.icon)
                                        sourceSize: Qt.size(40, 30)
                                        smooth:     true
                                        visible:    false
                                    }
                                    ColorOverlay {
                                        anchors.fill: tileIcon
                                        source: tileIcon
                                        color:  tileHover.hovered ? win.theme.accent : win.theme.textPrimary
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    font.family:    win.theme.textFont
                                    font.pixelSize: 11
                                    font.weight:    Font.Medium
                                    color:          win.theme.textPrimary
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 16; height: 16; radius: 8
                        color: win.rememberOn ? win.theme.accent : "transparent"
                        border.width: 1
                        border.color: win.rememberOn ? win.theme.accent : win.theme.textSecondary
                        Behavior on color { ColorAnimation { duration: 160 } }
                        TapHandler { onTapped: win.rememberOn = !win.rememberOn }
                    }

                    Text {
                        text: "remember this screen"
                        font.family:    win.theme.textFont
                        font.pixelSize: 11
                        color:          win.theme.textSecondary
                        TapHandler { onTapped: win.rememberOn = !win.rememberOn }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "more options ▸"
                        font.family:    win.theme.textFont
                        font.pixelSize: 11
                        color:          moreHover.hovered ? win.theme.accent : win.theme.textSecondary
                        Behavior on color { ColorAnimation { duration: 160 } }
                        HoverHandler { id: moreHover }
                        TapHandler { onTapped: { win.moreOptionsRequested(); win.close() } }
                    }
                }
            }

            // TOAST
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10
                opacity: win.phase === "toast" ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: win.theme.accent
                }

                Text {
                    Layout.fillWidth: true
                    text: win.monTitle
                    font.family:    win.theme.textFont
                    font.pixelSize: 12
                    color:          win.theme.textPrimary
                    elide:          Text.ElideRight
                }

                Text {
                    text: "change ▸"
                    font.family:    win.theme.textFont
                    font.pixelSize: 11
                    color:          toastHover.hovered ? win.theme.accent : win.theme.textSecondary
                    Behavior on color { ColorAnimation { duration: 160 } }
                    HoverHandler { id: toastHover }
                    TapHandler { onTapped: win.open(win.mon) }
                }
            }

            // CONFIRM
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12
                opacity: win.phase === "confirm" ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Keep this display setup?"
                        font.family:    win.theme.textFont
                        font.pixelSize: 15
                        font.weight:    Font.Bold
                        color:          win.theme.textPrimary
                    }
                    Text {
                        text: "Reverting in " + win.countdown + "s"
                        font.family:    win.theme.textFont
                        font.pixelSize: 11
                        color:          win.theme.accentRed
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: [
                            { label: "Keep",   primary: true },
                            { label: "Revert", primary: false }
                        ]

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: win.theme.radiusOuter - 4
                            color: modelData.primary
                                ? (btnHover.hovered ? win.theme.accent : Qt.rgba(win.theme.accent.r, win.theme.accent.g, win.theme.accent.b, 0.35))
                                : (btnHover.hovered ? win.theme.bgItemHover : win.theme.bgItem)
                            Behavior on color { ColorAnimation { duration: 200 } }

                            HoverHandler { id: btnHover }
                            TapHandler { onTapped: modelData.primary ? win.keep() : win.revert() }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family:    win.theme.textFont
                                font.pixelSize: 12
                                font.weight:    Font.Medium
                                color:          win.theme.textPrimary
                            }
                        }
                    }
                }
            }
        }
    }
}
