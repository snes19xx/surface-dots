import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Output picker, bound straight to pipewire's nodes with no polling.
Item {
    id: panel

    required property var theme
    signal closeRequested()

    implicitHeight: content.implicitHeight

    readonly property var current: Pipewire.defaultAudioSink

    // media.class needs tracking first
    readonly property var sinks: {
        const out = []
        const all = Pipewire.nodes.values
        for (let i = 0; i < all.length; i++) {
            const n = all[i]
            if (!n.isSink || n.isStream) continue
            if (n.properties["media.class"] !== "Audio/Sink") continue
            out.push(n)
        }
        return out
    }

    readonly property var otherSinks: panel.sinks.filter(n => n !== panel.current)

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    }

    // audio is null until tracked
    readonly property bool currentReady:
        panel.current !== null && panel.current.audio !== null
    readonly property real currentVolume:
        panel.currentReady ? Math.max(0, Math.min(1, panel.current.audio.volume)) : 0
    readonly property bool currentMuted:
        panel.currentReady ? panel.current.audio.muted : false

    function label(node) {
        if (!node) return ""
        return node.nickname || node.description || node.name
    }

    function kind(node) {
        const n = String(node ? node.name : "")
        if (n.indexOf("bluez_") === 0) return "bluetooth"
        if (n.indexOf("HDMI") !== -1 || n.indexOf("hdmi") !== -1) return "hdmi"
        if (n.indexOf("usb") !== -1) return "usb"
        return "builtin"
    }

    function icon(node) {
        switch (panel.kind(node)) {
        case "bluetooth": return "\u{F02CB}"
        case "hdmi":      return "\u{F0379}"
        default:          return "\u{F00C3}"
        }
    }

    function subtitle(node) {
        if (node === panel.current) {
            return panel.currentMuted ? "Muted"
                : "Default, " + Math.round(panel.currentVolume * 100) + "%"
        }
        switch (panel.kind(node)) {
        case "bluetooth": return "Bluetooth"
        case "hdmi":      return "HDMI / DisplayPort"
        case "usb":       return "USB"
        default:          return "Built-in"
        }
    }

    function choose(node) {
        if (!node || node === panel.current) return
        Pipewire.preferredDefaultAudioSink = node
    }

    function toggleMute() {
        if (!panel.currentReady) return
        panel.current.audio.muted = !panel.current.audio.muted
    }

    // -------- Shared bits --------
    component SectionLabel: Text {
        font.family:      panel.theme.textFont
        font.pixelSize:   10
        font.weight:      Font.DemiBold
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color:            panel.theme.textSecondary
        opacity:          0.75
    }

    component LinkText: Text {
        id: link
        signal triggered()

        font.family:    panel.theme.textFont
        font.pixelSize: 12
        font.weight:    Font.Medium
        color:          linkHover.hovered ? panel.theme.accent : panel.theme.textSecondary
        Behavior on color { ColorAnimation { duration: 160 } }

        HoverHandler { id: linkHover }
        TapHandler { onTapped: link.triggered() }
    }

    component DeviceRow: Rectangle {
        id: row
        required property var node

        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: 12
        color: rowHover.hovered ? panel.theme.bgItemHover : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }

        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: panel.choose(row.node) }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 11

            Text {
                text: panel.icon(row.node)
                font.family:    panel.theme.iconFont
                font.pixelSize: 15
                color:          panel.theme.textSecondary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: panel.label(row.node)
                    font.family:    panel.theme.textFont
                    font.pixelSize: 13
                    font.weight:    Font.Medium
                    color:          panel.theme.textPrimary
                    elide:          Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: panel.subtitle(row.node)
                    font.family:    panel.theme.textFont
                    font.pixelSize: 10
                    color:          panel.theme.textSecondary
                    elide:          Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    // -------- UI --------
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 200
        maximumFlickVelocity: 2000

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (ev) => {
                var base = scrollAnim.running ? scrollAnim.to : flick.contentY
                var step = Math.abs(ev.angleDelta.y) * 1.1 + 20
                scrollAnim.to = Math.max(0, Math.min(
                    base + (ev.angleDelta.y > 0 ? -step : (ev.angleDelta.y < 0 ? step : 0)),
                    Math.max(0, flick.contentHeight - flick.height)))
                scrollAnim.restart()
                ev.accepted = true
            }
        }
        NumberAnimation {
            id: scrollAnim
            target: flick; property: "contentY"
            duration: 500; easing.type: Easing.OutExpo
        }

        ColumnLayout {
            id: content
            width: flick.width - (flick.contentHeight > flick.height ? 9 : 0)
            spacing: 14

            // HEADER
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2

                Text {
                    text: "Sound"
                    font.family:    panel.theme.textFont
                    font.pixelSize: 26
                    font.weight:    Font.DemiBold
                    color:          panel.theme.textPrimary
                }

                Item { Layout.fillWidth: true }

                LinkText {
                    text: "Back"
                    onTriggered: panel.closeRequested()
                }
            }

            // CURRENT OUTPUT
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                radius: 12
                color: panel.theme.subtleFill
                border.width: 1
                border.color: panel.current ? panel.theme.accent : panel.theme.outline
                Behavior on border.color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 12

                    Text {
                        text: panel.current ? panel.icon(panel.current) : "\u{F075F}"
                        font.family:    panel.theme.iconFont
                        font.pixelSize: 24
                        color:          panel.current ? panel.theme.accent : panel.theme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: panel.current ? panel.label(panel.current) : "No output"
                            font.family:    panel.theme.textFont
                            font.pixelSize: 14
                            font.weight:    Font.DemiBold
                            color:          panel.theme.textPrimary
                            elide:          Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: panel.current
                                ? (panel.currentMuted ? "Muted"
                                   : Math.round(panel.currentVolume * 100) + "% volume")
                                : "No audio device available"
                            font.family:    panel.theme.textFont
                            font.pixelSize: 11
                            color:          panel.theme.textSecondary
                            elide:          Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        visible: panel.currentReady
                        width: 34; height: 34
                        radius: 11
                        color: muteHover.hovered ? panel.theme.bgItemHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: panel.currentMuted ? "\u{F075F}" : "\u{F057E}"
                            font.family:    panel.theme.iconFont
                            font.pixelSize: 16
                            color:          panel.currentMuted ? panel.theme.accentRed
                                                               : panel.theme.textSecondary
                        }

                        HoverHandler { id: muteHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: panel.toggleMute() }
                    }
                }
            }

            // OTHER OUTPUTS
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                SectionLabel { text: "Outputs" }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    visible: panel.otherSinks.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "No other outputs"
                    font.family:    panel.theme.textFont
                    font.pixelSize: 12
                    color:          panel.theme.textSecondary
                }

                Repeater {
                    model: panel.otherSinks
                    DeviceRow { required property var modelData; node: modelData }
                }
            }
        }
    }
}
