import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Lib.Card {
    id: root
    Layout.fillWidth: true
    property bool active: false

    // Theme Bindings 
    readonly property color textPrimary: root.theme.textPrimary
    readonly property color textSecondary: root.theme.textSecondary
    readonly property color accent: root.theme.accent
    readonly property color accentAlt: root.theme.accentSlider
    readonly property color bgItem: root.theme.bgItem
    readonly property color bgCard: root.theme.bgCard
    readonly property color healthColor: Qt.rgba(root.theme.accentSlider.r, root.theme.accentSlider.g, root.theme.accentSlider.b, 0.5)

    property real contentHeight: mainLayout.implicitHeight + (root.pad * 2) 

    implicitHeight: root.active ? contentHeight : 0
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

    visible: implicitHeight > 1
    clip: true

    // Hover spotlight
    Rectangle {
        parent: root; anchors.fill: parent; radius: root.radius
        color: root.theme.hoverSpotlight
        opacity: root.active ? (root.theme.isDarkMode ? 0.18 : 0.08) : 0
    }


    // DATA POLLERS
    Lib.CommandPoll {
        id: sysInfo
        running: root.active && root.visible
        interval: 600000 
        command: ["uname", "-r"]
        parse: function(out) { return String(out).trim() }
    }

    Lib.CommandPoll {
        id: cpu
        running: root.active && root.visible
        interval: 3000
        property var prevIdle: 0; property var prevTotal: 0
        command: ["bash","-lc","grep 'cpu ' /proc/stat"]
        parse: function(out) {
            var parts = String(out).split(/\s+/)
            var idle = Number(parts[4]) + Number(parts[5])
            var total = 0
            for (var i=1; i<parts.length; i++) total += Number(parts[i])
            var diffTotal = total - prevTotal
            var usage = (diffTotal > 0) ? (1 - ((idle - prevIdle) / diffTotal)) * 100 : 0
            prevIdle = idle; prevTotal = total
            return Math.round(usage)
        }
    }

    Lib.CommandPoll {
        id: ram
        running: root.active && root.visible
        interval: 4000
        command: ["bash","-lc","awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END{ if(t>0) printf(\"%d\", (100-(a*100/t))); else print \"0\" }' /proc/meminfo || true"]
        parse: function(o) { return Number(String(o).trim()) || 0 }
    }

    Lib.CommandPoll {
        id: batteryPoll
        running: root.active && root.visible
        interval: 8000
        command: ["bash", "-lc", "upower -i /org/freedesktop/UPower/devices/battery_BAT1 2>/dev/null || true"]
        parse: function(out) {
            var info = { percentage: 0, capacity: 0, cycles: 0, state: "", time: "", energy: "" }
            var lines = String(out || "").split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                var parts = line.split(":")
                if (parts.length < 2) continue
                var k = parts[0].trim().toLowerCase()
                var v = parts[1].trim()
                
                if (k === "percentage") info.percentage = parseFloat(v)
                else if (k === "capacity") info.capacity = parseFloat(v)
                else if (k === "state") info.state = v
                else if (k.includes("time to")) info.time = v
                else if (k.includes("cycles")) info.cycles = parseInt(v)
                else if (k === "energy-full") info.energy = v
            }
            return info
        }
    }

    readonly property var bat: batteryPoll.value || {}
    readonly property int batP: Math.round(bat.percentage || 0)
    readonly property int batHealth: Math.round(bat.capacity || 100)
    readonly property string batState: bat.state ? (bat.state.charAt(0).toUpperCase() + bat.state.slice(1)) : "Unknown"
    readonly property bool isCharging: bat.state === "charging"


    // HELPERS
    function getStatusColor(percentage) {
        if (percentage > 75) {
            // Red for high
            return root.theme.isDarkMode 
                ? Qt.rgba(0.8, 0.3, 0.3, 0.25) 
                : Qt.rgba(1.0, 0.0, 0.0, 0.15)
        } else if (percentage > 50) {
            // Yellow/Orange tint for medium
            return root.theme.isDarkMode 
                ? Qt.rgba(0.8, 0.6, 0.2, 0.20) 
                : Qt.rgba(1.0, 0.7, 0.0, 0.15)
        }
        // Default background
        return root.bgItem
    }

    function getStatusIconColor(percentage) {
        if (percentage > 75) return root.theme.accentRed
        if (percentage > 50) return root.theme.isDarkMode ? "#e3be5c" : "#d4a017"
        return root.textPrimary
    }

    // UI LAYOUT
    ColumnLayout {
    id: mainLayout
    anchors.fill: parent  
    anchors.margins: root.pad
    anchors.bottomMargin: root.pad * 2  // bottom space
    spacing: 12

        // ROW 1: Kernel
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "System Status"
                color: root.textPrimary
                font.family: root.theme.textFont
                font.pixelSize: 11
                font.weight: Font.Bold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: sysInfo.value || "Linux"
                color: root.textSecondary
                font.family: root.theme.textFont
                font.pixelSize: 12
                //opacity: 0.99
            }
        }

        // ROW 2:
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 150 
            spacing: 12

            // LEFT GROUP: CPU & RAM 
            RowLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: 1 
                Layout.fillWidth: true
                spacing: 10

                // CPU
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 9
                    color: getStatusColor(cpu.value || 0)
                    Behavior on color { ColorAnimation { duration: 300 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: ""
                            font.family: root.theme.iconFont
                            font.pixelSize: 36
                            color: getStatusIconColor(cpu.value || 0)
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: (cpu.value || 0) + "%"
                            font.family: root.theme.textFont
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: root.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "CPU"
                            font.family: root.theme.textFont
                            font.pixelSize: 10
                            color: root.textSecondary
                            opacity: 0.9
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // RAM
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 9
                    color: getStatusColor(ram.value || 0)
                    Behavior on color { ColorAnimation { duration: 300 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: ""
                            font.family: root.theme.iconFont
                            font.pixelSize: 36
                            color: getStatusIconColor(ram.value || 0)
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: (ram.value || 0) + "%"
                            font.family: root.theme.textFont
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: root.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "RAM"
                            font.family: root.theme.textFont
                            font.pixelSize: 10
                            color: root.textSecondary
                            opacity: 0.9
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            // RIGHT: BATTERY CARD
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1.2 
                Layout.fillWidth: true
                Layout.preferredHeight: 1.2
                color: root.bgItem
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 8
                    anchors.bottomMargin: 22
                    spacing: 0

                    // Top Row: Label + State
                    RowLayout {
                        Layout.fillWidth: true
                        Text { 
                            text: "Battery"
                            color: root.textSecondary
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.family: root.theme.textFont 
                        }
                        Item { Layout.fillWidth: true }
                        Text { 
                            text: root.batState
                            color: root.textSecondary
                            font.pixelSize: 11
                            font.family: root.theme.textFont 
                            opacity: 0.6
                        }
                    }
                    

                    // Middle: Big Number + Icon
                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignLeft
                        
                        Text {
                            text: root.isCharging ? "󰂄" : "󱟢" 
                            color: root.isCharging ? root.theme.accentSlider : root.textPrimary
                            font.family: root.theme.iconFont
                            font.pixelSize: 24
                            Layout.alignment: Qt.AlignBaseline
                        }
                        Text {
                            text: root.batP + "%"
                            color: root.textPrimary
                            font.family: root.theme.textFont
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignBaseline
                        }
                    }

                   Item { Layout.fillHeight: true; Layout.preferredHeight: 2 } //spacer

                    // Bottom: Health Bar
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        RowLayout {
                            Text { text: "Overall Health"; color: root.textSecondary; font.pixelSize: 9; font.family: root.theme.textFont }
                            Item { Layout.fillWidth: true }
                            Text { text: root.batHealth + "%"; color: root.healthColor; font.pixelSize: 9; font.family: root.theme.textFont; font.weight: Font.Bold }
                        }
                        
                        // Capsule Bar
                        Rectangle {
                            Layout.fillWidth: true; height: 8; radius: 1; color: Qt.rgba(1,1,1,0.08)
                            Rectangle {
                                height: parent.height; radius: 3; color: root.healthColor
                                width: Math.max(3, parent.width * (root.batHealth / 100))
                                Behavior on width { NumberAnimation { duration: 250 } }
                            }
                        }
                    }

                    // Extra info (Time/Energy)
                    Text {
                        text: root.bat.time ? (root.bat.time + " remaining") : (root.bat.cycles + " Cycles")
                        color: root.textSecondary
                        font.family: root.theme.textFont
                        font.pixelSize: 11
                        opacity: 0.9
                        Layout.topMargin: 6
                    }
                    
                }
            }
        }
    }
}