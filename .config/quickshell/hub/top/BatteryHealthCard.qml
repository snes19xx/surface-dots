import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.UPower
import "../../lib" as Lib

Lib.TopCard {
    id: root
    Layout.fillWidth: true

    property bool active: false

    readonly property bool themed: root.theme !== null
    readonly property color textPrimary:   themed ? root.theme.textPrimary   : "#d3c6aa"
    readonly property color textSecondary: themed ? root.theme.textSecondary : "#9da9a0"
    readonly property color accent:        themed ? root.theme.accent        : "#a7c080"
    readonly property color accentAlt:     themed ? root.theme.accentSlider  : "#7AA1A6"

    property real contentHeight: contentLayout.implicitHeight + (root.pad * 2)

    // smooth expand/collapse animation based on active state
    implicitHeight: root.active ? contentHeight : 0
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

    //NO rendering when collapsed
    visible: implicitHeight > 1
    clip: true

    // Regular hover/Spotlight background effect
    Rectangle {
        parent: root
        anchors.fill: parent
        radius: root.radius
        color: themed ? root.theme.hoverSpotlight : Qt.rgba(1, 1, 1, 0.08)
        opacity: root.active ? (root.isDark ? 0.18 : 0.08) : 0
        z: 0
    }

    // upower has no cycle count or design energy property, read them once per open
    property var extra: ({ cycles: 0, energyFull: "", energyFullDesign: "" })
    Process {
        id: extraProc
        command: ["bash", "-lc", "DEV=$(upower -e 2>/dev/null | grep -m1 -i battery); [ -n \"$DEV\" ] && upower -i \"$DEV\" 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text)
                var c = t.match(/charge-cycles:\s*(\d+)/)
                var f = t.match(/energy-full:\s*(.+)/)
                var d = t.match(/energy-full-design:\s*(.+)/)
                root.extra = {
                    cycles: c ? parseInt(c[1]) : 0,
                    energyFull: f ? f[1].trim() : "",
                    energyFullDesign: d ? d[1].trim() : ""
                }
            }
        }
    }
    onActiveChanged: if (active && !extraProc.running) extraProc.running = true

    // Clamp health percentage
    readonly property real healthPercent: Lib.Battery.healthSupported
        ? Math.max(0, Math.min(100, Lib.Battery.healthPercent)) : 0
    readonly property string cyclesText: extra.cycles > 0 ? String(extra.cycles) : "—"
    readonly property string energyText: (extra.energyFull && extra.energyFullDesign)
        ? (extra.energyFull + " / " + extra.energyFullDesign)
        : "—"
    readonly property string timeText: Lib.Battery.formatDuration(
            Lib.Battery.state === UPowerDeviceState.Charging ? Lib.Battery.timeToFull : Lib.Battery.timeToEmpty)
        || (Lib.Battery.state === UPowerDeviceState.FullyCharged ? "Full" : "—")
    readonly property string stateText: Lib.Battery.present
        ? Lib.Battery.stateText
        : "Unknown"

    ColumnLayout {
        id: contentLayout
        spacing: 8
        Layout.fillWidth: true
        z: 1

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: "Battery Health  "
                color: root.textPrimary
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Text {
                text: "󱟢"
                color: root.textPrimary
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 20 // Set the battery icon size independently
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
            }

            Text {
                text: root.stateText
                color: root.textSecondary
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 10
            }
        }

        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: Math.round(root.healthPercent) + "% capacity"
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }

                Text {
                    text: "Charge " + Lib.Battery.percent + "%"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 10
                }
            }
            // Health Bar
            Rectangle {
                id: barTrack
                Layout.fillWidth: true
                height: 7
                radius: 4
                color: themed ? root.theme.bgItem : "#2d353b"

                Rectangle {
                    id: barFill
                    height: parent.height
                    radius: parent.radius
                    width: Math.max(4, parent.width * (root.healthPercent / 100))
                    color: root.accentAlt
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 1

                Text {
                    text: "Cycles"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: root.cyclesText
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                spacing: 1

                Text {
                    text: "Energy (full / design)"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: root.energyText
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1.5
                spacing: 1

                Text {
                    text: "Time remaining"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: root.timeText
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }
    }
}
