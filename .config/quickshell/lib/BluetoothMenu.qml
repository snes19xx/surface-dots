import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Overlay kept loaded by the shell, same pattern as WifiMenu.qml. Right-click
// the Hub's Bluetooth pill opens this instead of the old rfkill-toggle-only +
// external blueman-manager combo -- real device list, connect/disconnect/pair/
// forget, all in the same visual language as the rest of the shell.

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "bluetooth-menu"

    focusable: true

    // Runs either as its own process or as an overlay inside the shell; the
    // embedded case must not tear the whole shell down when it closes
    property bool standalone: true
    signal closeRequested()
    function dismiss() {
        if (root.standalone) Qt.quit()
        else root.closeRequested()
    }

    // A Shortcut is application-wide, so it will work even if the menu is not focused
    Shortcut { sequence: "Esc"; enabled: root.visible; onActivated: root.dismiss() }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: (mouse) => {
            const inside = mouse.x >= card.x && mouse.x <= (card.x + card.width) &&
                           mouse.y >= card.y && mouse.y <= (card.y + card.height)
            if (!inside) root.dismiss()
        }
    }

    // -------- Theme (mirrors WifiMenu.qml's palette) --------
    readonly property bool isDarkMode: ThemeState.isDarkMode

    readonly property color cCard:   isDarkMode ? "#282c2d" : "#F0ECE6"
    readonly property color cItem:   isDarkMode ? "#323738" : "#cb97a382"
    readonly property color cItemHv: isDarkMode ? "#3c4243" : "#e697a382"
    readonly property color cFg:     isDarkMode ? "#D3C6AA" : "#1e2326"
    readonly property color cMuted:  isDarkMode ? "#859289" : "#4d6049"
    readonly property color cBorder: isDarkMode ? "#d4708154" : "#d4586a3c"
    readonly property color cGreen:  isDarkMode ? "#A7C080" : "#576830"
    readonly property color cRed:    isDarkMode ? "#E67E80" : "#b13c3a"
    readonly property int   cRadius: 10
    readonly property string fontText: "Inter"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"

    // -------- State --------
    property bool powered: false
    property bool scanning: false
    property string busyMac: ""
    property var devices: []   // [{mac, name, paired, connected}]

    function iconFor(name) {
        var n = (name || "").toLowerCase()
        if (n.includes("buds") || n.includes("headphone") || n.includes("headset") || n.includes("airpod")) return "󰋋"
        if (n.includes("mouse")) return "󰍽"
        if (n.includes("keyboard")) return "󰌌"
        if (n.includes("speaker")) return "󰓃"
        if (n.includes("watch")) return "󰥔"
        if (n.includes("phone")) return ""
        return "󰂯"
    }

    function parseDeviceLines(text) {
        var out = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$/)
            if (m) out[m[1]] = m[2].trim()
        }
        return out
    }

    Process {
        id: statusPoll
        command: ["bash", "-c", `
            bluetoothctl show | grep -q "Powered: yes" && echo "POWERED:1" || echo "POWERED:0"
            echo "===ALL==="
            bluetoothctl devices
            echo "===PAIRED==="
            bluetoothctl devices Paired
            echo "===CONNECTED==="
            bluetoothctl devices Connected
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var chunks = text.split("===")
                // chunks[0] = "POWERED:x\n", then alternating "ALL===\n<data>", "PAIRED===\n<data>"...
                var head = chunks[0] || ""
                root.powered = head.includes("POWERED:1")

                var all = {}, paired = {}, connected = {}
                for (var i = 1; i < chunks.length; i += 2) {
                    var label = chunks[i]
                    var body = chunks[i + 1] || ""
                    if (label === "ALL") all = root.parseDeviceLines(body)
                    else if (label === "PAIRED") paired = root.parseDeviceLines(body)
                    else if (label === "CONNECTED") connected = root.parseDeviceLines(body)
                }

                var list = []
                for (var mac in all) {
                    list.push({
                        mac: mac,
                        name: all[mac],
                        paired: !!paired[mac],
                        connected: !!connected[mac]
                    })
                }
                list.sort(function(a, b) {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1
                    if (a.paired !== b.paired) return a.paired ? -1 : 1
                    return a.name.localeCompare(b.name)
                })
                root.devices = list
            }
        }
    }

    // the shell keeps this loaded, so only poll while it is actually on screen
    Timer {
        interval: 3000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: if (!statusPoll.running) statusPoll.running = true
    }

    function togglePower() {
        root.powered = !root.powered
        Quickshell.execDetached(["bash", "-c", "bluetoothctl power " + (root.powered ? "on" : "off")])
    }

    function toggleConnect(dev) {
        root.busyMac = dev.mac
        var cmd = dev.connected
            ? "bluetoothctl disconnect " + dev.mac
            : (dev.paired
                ? "bluetoothctl connect " + dev.mac
                : "bluetoothctl pair " + dev.mac + " && bluetoothctl trust " + dev.mac + " && bluetoothctl connect " + dev.mac)
        Quickshell.execDetached(["bash", "-c", cmd + "; sleep 1"])
        busyResetTimer.restart()
    }
    Timer { id: busyResetTimer; interval: 4000; onTriggered: root.busyMac = "" }

    function forget(dev) {
        Quickshell.execDetached(["bash", "-c", "bluetoothctl remove " + dev.mac])
    }

    function toggleScan() {
        root.scanning = !root.scanning
        if (root.scanning) {
            Quickshell.execDetached(["bash", "-c", "timeout 10 bluetoothctl scan on"])
            scanStopTimer.restart()
        } else {
            Quickshell.execDetached(["bash", "-c", "bluetoothctl scan off"])
        }
    }
    Timer { id: scanStopTimer; interval: 10000; onTriggered: root.scanning = false }

    Rectangle {
        id: card
        width: 340
        height: Math.ceil(mainLayout.implicitHeight + 24)
        // the popup opens from whichever corner the bar is in, so the two
        // layouts keep the placement they each had before this file merged them
        readonly property bool topStyle: Configuration.barStyle === "top"
        anchors.right: parent.right
        anchors.top: topStyle ? parent.top : undefined
        anchors.bottom: topStyle ? undefined : parent.bottom
        anchors.rightMargin: topStyle ? 14 : 10
        anchors.topMargin: 52
        anchors.bottomMargin: 48
        color: cCard
        radius: cRadius
        border.width: 1
        border.color: cBorder
        clip: true

        ColumnLayout {
            id: mainLayout
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Bluetooth"
                    color: root.cFg
                    font.family: root.fontText; font.pixelSize: 14; font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 40; height: 22; radius: 11
                    color: root.powered ? root.cGreen : root.cItem
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Rectangle {
                        x: root.powered ? parent.width - width - 3 : 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16; radius: 8; color: "white"
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePower() }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder; opacity: 0.5 }

            RowLayout {
                Layout.fillWidth: true
                visible: root.powered
                Text {
                    text: root.scanning ? "Scanning…" : "Devices"
                    color: root.cMuted
                    font.family: root.fontText; font.pixelSize: 11
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: scanLabel.implicitWidth + 16; height: 24; radius: 8
                    color: scanHov.hovered ? root.cItemHv : root.cItem
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        id: scanLabel
                        anchors.centerIn: parent
                        text: root.scanning ? "Stop" : "Scan"
                        color: root.cFg
                        font.family: root.fontText; font.pixelSize: 11
                    }
                    MouseArea { id: scanHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleScan() }
                }
            }

            Text {
                visible: !root.powered
                text: "Bluetooth is off"
                color: root.cMuted
                font.family: root.fontText; font.pixelSize: 12
                Layout.topMargin: 4; Layout.bottomMargin: 4
            }

            Text {
                visible: root.powered && root.devices.length === 0
                text: "No devices found -- try Scan"
                color: root.cMuted
                font.family: root.fontText; font.pixelSize: 12
                opacity: 0.8
                Layout.topMargin: 4; Layout.bottomMargin: 4
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.powered
                spacing: 4

                Repeater {
                    model: root.devices
                    delegate: Rectangle {
                        id: devRow
                        required property var modelData
                        readonly property bool isBusy: root.busyMac === modelData.mac

                        Layout.fillWidth: true
                        height: 44
                        radius: 8
                        color: rowHov.hovered ? root.cItemHv : root.cItem

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                            spacing: 8

                            Text {
                                text: root.iconFor(devRow.modelData.name)
                                font.family: root.fontIcon; font.pixelSize: 16
                                color: devRow.modelData.connected ? root.cGreen : root.cMuted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: devRow.modelData.name
                                    color: root.cFg
                                    font.family: root.fontText; font.pixelSize: 12; font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: devRow.isBusy ? "Working…"
                                        : devRow.modelData.connected ? "Connected"
                                        : devRow.modelData.paired ? "Paired" : "Available"
                                    color: devRow.modelData.connected ? root.cGreen : root.cMuted
                                    font.family: root.fontText; font.pixelSize: 10
                                }
                            }

                            Rectangle {
                                width: btnLabel.implicitWidth + 14; height: 24; radius: 8
                                color: devRow.modelData.connected ? Qt.rgba(root.cRed.r, root.cRed.g, root.cRed.b, 0.18) : root.cGreen
                                opacity: devRow.isBusy ? 0.5 : 1.0
                                Text {
                                    id: btnLabel
                                    anchors.centerIn: parent
                                    text: devRow.modelData.connected ? "Disconnect" : devRow.modelData.paired ? "Connect" : "Pair"
                                    color: devRow.modelData.connected ? root.cRed : "#232a2e"
                                    font.family: root.fontText; font.pixelSize: 10; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !devRow.isBusy
                                    onClicked: root.toggleConnect(devRow.modelData)
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onPressed: (m) => { if (m.button === Qt.RightButton) root.forget(devRow.modelData) }
                                }
                            }
                        }

                        MouseArea { id: rowHov; anchors.fill: parent; hoverEnabled: true; z: -1 }
                    }
                }
            }

            Text {
                visible: root.powered && root.devices.length > 0
                text: "Right-click a device to forget it"
                color: root.cMuted
                font.family: root.fontText; font.pixelSize: 10
                opacity: 0.6
                Layout.topMargin: 2
            }
        }
    }
}
