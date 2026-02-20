import QtQuick
import QtQuick.Layouts
import "../lib" as Lib
import "../theme.js" as Theme

Lib.Card {
    id: root
    Layout.fillWidth: true

    property bool active: false

    readonly property bool themed: root.theme !== null
    readonly property color textPrimary: themed ? root.theme.textPrimary : Theme.fgMain
    readonly property color textSecondary: themed ? root.theme.textSecondary : Theme.fgMuted
    readonly property color accent: themed ? root.theme.accent : Theme.accent
    readonly property color accentAlt: themed ? root.theme.accentSlider : Theme.accentBlue

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

    Lib.CommandPoll {
        id: batteryPoll
        running: root.active && root.visible
        interval: 8000
        command: ["bash", "-lc", "upower -i /org/freedesktop/UPower/devices/battery_BAT1 2>/dev/null || true"]
        parse: function(out) {
            var info = {
                percentage: 0,
                capacity: 0,
                cycles: 0,
                energyFull: "",
                energyFullDesign: "",
                timeRemaining: "",
                state: ""
            }

            var lines = String(out || "").split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (!line || line.indexOf(":") === -1) continue

                var parts = line.split(":")
                var key = parts.shift().trim().toLowerCase()
                var value = parts.join(":").trim()

                if (key === "percentage") info.percentage = parseFloat(value)
                else if (key === "capacity") info.capacity = parseFloat(value)
                else if (key === "charge cycles" || key === "charge-cycles") info.cycles = parseInt(value)
                else if (key === "energy-full") info.energyFull = value
                else if (key === "energy-full-design") info.energyFullDesign = value
                else if (key === "time to empty" || key === "time to full") info.timeRemaining = value
                else if (key === "state") info.state = value
            }

            return info
        }
    }

    // Null safeties
    readonly property var batteryInfo: batteryPoll.value || ({})
    // Clamp health percentage
    readonly property real healthPercent: Math.max(0, Math.min(100, Number(batteryInfo.capacity) || 0))
    readonly property string cyclesText: isFinite(batteryInfo.cycles) && batteryInfo.cycles > 0
        ? String(batteryInfo.cycles)
        : "—"
    readonly property string energyText: (batteryInfo.energyFull && batteryInfo.energyFullDesign)
        ? (batteryInfo.energyFull + " / " + batteryInfo.energyFullDesign)
        : "—"
    readonly property string timeText: batteryInfo.timeRemaining
        || (batteryInfo.state === "fully-charged" ? "Full" : "—")
    readonly property string stateText: batteryInfo.state
        ? (batteryInfo.state.charAt(0).toUpperCase() + batteryInfo.state.slice(1))
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
                font.family: Theme.textFont
                font.pixelSize: 10
                font.weight: Font.DemiBold  
            }
            
            Text {
                text: "󱟢"
                color: root.textPrimary
                font.family: Theme.textFont 
                font.pixelSize: 20 // Set the battery icon size independently 
                Layout.fillWidth: true 
                horizontalAlignment: Text.AlignLeft 
            }

            Text {
                text: root.stateText
                color: root.textSecondary
                font.family: Theme.textFont
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
                    font.family: Theme.textFont
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }

                Text {
                    text: "Charge " + Math.round(Number(batteryInfo.percentage) || 0) + "%"
                    color: root.textSecondary
                    font.family: Theme.textFont
                    font.pixelSize: 10
                }
            }
            // Health Bar 
            Rectangle {
                id: barTrack
                Layout.fillWidth: true
                height: 7
                radius: 4
                color: themed ? root.theme.bgItem : Theme.bgItem

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
                    font.family: Theme.textFont
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: root.cyclesText
                    color: root.textPrimary
                    font.family: Theme.textFont
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
                    font.family: Theme.textFont
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: root.energyText
                    color: root.textPrimary
                    font.family: Theme.textFont
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
                    font.family: Theme.textFont
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: root.timeText
                    color: root.textPrimary
                    font.family: Theme.textFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }
    }
}