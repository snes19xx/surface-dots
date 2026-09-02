import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../lib" as Lib

// Bluetooth panel for the hub.
Item {
    id: panel

    required property var theme
    signal closeRequested()
    signal toastRequested(string msg)

    // Set by the hub while this panel is the visible content.
    property bool live: false

    implicitHeight: content.implicitHeight

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterOn: panel.adapter ? panel.adapter.enabled : false
    readonly property bool adapterBusy: panel.adapter
        ? (panel.adapter.state === BluetoothAdapterState.Enabling
           || panel.adapter.state === BluetoothAdapterState.Disabling)
        : false
    readonly property bool adapterBlocked: panel.adapter
        ? panel.adapter.state === BluetoothAdapterState.Blocked : false

    readonly property var allDevices: (panel.adapter && panel.adapter.devices)
        ? panel.adapter.devices.values : []

    // A device can be connected without being paired, so these partition the
    // list
    readonly property var connectedDevices: panel.allDevices.filter(d => d.connected)
    readonly property var pairedDevices: panel.allDevices.filter(d => !d.connected && (d.paired || d.bonded))
    readonly property var nearbyDevices: panel.allDevices.filter(d => !d.connected && !d.paired && !d.bonded)

    property string statusLine: ""
    property bool statusBad: false

    // Device asked to pair, so it can be connected once bluez says success
    property var pairingDevice: null
    // "forget this device" confirmation.
    property var forgetDevice: null
    // Still name the device after the prompt closes
    property string forgetLabel: ""

    Timer {
        id: statusTimer
        interval: 3200
        onTriggered: panel.statusLine = ""
    }

    function setStatus(msg, bad) {
        panel.statusLine = msg
        panel.statusBad = !!bad
        statusTimer.restart()
    }

    function deviceLabel(dev) {
        if (!dev) return ""
        return dev.deviceName || dev.name || dev.address || "Unknown device"
    }

    function isAnonymous(dev) {
        if (!dev) return false
        const n = String(panel.deviceLabel(dev)).replace(/[-:]/g, "").toLowerCase()
        const a = String(dev.address || "").replace(/[-:]/g, "").toLowerCase()
        return a.length > 0 && n === a
    }

    function deviceIcon(dev) {
        const n = String(dev && dev.icon ? dev.icon : "")
        if (n.indexOf("headset") !== -1 || n.indexOf("headphone") !== -1) return "󰋋"
        if (n.indexOf("audio") !== -1 || n.indexOf("speaker") !== -1) return "󰓃"
        if (n.indexOf("mouse") !== -1) return "󰍽"
        if (n.indexOf("keyboard") !== -1) return "󰌌"
        if (n.indexOf("gaming") !== -1 || n.indexOf("joypad") !== -1) return "󰊴"
        if (n.indexOf("phone") !== -1) return "󰄜"
        if (n.indexOf("computer") !== -1) return "󰟀"
        if (n.indexOf("printer") !== -1) return "󰐪"
        if (n.indexOf("camera") !== -1) return "󰄀"
        if (n.indexOf("watch") !== -1) return "󰥔"
        if (n.indexOf("display") !== -1 || n.indexOf("tv") !== -1) return "󰓶"
        return "󰂯"
    }

    function batteryText(dev) {
        if (!dev || !dev.batteryAvailable) return ""
        const b = dev.battery
        return Math.round(b <= 1 ? b * 100 : b) + "%"
    }

    function deviceSubtitle(dev) {
        if (!dev) return ""
        if (dev.pairing) return "Pairing…"
        if (dev.state === BluetoothDeviceState.Connecting) return "Connecting…"
        if (dev.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
        if (dev.connected) {
            const bat = panel.batteryText(dev)
            return bat ? "Connected · " + bat : "Connected"
        }
        if (dev.paired || dev.bonded) return "Paired"
        return panel.isAnonymous(dev) ? "Unnamed device" : dev.address
    }

    // -------- Actions --------
    function toggleAdapter() {
        if (!panel.adapter || panel.adapterBusy) return
        if (panel.adapterBlocked) {
            panel.setStatus("Bluetooth is blocked by rfkill", true)
            return
        }
        panel.adapter.enabled = !panel.adapter.enabled
    }

    function activate(dev) {
        if (!dev) return

        if (dev.paired || dev.bonded) {
            if (dev.connected) dev.disconnect()
            else {
                panel.setStatus("Connecting to " + panel.deviceLabel(dev), false)
                dev.connect()
            }
            return
        }

        if (dev.pairing) {
            dev.cancelPair()
            panel.setStatus("Pairing cancelled", false)
            return
        }

        panel.pairingDevice = dev
        panel.setStatus("Pairing with " + panel.deviceLabel(dev), false)
        dev.pair()
    }

    // bluez pairs and connects as separate steps
    Connections {
        target: panel.pairingDevice
        ignoreUnknownSignals: true

        function onPairedChanged() {
            const dev = panel.pairingDevice
            if (!dev || !dev.paired) return
            panel.pairingDevice = null
            panel.toastRequested("Paired " + panel.deviceLabel(dev))
            if (!dev.connected) dev.connect()
        }

        function onPairingChanged() {
            const dev = panel.pairingDevice
            // Pairing stopped without the device becoming paired
            if (!dev || dev.pairing || dev.paired) return
            panel.pairingDevice = null
            panel.setStatus("Pairing failed — try Advanced settings", true)
        }
    }

    function askForget(dev) {
        if (!dev) return
        panel.forgetDevice = dev
    }

    function cancelForget() {
        panel.forgetDevice = null
    }

    function confirmForget() {
        const dev = panel.forgetDevice
        if (!dev) return

        panel.forgetLabel = panel.deviceLabel(dev)
        dev.forget()
        panel.cancelForget()
        panel.setStatus("Removed " + panel.forgetLabel, false)
        panel.toastRequested("Removed " + panel.forgetLabel)
    }

    function openAdvancedEditor() {
        Quickshell.execDetached(["blueman-manager"])
        panel.closeRequested()
    }

    // -------- Lifecycle --------
    // Discovery only runs while the panel is on screen and the radio is up.
    function setDiscovery(on) {
        if (!panel.adapter) return
        if (panel.adapter.discovering === on) return
        panel.adapter.discovering = on
    }

    function syncDiscovery() {
        panel.setDiscovery(panel.live && panel.adapterOn)
    }

    onLiveChanged: {
        panel.syncDiscovery()
        if (!panel.live) {
            panel.cancelForget()
            panel.pairingDevice = null
        }
    }
    onAdapterOnChanged: panel.syncDiscovery()
    onAdapterChanged: panel.syncDiscovery()

    // The loader builds this panel at the moment it is first shown
    Component.onCompleted: panel.syncDiscovery()
    Component.onDestruction: panel.setDiscovery(false)

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
        property bool disabled: false
        signal triggered()

        font.family:    panel.theme.textFont
        font.pixelSize: 12
        font.weight:    Font.Medium
        color:          linkHover.hovered && !link.disabled ? panel.theme.accent : panel.theme.textSecondary
        opacity:        link.disabled ? 0.45 : 1.0
        Behavior on color { ColorAnimation { duration: 160 } }

        HoverHandler { id: linkHover; enabled: !link.disabled }
        TapHandler { enabled: !link.disabled; onTapped: link.triggered() }
    }

    component PillButton: Rectangle {
        id: btn
        property string label: ""
        property bool primary: false
        property bool disabled: false
        property color tint: panel.theme.accent
        signal triggered()

        implicitHeight: 38
        radius: 12
        color: btn.primary
            ? (btnHover.hovered && !btn.disabled ? Qt.lighter(btn.tint, 1.12) : btn.tint)
            : (btnHover.hovered && !btn.disabled ? panel.theme.bgItemHover : panel.theme.bgItem)
        opacity: btn.disabled ? 0.5 : 1.0
        Behavior on color { ColorAnimation { duration: 200 } }

        scale: btnHover.hovered && !btn.disabled ? 1.017 : 1.0
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

        HoverHandler { id: btnHover; enabled: !btn.disabled; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: !btn.disabled; onTapped: btn.triggered() }

        Text {
            anchors.centerIn: parent
            text: btn.label
            font.family:    panel.theme.textFont
            font.pixelSize: 12
            font.weight:    Font.Medium
            color:          btn.primary ? panel.theme.textOnAccent : panel.theme.textPrimary
        }
    }

    // tappable device row
    component DeviceRow: Rectangle {
        id: row
        required property var dev

        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: 12
        color: rowHover.hovered ? panel.theme.bgItemHover : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }

        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: panel.activate(row.dev) }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: if (row.dev.paired || row.dev.bonded) panel.askForget(row.dev)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 11

            Text {
                text: panel.deviceIcon(row.dev)
                font.family:    panel.theme.iconFont
                font.pixelSize: 15
                color:          row.dev.connected ? panel.theme.accent : panel.theme.textSecondary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: panel.deviceLabel(row.dev)
                    font.family:    panel.theme.textFont
                    font.pixelSize: 13
                    font.weight:    Font.Medium
                    color:          panel.theme.textPrimary
                    elide:          Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: panel.deviceSubtitle(row.dev)
                    font.family:    panel.theme.textFont
                    font.pixelSize: 10
                    color:          panel.theme.textSecondary
                    elide:          Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Text {
                visible: row.dev.trusted && (row.dev.paired || row.dev.bonded)
                text: "󰓾"
                font.family:    panel.theme.iconFont
                font.pixelSize: 12
                color:          panel.theme.textSecondary
                opacity:        0.7
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
                    base + (ev.angleDelta.y > 0 ? -step : step),
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
                    text: "Bluetooth"
                    font.family:    panel.theme.textFont
                    font.pixelSize: 26
                    font.weight:    Font.DemiBold
                    color:          panel.theme.textPrimary
                }

                Item { Layout.fillWidth: true }

                // Adapter switch
                Rectangle {
                    width: 44; height: 24
                    radius: 12
                    color: panel.adapterOn ? panel.theme.accent : panel.theme.bgItem
                    border.width: 1
                    border.color: panel.adapterOn ? panel.theme.accent : panel.theme.outline
                    opacity: panel.adapterBusy ? 0.6 : 1.0
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        color: panel.adapterOn ? panel.theme.textOnAccent : panel.theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                        x: panel.adapterOn ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    HoverHandler { enabled: !panel.adapterBusy; cursorShape: Qt.PointingHandCursor }
                    TapHandler { enabled: !panel.adapterBusy; onTapped: panel.toggleAdapter() }
                }

                LinkText {
                    Layout.leftMargin: 12
                    text: "Back"
                    onTriggered: panel.closeRequested()
                }
            }

            // CONNECTED DEVICE
            Rectangle {
                id: connCard
                readonly property var dev: panel.connectedDevices.length > 0
                    ? panel.connectedDevices[0] : null

                Layout.fillWidth: true
                Layout.preferredHeight: 72
                radius: 12
                color: panel.theme.subtleFill
                border.width: 1
                border.color: connCard.dev ? panel.theme.accent : panel.theme.outline
                Behavior on border.color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 12

                    Text {
                        text: connCard.dev ? panel.deviceIcon(connCard.dev)
                                           : (panel.adapterOn ? "󰂯" : "󰂲")
                        font.family:    panel.theme.iconFont
                        font.pixelSize: 24
                        color:          connCard.dev ? panel.theme.accent : panel.theme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: connCard.dev
                                ? panel.deviceLabel(connCard.dev)
                                : (panel.adapterBlocked ? "Blocked"
                                   : panel.adapterOn ? "No device connected" : "Bluetooth off")
                            font.family:    panel.theme.textFont
                            font.pixelSize: 14
                            font.weight:    Font.DemiBold
                            color:          panel.theme.textPrimary
                            elide:          Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: {
                                if (connCard.dev) {
                                    const bat = panel.batteryText(connCard.dev)
                                    return bat ? "Connected · " + bat + " battery" : "Connected"
                                }
                                if (panel.adapterBlocked) return "Unblock with rfkill to use Bluetooth"
                                if (!panel.adapterOn) return "Turn Bluetooth on to see devices"
                                return panel.pairedDevices.length > 0
                                    ? "Pick a paired device below" : "Nothing paired yet"
                            }
                            font.family:    panel.theme.textFont
                            font.pixelSize: 11
                            color:          panel.theme.textSecondary
                            elide:          Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        visible: connCard.dev !== null
                        width: 34; height: 34
                        radius: 11
                        color: discHover.hovered
                            ? Qt.rgba(panel.theme.accentRed.r, panel.theme.accentRed.g, panel.theme.accentRed.b, 0.14)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅙"
                            font.family:    panel.theme.iconFont
                            font.pixelSize: 16
                            color:          panel.theme.accentRed
                        }

                        HoverHandler { id: discHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (connCard.dev) connCard.dev.disconnect() }
                    }
                }
            }

            // STATUS LINE
            Text {
                Layout.fillWidth: true
                visible: panel.statusLine.length > 0
                text: panel.statusLine
                font.family:    panel.theme.textFont
                font.pixelSize: 11
                color:          panel.statusBad ? panel.theme.accentRed : panel.theme.textSecondary
                elide:          Text.ElideRight
            }

            // OTHER CONNECTED DEVICES
            ColumnLayout {
                Layout.fillWidth: true
                visible: panel.connectedDevices.length > 1
                spacing: 4

                SectionLabel { text: "Also connected" }

                Repeater {
                    model: panel.connectedDevices.slice(1)
                    DeviceRow { required property var modelData; dev: modelData }
                }
            }

            // PAIRED
            ColumnLayout {
                Layout.fillWidth: true
                visible: panel.pairedDevices.length > 0
                spacing: 4

                SectionLabel { text: "Paired" }

                Repeater {
                    model: panel.pairedDevices
                    DeviceRow { required property var modelData; dev: modelData }
                }
            }

            // NEARBY
            ColumnLayout {
                Layout.fillWidth: true
                visible: panel.adapterOn
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    SectionLabel {
                        text: (panel.adapter && panel.adapter.discovering) ? "Scanning…" : "Nearby"
                    }
                    Item { Layout.fillWidth: true }
                    LinkText {
                        text: (panel.adapter && panel.adapter.discovering) ? "Stop" : "Scan"
                        onTriggered: panel.setDiscovery(!(panel.adapter && panel.adapter.discovering))
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    visible: panel.nearbyDevices.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: (panel.adapter && panel.adapter.discovering)
                        ? "Looking for devices…"
                        : "No new devices found"
                    font.family:    panel.theme.textFont
                    font.pixelSize: 12
                    color:          panel.theme.textSecondary
                }

                Repeater {
                    model: panel.nearbyDevices
                    DeviceRow { required property var modelData; dev: modelData }
                }
            }

            PillButton {
                Layout.fillWidth: true
                Layout.topMargin: 2
                label: "Advanced settings"
                onTriggered: panel.openAdvancedEditor()
            }
        }
    }

    // -------- Forget confirmation --------
    Item {
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: panel.forgetDevice ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(0, 0, 0, panel.theme.isDarkMode ? 0.55 : 0.35)
            TapHandler { onTapped: panel.cancelForget() }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 24, 320)
            height: promptCol.implicitHeight + 32
            radius: 14
            color: panel.theme.bgCard
            border.width: 1
            border.color: panel.theme.outline

            // Keeps a click on the card itself from reaching behind it
            TapHandler { }

            ColumnLayout {
                id: promptCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.margins: 16
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Remove this paired device?"
                    font.family:    panel.theme.textFont
                    font.pixelSize: 14
                    font.weight:    Font.DemiBold
                    color:          panel.theme.textPrimary
                    wrapMode:       Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    text: "“" + panel.deviceLabel(panel.forgetDevice)
                          + "” will be unpaired. You will need to pair it again to use it."
                    font.family:    panel.theme.textFont
                    font.pixelSize: 12
                    color:          panel.theme.textSecondary
                    wrapMode:       Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    PillButton {
                        Layout.fillWidth: true
                        label: "No"
                        onTriggered: panel.cancelForget()
                    }

                    PillButton {
                        Layout.fillWidth: true
                        primary: true
                        tint: panel.theme.accentRed
                        label: "Yes"
                        onTriggered: panel.confirmForget()
                    }
                }
            }
        }
    }
}
