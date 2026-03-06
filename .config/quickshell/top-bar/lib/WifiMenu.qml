import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrLayerKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "wifi-menu"

    // Hide hyprland borders
    function setBordersHidden(shouldHide) {
        Quickshell.execDetached(["hyprctl", "keyword", "general:border_size", shouldHide ? "0" : "1"])
    }

    onVisibleChanged: {
        setBordersHidden(visible)
            if (!visible) {
                viewStack.currentIndex = 0 // Go back to the main list
                targetSsid = ""
                enteredPass = ""
            }
            else {
                root.forceActiveFocus()
                refreshStatus()
            }
    }

    // restored when the app quits completely
    Component.onDestruction: {
        setBordersHidden(false)
    }
        
    focusable: true
    Shortcut { sequence: "Esc"; onActivated: Qt.quit() }
    

    // -------- Constants --------
    readonly property int statusRefreshInterval: 5000
    readonly property int processTimeout: 20000
    readonly property int scanDebounceDelay: 500

    // -------- Theme --------
    property string themeMode: "auto"
    property string themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"
    readonly property string envTheme: (Quickshell.env("QS_THEME") || "").trim().toLowerCase()

    property bool autoDark: true
    readonly property bool isDarkMode: {
        if (envTheme === "dark") return true
        if (envTheme === "light") return false
        if (themeMode === "dark") return true
        if (themeMode === "light") return false
        return autoDark
    }

    function applyAutoTheme(raw) {
        const m = String(raw || "").trim().toLowerCase()
        autoDark = (m !== "light")
    }

    FileView {
        path: root.themeModePath
        watchChanges: true
        preload: true
        onLoaded: {
            if (root.themeMode !== "auto") return
            if (root.envTheme === "dark" || root.envTheme === "light") return
            root.applyAutoTheme(text())
        }
        onTextChanged: {
            if (root.themeMode !== "auto") return
            if (root.envTheme === "dark" || root.envTheme === "light") return
            root.applyAutoTheme(text())
        }
        onFileChanged: reload()
        onLoadFailed: root.applyAutoTheme("dark")
    }

    // -------- Colors / Fonts --------
    readonly property color cBg:      isDarkMode ? "#6b3f443c" : "#97a382"
    readonly property color cBgAlt:   isDarkMode ? '#6b3f443c' : '#97a382'
    readonly property color cCard:    isDarkMode ? "#282c2d" : "#c1c3ae"
    readonly property color cFg:      isDarkMode ? "#D3C6AA" : "#1e2326"
    readonly property color cMuted:   isDarkMode ? "#859289" : '#4d6049'
    readonly property color cBorder:  isDarkMode ? '#d4708154' : '#d4586a3c'
    readonly property color cGreen:   isDarkMode ? "#A7C080" : "#576830"
    readonly property color cRed:     isDarkMode ? "#E67E80" : '#b13c3a'
    readonly property color cBlue:    isDarkMode ? '#A7C080' : '#5c7267'
    readonly property int   cRadius: 14

    readonly property string fontText: "Inter"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"

    // outside click closes
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: (mouse) => {
            const inside =
                mouse.x >= menuCard.x && mouse.x <= (menuCard.x + menuCard.width) &&
                mouse.y >= menuCard.y && mouse.y <= (menuCard.y + menuCard.height)
            if (!inside) Qt.quit()
        }
    }

    // -------- State --------
    property bool isExpanded: false
    property bool isBusy: false
    property bool scanRunning: false

    property bool wifiEnabled: true
    property string activeConnectionUuid: ""
    property string currentSsid: "Checking…"
    property int currentSignalVal: 0
    property string currentIp: ""

    property string statusLine: ""
    property color statusColor: cMuted

    property string targetSsid: ""
    property bool targetIsEnterprise: false
    property string enteredUser: ""
    property string enteredPass: ""

    property string pendingSavedUuid: ""
    property string pendingSavedSsid: ""

    Timer {
        id: statusTimer
        interval: 3200
        repeat: false
        onTriggered: statusLine = ""
    }

    Timer {
        id: processWatchdog
        interval: processTimeout
        repeat: false
        onTriggered: {
            // Watchdog fired - something took too long
            // Don't unlock UI since process might still be running
            // Just show error status
            if (isBusy || scanRunning) {
                setStatus("Operation timed out - please wait", true)
            }
        }
    }

    Timer {
        id: scanDebounce
        interval: scanDebounceDelay
        repeat: false
        onTriggered: performScan()
    }

    function setStatus(msg, bad) {
        statusLine = msg
        statusColor = bad ? cRed : cMuted
        statusTimer.restart()
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function getSignalIcon(strength) {
        if (strength > 80) return "󰤨"
        if (strength > 60) return "󰤥"
        if (strength > 40) return "󰤢"
        if (strength > 20) return "󰤟"
        return "󰤯"
    }

    function securityIsEnterprise(sec) {
        const s = String(sec || "")
        return s.includes("802.1X") || s.includes("Enterprise")
    }

    function securityLabel(sec, isEnt) {
        if (isEnt) return "Enterprise"
        const s = String(sec || "").trim()
        if (s === "" || s === "--") return "Open"
        return "Secured"
    }

    // Combined Status Process
    Process {
        id: procStatus
        command: ["bash", "-c", `
            # Get WiFi radio state
            WIFI_STATE=$(nmcli -g WIFI radio 2>/dev/null || echo "unknown")
            echo "WIFI:$WIFI_STATE"
            
            if [ "$WIFI_STATE" != "enabled" ]; then
                exit 0
            fi
            
            # Get active WiFi connection UUID and state
            ACTIVE=$(nmcli -g UUID,TYPE,STATE connection show --active 2>/dev/null | awk -F: '$2=="802-11-wireless" && $3=="activated"{print $1; exit}')
            
            if [ -z "$ACTIVE" ]; then
                # Check for activating connections
                ACTIVATING=$(nmcli -g UUID,TYPE,STATE connection show --active 2>/dev/null | awk -F: '$2=="802-11-wireless" && $3=="activating"{print $1; exit}')
                if [ -n "$ACTIVATING" ]; then
                    echo "UUID:$ACTIVATING"
                    echo "STATE:activating"
                    exit 0
                fi
                echo "STATE:disconnected"
                exit 0
            fi
            
            echo "UUID:$ACTIVE"
            echo "STATE:activated"
            
            # Get SSID from connection
            SSID=$(nmcli -g 802-11-wireless.ssid connection show uuid "$ACTIVE" 2>/dev/null | head -n1)
            echo "SSID:$SSID"
            
            # Get signal strength
            SIGNAL=$(nmcli -g IN-USE,SIGNAL dev wifi list 2>/dev/null | awk -F: '$1=="*"{print $2; exit}')
            echo "SIGNAL:$SIGNAL"
            
            # Get IP address
            IP=$(ip -o route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
            echo "IP:$IP"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text || "").split(/\r?\n/)
                let wifi = "", uuid = "", state = "", ssid = "", signal = "", ip = ""
                
                for (let line of lines) {
                    const parts = line.trim().split(":")
                    if (parts.length < 2) continue
                    const key = parts[0]
                    const val = parts.slice(1).join(":")
                    
                    if (key === "WIFI") wifi = val
                    else if (key === "UUID") uuid = val
                    else if (key === "STATE") state = val
                    else if (key === "SSID") ssid = val
                    else if (key === "SIGNAL") signal = val
                    else if (key === "IP") ip = val
                }
                
                wifiEnabled = (wifi === "enabled")
                
                if (!wifiEnabled) {
                    currentSsid = "WiFi Off"
                    currentIp = ""
                    currentSignalVal = 0
                    activeConnectionUuid = ""
                    return
                }
                
                activeConnectionUuid = uuid
                
                if (state === "activated") {
                    currentSsid = ssid || "Connected"
                    const sig = parseInt(signal, 10)
                    currentSignalVal = isFinite(sig) ? sig : 0
                    currentIp = ip
                } else if (state === "activating") {
                    currentSsid = "Connecting…"
                    currentIp = ""
                    currentSignalVal = 0
                } else {
                    currentSsid = "Disconnected"
                    currentIp = ""
                    currentSignalVal = 0
                }
            }
        }
    }

    function refreshStatus() {
        procStatus.running = true
    }

    // Saved networks
    ListModel { id: savedModel }
    property var savedBySsid: ({})
    property var savedByUuid: ({})

    function markSavedFlags() {
        const updates = []
        for (let i = 0; i < networkModel.count; i++) {
            const item = networkModel.get(i)
            const ss = item.ssid
            const wasSaved = item.isSaved
            const nowSaved = (savedBySsid[ss] !== undefined)
            
            if (wasSaved !== nowSaved) {
                updates.push({index: i, value: nowSaved})
            }
        }
        
        for (let u of updates) {
            networkModel.setProperty(u.index, "isSaved", u.value)
        }
    }

    Process {
    id: procSaved
    command: ["bash", "-c", `
        nmcli -t -f UUID,TYPE connection show 2>/dev/null \
        | awk -F: '$2=="802-11-wireless"{print $1}' \
        | while IFS= read -r uuid; do
            # nmcli -g prints ONE LINE PER FIELD, so read both lines
            mapfile -t vals < <(nmcli -g 802-11-wireless.ssid,connection.id connection show uuid "$uuid" 2>/dev/null)

            ssid="\${vals[0]}"
            name="\${vals[1]}"

            # fallbacks for weird/empty profiles
            [ -z "$name" ] && name="$ssid"
            [ -z "$ssid" ] && ssid="$name"
            [ -z "$ssid" ] && continue

            # Emit tab-separated: uuid<TAB>ssid<TAB>name
            printf '%s\\t%s\\t%s\\n' "$uuid" "$ssid" "$name"
        done
    `]
    stdout: StdioCollector {
        onStreamFinished: {
            savedModel.clear()
            savedBySsid = ({})
            savedByUuid = ({})

            const lines = String(text || "").split(/\r?\n/)
            for (let line of lines) {
                if (!line.trim()) continue
                const parts = line.split("\t")
                if (parts.length < 3) continue

                const uuid = parts[0].trim()
                const ssid = parts[1].trim()
                const name = parts[2].trim()

                if (!uuid || !ssid) continue

                if (savedBySsid[ssid] === undefined) {
                    savedModel.append({ ssid, name, uuid })
                    savedBySsid[ssid] = { uuid, name }
                }
                savedByUuid[uuid] = { ssid, name }
            }

            markSavedFlags()
        }
    }
}

    function refreshSaved() { 
        procSaved.running = true 
    }

    // Networks model
    ListModel { id: networkModel }
    property var ssidMap: ({})
    property var ssidBestSignal: ({})

    function upsertNetwork(ssid, bssid, sec, sig) {
        if (!ssid || ssid.length === 0) return
        if (!bssid || bssid.length === 0) return
        
        const ent = securityIsEnterprise(sec)
        const isSaved = (savedBySsid[ssid] !== undefined)

        // Track best signal for this SSID
        if (ssidBestSignal[ssid] === undefined || sig > ssidBestSignal[ssid]) {
            ssidBestSignal[ssid] = sig
        }

        // If SSID exists, update only if this has better signal
        if (ssidMap[ssid] !== undefined) {
            const idx = ssidMap[ssid]
            if (idx < networkModel.count) {
                const current = networkModel.get(idx)
                if (sig > current.strength) {
                    networkModel.setProperty(idx, "bssid", bssid)
                    networkModel.setProperty(idx, "security", sec || "")
                    networkModel.setProperty(idx, "strength", sig)
                    networkModel.setProperty(idx, "isEnterprise", ent)
                    networkModel.setProperty(idx, "isSaved", isSaved)
                }
            }
            return
        }

        // New SSID
        networkModel.append({
            ssid: ssid,
            bssid: bssid,
            security: sec || "",
            strength: sig,
            isEnterprise: ent,
            isSaved: isSaved
        })
        
        ssidMap[ssid] = networkModel.count - 1
    }

    function parseScanOutput(raw) {
        const lines = String(raw || "").split(/\r?\n/)
        for (let line of lines) {
            line = line.trim()
            if (!line) continue

            // Handle escaped colons in nmcli -g output
            // Replace \: with a placeholder
            const safeLine = line.replace(/\\:/g, "___COLON___")
            const parts = safeLine.split(":")
            if (parts.length < 4) continue

            const bssid = parts[0].replace(/___COLON___/g, ":")
            const ssid = parts[1].replace(/___COLON___/g, ":")
            const sec = parts[2].replace(/___COLON___/g, ":")
            const sigStr = parts[3]

            let sig = parseInt(sigStr, 10)
            if (!isFinite(sig)) sig = 0
            if (!ssid || ssid.length === 0) continue

            upsertNetwork(ssid, bssid, sec, sig)
        }
    }

    // Scanner
    Process {
        id: scanner
        command: ["bash", "-c", "nmcli -g BSSID,SSID,SECURITY,SIGNAL dev wifi list --rescan yes 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                scanRunning = false
                processWatchdog.stop()
                parseScanOutput(text || "")
                
                // Refresh saved networks after scan completes
                refreshSaved()

                if (networkModel.count === 0 && savedModel.count === 0) {
                    setStatus("No networks found", true)
                } else {
                    setStatus("Networks updated", false)
                }
            }
        }
        onExited: {
            if (exitCode !== 0 && scanRunning) {
                scanRunning = false
                processWatchdog.stop()
                setStatus("Scan failed", true)
            }
        }
    }

    function performScan() {
        if (!wifiEnabled) {
            setStatus("WiFi is off", true)
            return
        }
        
        scanRunning = true
        processWatchdog.restart()
        scanner.running = true
    }

    // Runner
    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                isBusy = false
                processWatchdog.stop()
                const out = String(text || "")
                const ok = out.includes("__EXIT:0")

                if (ok) {
                    setStatus("Connected", false)
                    errorBox.visible = false
                    viewStack.currentIndex = 0
                    statusRefreshDelay.restart()
                    return
                }

                if (out.includes("Secrets were required") || out.includes("No suitable secrets")) {
                    errorBox.visible = false
                    setStatus("Password required", true)
                    targetSsid = pendingSavedSsid
                    viewStack.currentIndex = 1
                    Qt.callLater(() => {
                        if (targetIsEnterprise) userField.forceActiveFocus()
                        else passField.forceActiveFocus()
                    })
                    return
                }

                const lines = out.trim().split(/\r?\n/)
                const tail = lines.slice(Math.max(0, lines.length - 10)).join("\n")
                errorBox.text = tail.length ? tail : "Connection failed. Check credentials and try again."
                errorBox.visible = true
                setStatus("Connection failed", true)
                refreshStatus()
                refreshSaved()
            }
        }
        onExited: {
            if (exitCode !== 0 && isBusy) {
                isBusy = false
                processWatchdog.stop()
                setStatus("Connection failed", true)
            }
        }
    }

    Timer {
        id: statusRefreshDelay
        interval: 1500
        repeat: false
        onTriggered: {
            refreshStatus()
            refreshSaved()
        }
    }

    function runWithExit(cmdString) {
        if (isBusy) return
        isBusy = true
        processWatchdog.restart()
        errorBox.visible = false
        setStatus("Working…", false)
        runner.command = ["bash", "-c", cmdString + " 2>&1; rc=$?; echo __EXIT:$rc"]
        runner.running = true
    }

    function connectSaved(uuid, ssid) {
        pendingSavedUuid = uuid
        pendingSavedSsid = ssid
        
        if (!uuid || uuid === "") {
            setStatus("Invalid connection", true)
            return
        }
        
        runWithExit("nmcli -w 15 connection up uuid " + shellQuote(uuid))
    }

    function setSavedPskAndConnect(uuid, password) {
        runWithExit(
            "nmcli connection modify uuid " + shellQuote(uuid) +
            " 802-11-wireless-security.key-mgmt wpa-psk " +
            " 802-11-wireless-security.psk " + shellQuote(password) + " && " +
            "nmcli -w 15 connection up uuid " + shellQuote(uuid)
        )
    }

    function connectNew(ssid, password, username, isEnterprise) {
        if (savedBySsid[ssid] !== undefined) {
            connectSaved(savedBySsid[ssid].uuid, ssid)
            return
        }

        let cmd = ""
        if (isEnterprise) {
            cmd =
                "nmcli -w 20 dev wifi connect " + shellQuote(ssid) +
                " password " + shellQuote(password) +
                " wifi-sec.key-mgmt wpa-eap " +
                " 802-1x.eap peap " +
                " 802-1x.phase2-auth mschapv2 " +
                " 802-1x.identity " + shellQuote(username)
        } else {
            cmd = "nmcli -w 20 dev wifi connect " + shellQuote(ssid)
            if (password && password.trim().length > 0)
                cmd += " password " + shellQuote(password)
        }

        pendingSavedUuid = ""
        pendingSavedSsid = ssid

        runWithExit(cmd)
    }

    function toggleWifi() {
        if (isBusy) return
        runWithExit("nmcli radio wifi " + (wifiEnabled ? "off" : "on"))
    }

    function disconnectNetwork() {
        if (isBusy) return
        if (!activeConnectionUuid || activeConnectionUuid === "") {
            setStatus("No active connection", true)
            return
        }
        runWithExit("nmcli connection down uuid " + shellQuote(activeConnectionUuid))
    }

    function startScanToggle() {
        if (isBusy) return

        if (!wifiEnabled) {
            setStatus("WiFi is off", true)
            return
        }

        if (!isExpanded) {
            isExpanded = true
            viewStack.currentIndex = 0
            networkModel.clear()
            ssidMap = ({})
            ssidBestSignal = ({})
            
            // Refresh saved networks when opening
            refreshSaved()
            scanDebounce.restart()
        } else {
            isExpanded = false
            scanRunning = false
            scanDebounce.stop()
        }
    }

    function rescanNow() {
        if (isBusy || !wifiEnabled) return
        networkModel.clear()
        ssidMap = ({})
        ssidBestSignal = ({})
        scanDebounce.restart()
    }

    function openAdvancedEditor() {
        Quickshell.execDetached(["nm-connection-editor"])
        Qt.quit()
    }

    // -------- UI --------
    // Shadows
    Rectangle {
        id: menuShadow
        anchors.fill: menuCard
        color: cCard
        radius: cRadius

        // The layer is applied HERE, so only the shadow is rasterized
        layer.enabled: true
        layer.effect: DropShadow {
            radius: 44
            samples: 64
            horizontalOffset: 0
            verticalOffset: 18
            color: Qt.rgba(0, 0, 0, root.isDarkMode ? 0.55 : 0.22)
        }
    }

    // Main Menu Card
    Rectangle {
        id: menuCard
        width: 390
        height: Math.ceil(mainLayout.implicitHeight + 24)

        //anchors.right: parent.right
        //anchors.top: parent.top
        //anchors.margins: 40

        x: 1042  // Distance from left edge of screen
        y: 44   // Distance from top edge of screen

        color: cCard
        radius: cRadius
        border.width: 1
        border.color: cBorder
        clip: true

        Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: mainLayout
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Internet"
                    font.family: fontText
                    font.pixelSize: 18
                    font.weight: 800
                    color: cFg
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 46; height: 24
                    radius: 12
                    color: wifiEnabled ? Qt.rgba(cGreen.r, cGreen.g, cGreen.b, 0.95) : cBgAlt
                    border.width: 1
                    border.color: wifiEnabled ? Qt.rgba(cGreen.r, cGreen.g, cGreen.b, 0.55) : cBorder
                    
                    opacity: isBusy ? 0.6 : 1.0

                    Rectangle {
                        width: 18; height: 18
                        radius: 9
                        color: cCard
                        anchors.verticalCenter: parent.verticalCenter
                        x: wifiEnabled ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: isBusy ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !isBusy
                        onClicked: toggleWifi()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 76
                radius: 14
                color: cBgAlt
                border.width: 0
                border.color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Rectangle {
                        width: 44; height: 44
                        radius: 14
                        color: "transparent"
                        Label {
                            anchors.centerIn: parent
                            text: wifiEnabled ? getSignalIcon(currentSignalVal) : "󰤮"
                            font.pixelSize: 22
                            font.family: fontIcon
                            color: wifiEnabled ? cGreen : cMuted
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: currentSsid
                            font.family: fontText
                            font.pixelSize: 14
                            font.weight: 800
                            color: cFg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: (currentIp && currentIp.length > 0) ? currentIp : (wifiEnabled ? "No IP address" : "WiFi disabled")
                            font.family: fontText
                            font.pixelSize: 12
                            color: cMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        visible: wifiEnabled && activeConnectionUuid !== ""
                        width: 36; height: 36
                        radius: 12
                        color: discMouse.containsMouse ? Qt.rgba(cRed.r, cRed.g, cRed.b, 0.12) : "transparent"
                        border.width: discMouse.containsMouse ? 1 : 0
                        border.color: Qt.rgba(cRed.r, cRed.g, cRed.b, 0.35)
                        opacity: isBusy ? 0.6 : 1.0

                        Label {
                            anchors.centerIn: parent
                            text: "󰅙"
                            font.family: fontIcon
                            color: cRed
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: discMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: isBusy ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !isBusy
                            onClicked: disconnectNetwork()
                        }
                    }
                }
            }

            MenuButton {
                //Layout.alignment: Qt.AlignHCenter 
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 100
                Layout.preferredHeight: 26       
                text: isExpanded ? "Close" : "Networks"
                icon: isExpanded ? "" : ""
                kind: "ghost"
                disabled: isBusy
                onClicked: startScanToggle()
            }

            Label {
                visible: statusLine.length > 0
                text: statusLine
                font.family: fontText
                font.pixelSize: 11
                color: statusColor
            }

            TextArea {
                id: errorBox
                visible: false
                readOnly: true
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight + 20, 120)
                font.family: fontText
                font.pixelSize: 11
                color: cRed
                background: Rectangle {
                    radius: 12
                    color: Qt.rgba(cRed.r, cRed.g, cRed.b, isDarkMode ? 0.08 : 0.12)
                    border.width: 1
                    border.color: Qt.rgba(cRed.r, cRed.g, cRed.b, 0.25)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: cBorder
                visible: isExpanded
                opacity: 0.7
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: isExpanded ? viewStack.children[viewStack.currentIndex].implicitHeight : 0
                visible: isExpanded
                opacity: isExpanded ? 1 : 0
                //clip: true
                Behavior on opacity { NumberAnimation { duration: 140 } }

                StackLayout {
                    id: viewStack
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    currentIndex: 0

                    // 0 = lists
                    ColumnLayout {
                        spacing: 10
                        
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 86
                            visible: !scanRunning && savedModel.count === 0 && networkModel.count === 0

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Label {
                                    text: "No networks found"
                                    font.family: fontText
                                    font.pixelSize: 13
                                    font.weight: 800
                                    color: cFg
                                }

                                Label {
                                    text: "Try rescan."
                                    font.family: fontText
                                    font.pixelSize: 11
                                    color: cMuted
                                }

                                MenuButton {
                                    height: 34
                                    text: "Rescan"
                                    icon: "󰑓"
                                    kind: "outline"
                                    disabled: scanRunning || isBusy
                                    onClicked: rescanNow()
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: savedModel.count > 0
                            Label {
                                text: "Saved"
                                font.family: fontText
                                font.pixelSize: 12
                                font.weight: 800
                                color: cMuted
                                Layout.fillWidth: true
                            }
                            BusyIndicator { 
                                running: scanRunning
                                visible: scanRunning
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    color: isDarkMode ? cGreen : cMuted
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(210, Math.max(0, savedModel.count * 48))
                            visible: savedModel.count > 0
                            clip: true
                            model: savedModel
                            spacing: 6
                            ScrollBar.vertical: ScrollBar { active: true; width: 4 }
                            delegate: savedDelegate
                        }

                        Label {
                            text: "Available"
                            font.family: fontText
                            font.pixelSize: 12
                            font.weight: 800
                            color: cMuted
                            visible: networkModel.count > 0
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(280, Math.max(0, networkModel.count * 48))
                            visible: networkModel.count > 0
                            clip: true
                            model: networkModel
                            spacing: 6
                            ScrollBar.vertical: ScrollBar { active: true; width: 4 }
                            delegate: networkDelegate
                        }

                        MenuButton {
                            Layout.fillWidth: true
                            height: 38
                            text: "Open Advanced Settings"
                            icon: "󰒓"
                            kind: "ghost"
                            disabled: isBusy
                            onClicked: openAdvancedEditor()
                        }
                    }

                    // 1 = password
                    ColumnLayout {
                        spacing: 12

                        Label {
                            text: targetIsEnterprise ? ("Log in to " + targetSsid) : ("Password for " + targetSsid)
                            color: cFg
                            font.family: fontText
                            font.pixelSize: 14
                            font.weight: 800
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        PillField {
                            id: userField
                            visible: targetIsEnterprise
                            Layout.fillWidth: true
                            placeholder: "Username"
                            text: enteredUser
                            enabled: !isBusy
                            onTextChanged: enteredUser = text
                            onAccepted: passField.forceActiveFocus()
                        }

                        PillField {
                            id: passField
                            Layout.fillWidth: true
                            placeholder: "Password"
                            echoMode: TextInput.Password
                            text: enteredPass
                            enabled: !isBusy
                            onTextChanged: enteredPass = text
                            onAccepted: {
                                if (pendingSavedUuid !== "") setSavedPskAndConnect(pendingSavedUuid, enteredPass)
                                else connectNew(targetSsid, enteredPass, enteredUser, targetIsEnterprise)
                            }
                        }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true

                            MenuButton {
                                Layout.fillWidth: true
                                height: 40
                                text: "Back"
                                icon: "󰁍"
                                kind: "outline"
                                disabled: isBusy
                                onClicked: viewStack.currentIndex = 0
                            }

                            MenuButton {
                                Layout.fillWidth: true
                                height: 40
                                text: isBusy ? "Connecting…" : "Connect"
                                btnColor: isDarkMode ? '#d483c092' : '#9e2a8650'
                                textColor: '#1e2326'
                                icon: "󱄙"
                                kind: "primary"
                                disabled: isBusy
                                onClicked: {
                                    if (pendingSavedUuid !== "") setSavedPskAndConnect(pendingSavedUuid, enteredPass)
                                    else connectNew(targetSsid, enteredPass, enteredUser, targetIsEnterprise)
                                }
                            }
                        }

                        MenuButton {
                            Layout.fillWidth: true
                            height: 38
                            text: "Open Advanced Settings"
                            icon: "󰒓"
                            kind: "ghost"
                            disabled: isBusy
                            onClicked: openAdvancedEditor()
                        }
                    }
                }
            }
        }
    }

    // -------- Delegates --------
    Component {
        id: savedDelegate
        Rectangle {
            required property string ssid
            required property string uuid
            required property string name
            
            width: ListView.view ? ListView.view.width : 0
            height: 35
            radius: 12
            color: sm.containsMouse ? Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.10) : "transparent"
            border.width: sm.containsMouse ? 1 : 0
            border.color: Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.25)
            opacity: isBusy ? 0.6 : 1.0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Label { text: "󰤨"; font.family: fontIcon; font.pixelSize: 14; color: cGreen }
                Label {
                    text: parent.parent.name || parent.parent.ssid || ""
                    font.family: fontText
                    font.pixelSize: 13
                    font.weight: 800
                    color: cFg
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Label { text: "Saved"; font.family: fontText; font.pixelSize: 10; color: cMuted }
            }

            MouseArea {
                id: sm
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: isBusy ? Qt.ArrowCursor : Qt.PointingHandCursor
                enabled: !isBusy
                onClicked: connectSaved(parent.uuid, parent.ssid)
            }
        }
    }

    Component {
        id: networkDelegate
        Rectangle {
            required property string ssid
            required property string bssid
            required property string security
            required property int strength
            required property bool isEnterprise
            required property bool isSaved
            
            width: ListView.view ? ListView.view.width : 0
            height: 54
            radius: 12
            color: nm.containsMouse ? Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.10) : "transparent"
            border.width: nm.containsMouse ? 1 : 0
            border.color: Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.25)
            opacity: isBusy ? 0.6 : 1.0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Label { 
                    text: getSignalIcon(parent.parent.strength)
                    font.family: fontIcon
                    font.pixelSize: 14
                    color: cGreen
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: parent.parent.parent.ssid || ""
                        font.family: fontText
                        font.pixelSize: 13
                        font.weight: 800
                        color: cFg
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Label {
                        text: parent.parent.parent.isSaved ? "Saved" : securityLabel(parent.parent.parent.security, parent.parent.parent.isEnterprise)
                        font.family: fontText
                        font.pixelSize: 10
                        color: cMuted
                    }
                }

                Label {
                    text: {
                        const sec = parent.parent.security || ""
                        return (parent.parent.isSaved || (sec.trim() !== "" && sec !== "--")) ? "󰌾" : "󰦝"
                    }
                    font.family: fontIcon
                    font.pixelSize: 12
                    color: cMuted
                }
            }

            MouseArea {
                id: nm
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: isBusy ? Qt.ArrowCursor : Qt.PointingHandCursor
                enabled: !isBusy
                onClicked: {
                    const item = parent
                    
                    if (item.isSaved) {
                        let uuid = savedBySsid[item.ssid] ? savedBySsid[item.ssid].uuid : ""
                        if (uuid) {
                            connectSaved(uuid, item.ssid)
                        }
                        return
                    }

                    const sec = String(item.security || "").trim()
                    const isOpen = (sec === "" || sec === "--")

                    if (isOpen) {
                        pendingSavedUuid = ""
                        pendingSavedSsid = item.ssid
                        connectNew(item.ssid, "", "", item.isEnterprise)
                        return
                    }

                    targetSsid = item.ssid
                    targetIsEnterprise = item.isEnterprise
                    enteredUser = ""
                    enteredPass = ""
                    pendingSavedUuid = ""
                    pendingSavedSsid = item.ssid

                    viewStack.currentIndex = 1
                    Qt.callLater(() => {
                        if (targetIsEnterprise) userField.forceActiveFocus()
                        else passField.forceActiveFocus()
                    })
                }
            }
        }
    }

    // -------- Components --------
    component MenuButton: Rectangle {
        id: btn
        property string text: ""
        property string icon: ""
        property string kind: "outline"
        property bool disabled: false
        
        property color btnColor: cGreen 
        property color textColor: (kind === "primary") ? cBg : cFg

        signal clicked()

        radius: 12
        implicitHeight: 40

        scale: pressed ? 0.95 : (hovered && !disabled ? 1.045 : 1.0)

        readonly property bool hovered: mouse.containsMouse
        readonly property bool pressed: mouse.pressed

        color: {
            if (kind === "primary") {
                if (disabled) return Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.35)
                return hovered ? Qt.darker(btnColor, 1.1) : btnColor
            }
            if (kind === "ghost") return hovered ? Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.10) : "transparent"
            return hovered ? Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.10) : "transparent"
        }

        border.width: (kind === "primary" || kind === "ghost") ? 0 : 1
        
        border.color: {
            if (kind === "primary") return "transparent" 
            return hovered ? Qt.rgba(cBlue.r, cBlue.g, cBlue.b, 0.35) : cBorder
        }

        opacity: disabled ? 0.55 : 1.0

        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            Label {
                visible: btn.icon.length > 0
                text: btn.icon
                font.family: fontIcon
                font.pixelSize: 16
                color: btn.textColor
            }

            Label {
                text: btn.text
                font.family: fontText
                font.pixelSize: 13
                font.weight: 800
                color: btn.textColor
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
            enabled: !btn.disabled
            onClicked: btn.clicked()
        }
    }

    component PillField: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder: ""
        property int echoMode: TextInput.Normal
        property bool enabled: true
        signal accepted()

        Layout.preferredHeight: 42
        radius: 999
        color: isDarkMode ? '#753c4841' : '#5e97a382'
        border.width: 1
        border.color: input.activeFocus ? Qt.rgba(cGreen.r, cGreen.g, cGreen.b, 0.7) : cBorder
        opacity: enabled ? 1.0 : 0.6
        clip: true

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14

            enabled: field.enabled
            color: cFg
            font.family: fontText
            font.pixelSize: 13
            echoMode: field.echoMode
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            activeFocusOnTab: true
            Keys.onReturnPressed: field.accepted()
            onActiveFocusChanged: {
                if (activeFocus) field.border.color = Qt.rgba(cGreen.r, cGreen.g, cGreen.b, 0.7)
                else field.border.color = cBorder
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: field.placeholder
            color: cMuted
            font.family: fontText
            font.pixelSize: 13
            visible: input.text.length === 0 && !input.activeFocus
        }

        MouseArea {
            anchors.fill: parent
            enabled: field.enabled
            cursorShape: Qt.IBeamCursor
            onClicked: input.forceActiveFocus()
        }
    }

    // Refresh status periodically, regardless of expansion state
    Timer {
        interval: statusRefreshInterval
        repeat: true
        running: root.visible
        triggeredOnStart: false
        onTriggered: {
            if (!isBusy && !scanRunning) {
                refreshStatus()
            }
        }
    }

    Component.onCompleted: {
        root.requestActivate()
        refreshStatus()
        Qt.callLater(() => {
            refreshSaved()
        })
    }
    
}