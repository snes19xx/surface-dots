import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../lib" as Lib

// Network panel for the hub
Item {
    id: panel

    required property var theme
    signal closeRequested()
    signal toastRequested(string msg)

    // Set by the hub while this panel is the visible content
    property bool live: false

    implicitHeight: content.implicitHeight

    // -------- Constants --------
    readonly property int statusRefreshInterval: 5000
    readonly property int processTimeout: 20000
    readonly property int scanDebounceDelay: 500

    // Last-known connection info is cached
    readonly property string statusCachePath: Quickshell.env("HOME") + "/.cache/quickshell/wifi_status.json"

    FileView {
        id: statusCache
        path: panel.statusCachePath
        preload: true
        onLoaded: panel.applyStatusCache(text())
    }

    // -------- State --------
    property bool isBusy: false
    property bool scanRunning: false

    property bool wifiEnabled: true
    property string activeConnectionUuid: ""
    property string currentSsid: "Checking…"
    property int currentSignalVal: 0
    property string currentIp: ""

    property string statusLine: ""
    property bool statusBad: false
    property string errorText: ""

    // True once a live nmcli status has landed, the cache never overrides fresh data
    property bool statusLoaded: false
    // Last json written to the cache
    property string lastStatusCacheJson: ""

    property string targetSsid: ""
    property bool targetIsEnterprise: false
    property string enteredUser: ""
    property string enteredPass: ""

    property string pendingSavedUuid: ""
    property string pendingSavedSsid: ""

    // "forget this network" confirmation
    property string forgetSsid: ""
    property string forgetUuid: ""
    property string forgetLabel: ""

    // 0 = network lists, 1 = credentials form
    property int view: 0

    Timer {
        id: statusTimer
        interval: 3200
        onTriggered: panel.statusLine = ""
    }

    // Something took too long. The process may still be running
    Timer {
        id: processWatchdog
        interval: panel.processTimeout
        onTriggered: if (panel.isBusy || panel.scanRunning) panel.setStatus("Operation timed out — please wait", true)
    }

    Timer {
        id: scanDebounce
        interval: panel.scanDebounceDelay
        onTriggered: panel.performScan()
    }

    function setStatus(msg, bad) {
        panel.statusLine = msg
        panel.statusBad = !!bad
        statusTimer.restart()
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function signalIcon(strength) {
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

    // -------- Status --------
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

                panel.statusLoaded = true
                panel.wifiEnabled = (wifi === "enabled")

                if (!panel.wifiEnabled) {
                    panel.currentSsid = "Wi-Fi off"
                    panel.currentIp = ""
                    panel.currentSignalVal = 0
                    panel.activeConnectionUuid = ""
                    panel.writeStatusCache()
                    return
                }

                panel.activeConnectionUuid = uuid

                if (state === "activated") {
                    panel.currentSsid = ssid || "Connected"
                    const sig = parseInt(signal, 10)
                    panel.currentSignalVal = isFinite(sig) ? sig : 0
                    panel.currentIp = ip
                } else if (state === "activating") {
                    panel.currentSsid = "Connecting…"
                    panel.currentIp = ""
                    panel.currentSignalVal = 0
                } else {
                    panel.currentSsid = "Disconnected"
                    panel.currentIp = ""
                    panel.currentSignalVal = 0
                }

                // Persist the resolved state; skip the transient connecting state
                if (state !== "activating") panel.writeStatusCache()
            }
        }
    }

    function refreshStatus() { procStatus.running = true }

    function applyStatusCache(raw) {
        // Never let a stale cache clobber a live nmcli result
        if (panel.statusLoaded) return

        let d
        try { d = JSON.parse(raw) } catch (e) { return }
        if (!d) return

        if (typeof d.wifiEnabled === "boolean") panel.wifiEnabled = d.wifiEnabled
        if (typeof d.ssid === "string" && d.ssid.length > 0) panel.currentSsid = d.ssid
        if (typeof d.signal === "number") panel.currentSignalVal = d.signal
        if (typeof d.ip === "string") panel.currentIp = d.ip
        if (typeof d.uuid === "string") panel.activeConnectionUuid = d.uuid
    }

    function writeStatusCache() {
        const d = {
            wifiEnabled: panel.wifiEnabled,
            ssid: panel.currentSsid,
            signal: panel.currentSignalVal,
            ip: panel.currentIp,
            uuid: panel.activeConnectionUuid
        }
        const json = JSON.stringify(d)

        // Only touch disk when something actually changed
        if (json === panel.lastStatusCacheJson) return
        panel.lastStatusCacheJson = json

        const dir = Quickshell.env("HOME") + "/.cache/quickshell"
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p " + panel.shellQuote(dir) +
            " && printf '%s' " + panel.shellQuote(json) + " > " + panel.shellQuote(panel.statusCachePath)])
    }

    // -------- Saved networks --------
    ListModel { id: savedModel }
    property var savedBySsid: ({})
    property var savedByUuid: ({})

    function markSavedFlags() {
        const updates = []
        for (let i = 0; i < networkModel.count; i++) {
            const item = networkModel.get(i)
            const wasSaved = item.isSaved
            const nowSaved = (panel.savedBySsid[item.ssid] !== undefined)
            if (wasSaved !== nowSaved) updates.push({ index: i, value: nowSaved })
        }
        for (let u of updates) networkModel.setProperty(u.index, "isSaved", u.value)
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
                panel.savedBySsid = ({})
                panel.savedByUuid = ({})

                const lines = String(text || "").split(/\r?\n/)
                for (let line of lines) {
                    if (!line.trim()) continue
                    const parts = line.split("\t")
                    if (parts.length < 3) continue

                    const uuid = parts[0].trim()
                    const ssid = parts[1].trim()
                    const name = parts[2].trim()
                    if (!uuid || !ssid) continue

                    if (panel.savedBySsid[ssid] === undefined) {
                        savedModel.append({ ssid, name, uuid })
                        panel.savedBySsid[ssid] = { uuid, name }
                    }
                    panel.savedByUuid[uuid] = { ssid, name }
                }

                panel.markSavedFlags()
            }
        }
    }

    function refreshSaved() { procSaved.running = true }

    // -------- Available networks --------
    ListModel { id: networkModel }
    property var ssidMap: ({})
    property var ssidBestSignal: ({})

    function upsertNetwork(ssid, bssid, sec, sig) {
        if (!ssid || ssid.length === 0) return
        if (!bssid || bssid.length === 0) return

        const ent = panel.securityIsEnterprise(sec)
        const isSaved = (panel.savedBySsid[ssid] !== undefined)

        // Track best signal for this SSID
        if (panel.ssidBestSignal[ssid] === undefined || sig > panel.ssidBestSignal[ssid])
            panel.ssidBestSignal[ssid] = sig

        // If the SSID is already listed, keep whichever BSSID has the better signal
        if (panel.ssidMap[ssid] !== undefined) {
            const idx = panel.ssidMap[ssid]
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

        networkModel.append({
            ssid: ssid,
            bssid: bssid,
            security: sec || "",
            strength: sig,
            isEnterprise: ent,
            isSaved: isSaved
        })
        panel.ssidMap[ssid] = networkModel.count - 1
    }

    function parseScanOutput(raw) {
        const lines = String(raw || "").split(/\r?\n/)
        for (let line of lines) {
            line = line.trim()
            if (!line) continue

            // nmcli -g escapes colons inside fields, so park them before splitting
            const safeLine = line.replace(/\\:/g, "___COLON___")
            const parts = safeLine.split(":")
            if (parts.length < 4) continue

            const bssid = parts[0].replace(/___COLON___/g, ":")
            const ssid = parts[1].replace(/___COLON___/g, ":")
            const sec = parts[2].replace(/___COLON___/g, ":")

            let sig = parseInt(parts[3], 10)
            if (!isFinite(sig)) sig = 0
            if (!ssid || ssid.length === 0) continue

            panel.upsertNetwork(ssid, bssid, sec, sig)
        }
    }

    Process {
        id: scanner
        command: ["bash", "-c", "nmcli -g BSSID,SSID,SECURITY,SIGNAL dev wifi list --rescan yes 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.scanRunning = false
                processWatchdog.stop()
                panel.parseScanOutput(text || "")

                // Saved profiles decide how each row behaves, so re-read them after the scan
                panel.refreshSaved()

                if (networkModel.count === 0 && savedModel.count === 0) panel.setStatus("No networks found", true)
                else panel.setStatus("Networks updated", false)
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && panel.scanRunning) {
                panel.scanRunning = false
                processWatchdog.stop()
                panel.setStatus("Scan failed", true)
            }
        }
    }

    function performScan() {
        if (!panel.wifiEnabled) {
            panel.setStatus("Wi-Fi is off", true)
            return
        }
        panel.scanRunning = true
        processWatchdog.restart()
        scanner.running = true
    }

    function rescanNow() {
        if (panel.isBusy || !panel.wifiEnabled) return
        networkModel.clear()
        panel.ssidMap = ({})
        panel.ssidBestSignal = ({})
        scanDebounce.restart()
    }

    // -------- Connect / disconnect --------
    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                panel.isBusy = false
                processWatchdog.stop()
                const out = String(text || "")

                if (out.includes("__EXIT:0")) {
                    panel.setStatus("Connected", false)
                    panel.errorText = ""
                    panel.view = 0
                    panel.toastRequested("Connected")
                    statusRefreshDelay.restart()
                    return
                }

                if (out.includes("Secrets were required") || out.includes("No suitable secrets")) {
                    panel.errorText = ""
                    panel.setStatus("Password required", true)
                    panel.targetSsid = panel.pendingSavedSsid
                    panel.view = 1
                    Qt.callLater(() => {
                        if (panel.targetIsEnterprise) userField.focusInput()
                        else passField.focusInput()
                    })
                    return
                }

                const lines = out.trim().split(/\r?\n/)
                const tail = lines.slice(Math.max(0, lines.length - 10)).join("\n")
                panel.errorText = tail.length ? tail : "Connection failed. Check credentials and try again."
                panel.setStatus("Connection failed", true)
                panel.refreshStatus()
                panel.refreshSaved()
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && panel.isBusy) {
                panel.isBusy = false
                processWatchdog.stop()
                panel.setStatus("Connection failed", true)
            }
        }
    }

    // nmcli returns before Hyprland state settles, so read back on a delay
    Timer {
        id: statusRefreshDelay
        interval: 1500
        onTriggered: {
            panel.refreshStatus()
            panel.refreshSaved()
        }
    }

    function runWithExit(cmdString) {
        if (panel.isBusy) return
        panel.isBusy = true
        processWatchdog.restart()
        panel.errorText = ""
        panel.setStatus("Working…", false)
        runner.command = ["bash", "-c", cmdString + " 2>&1; rc=$?; echo __EXIT:$rc"]
        runner.running = true
    }

    function connectSaved(uuid, ssid) {
        panel.pendingSavedUuid = uuid
        panel.pendingSavedSsid = ssid

        if (!uuid || uuid === "") {
            panel.setStatus("Invalid connection", true)
            return
        }
        panel.runWithExit("nmcli -w 15 connection up uuid " + panel.shellQuote(uuid))
    }

    function setSavedPskAndConnect(uuid, password) {
        panel.runWithExit(
            "nmcli connection modify uuid " + panel.shellQuote(uuid) +
            " 802-11-wireless-security.key-mgmt wpa-psk " +
            " 802-11-wireless-security.psk " + panel.shellQuote(password) + " && " +
            "nmcli -w 15 connection up uuid " + panel.shellQuote(uuid)
        )
    }

    function connectNew(ssid, password, username, isEnterprise) {
        // Saved psk profiles just get brought up; enterprise always gets rebuilt with fresh creds
        if (!isEnterprise && panel.savedBySsid[ssid] !== undefined) {
            panel.connectSaved(panel.savedBySsid[ssid].uuid, ssid)
            return
        }

        let cmd = ""
        if (isEnterprise) {
            // "dev wifi connect" cannot take 802-1x.* props, so build the profile explicitly
            // and put the secret in 802-1x.password (not the wpa-psk password field).
            // Drop any stale/half-made profile first so retries don't hit a name clash.
            cmd =
                "nmcli connection delete id " + panel.shellQuote(ssid) + " 2>/dev/null; " +
                "nmcli connection add type wifi con-name " + panel.shellQuote(ssid) +
                " ifname '*' ssid " + panel.shellQuote(ssid) +
                " wifi-sec.key-mgmt wpa-eap" +
                " 802-1x.eap peap" +
                " 802-1x.phase2-auth mschapv2" +
                " 802-1x.identity " + panel.shellQuote(username) +
                " 802-1x.password " + panel.shellQuote(password) +
                " && nmcli -w 25 connection up id " + panel.shellQuote(ssid)
        } else {
            cmd = "nmcli -w 20 dev wifi connect " + panel.shellQuote(ssid)
            if (password && password.trim().length > 0)
                cmd += " password " + panel.shellQuote(password)
        }

        panel.pendingSavedUuid = ""
        panel.pendingSavedSsid = ssid
        panel.runWithExit(cmd)
    }

    function submitCredentials() {
        // Enterprise needs the full 802-1x profile, never the psk-only path
        if (panel.pendingSavedUuid !== "" && !panel.targetIsEnterprise)
            panel.setSavedPskAndConnect(panel.pendingSavedUuid, panel.enteredPass)
        else
            panel.connectNew(panel.targetSsid, panel.enteredPass, panel.enteredUser, panel.targetIsEnterprise)
    }

    function askForCredentials(ssid, isEnterprise) {
        panel.targetSsid = ssid
        panel.targetIsEnterprise = isEnterprise
        panel.enteredUser = ""
        panel.enteredPass = ""
        panel.pendingSavedUuid = ""
        panel.pendingSavedSsid = ssid
        panel.view = 1
        Qt.callLater(() => {
            if (isEnterprise) userField.focusInput()
            else passField.focusInput()
        })
    }

    // -------- Forget a saved network --------
    Process {
        id: forgetter
        stdout: StdioCollector {
            onStreamFinished: {
                panel.isBusy = false
                processWatchdog.stop()

                if (String(text || "").includes("__EXIT:0")) {
                    panel.setStatus("Removed " + panel.forgetLabel, false)
                    panel.toastRequested("Removed " + panel.forgetLabel)
                    panel.refreshSaved()
                    panel.refreshStatus()
                    return
                }
                panel.setStatus("Could not remove " + panel.forgetLabel, true)
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && panel.isBusy) {
                panel.isBusy = false
                processWatchdog.stop()
                panel.setStatus("Could not remove " + panel.forgetLabel, true)
            }
        }
    }

    function askForget(uuid, ssid) {
        if (panel.isBusy || !uuid) return
        panel.forgetUuid = uuid
        panel.forgetSsid = ssid
    }

    function cancelForget() {
        panel.forgetUuid = ""
        panel.forgetSsid = ""
    }

    function confirmForget() {
        if (panel.isBusy || panel.forgetUuid === "") return

        panel.forgetLabel = panel.forgetSsid
        panel.isBusy = true
        processWatchdog.restart()
        panel.errorText = ""
        panel.setStatus("Removing…", false)
        forgetter.command = ["bash", "-c",
            "nmcli connection delete uuid " + panel.shellQuote(panel.forgetUuid) +
            " 2>&1; rc=$?; echo __EXIT:$rc"]
        forgetter.running = true
        panel.cancelForget()
    }

    // Right-clicking a row only offers to forget it if there is a profile to delete
    function savedUuidFor(ssid) {
        const entry = panel.savedBySsid[ssid]
        return (entry && entry.uuid) ? entry.uuid : ""
    }

    function toggleWifi() {
        if (panel.isBusy) return
        panel.runWithExit("nmcli radio wifi " + (panel.wifiEnabled ? "off" : "on"))
    }

    function disconnectNetwork() {
        if (panel.isBusy) return
        if (!panel.activeConnectionUuid || panel.activeConnectionUuid === "") {
            panel.setStatus("No active connection", true)
            return
        }
        panel.runWithExit("nmcli connection down uuid " + panel.shellQuote(panel.activeConnectionUuid))
    }

    function openAdvancedEditor() {
        Quickshell.execDetached(["nm-connection-editor"])
        panel.closeRequested()
    }

    // -------- Lifecycle --------
    // The panel stays loaded once opened, so polling follows live
    onLiveChanged: {
        if (panel.live) {
            panel.refreshStatus()
            panel.refreshSaved()
            panel.rescanNow()
        } else {
            panel.scanRunning = false
            scanDebounce.stop()
            panel.view = 0
            panel.targetSsid = ""
            panel.enteredUser = ""
            panel.enteredPass = ""
            panel.cancelForget()
        }
    }

    Timer {
        interval: panel.statusRefreshInterval
        repeat: true
        running: panel.live
        onTriggered: if (!panel.isBusy && !panel.scanRunning) panel.refreshStatus()
    }

    Component.onCompleted: {
        panel.refreshStatus()
        Qt.callLater(() => panel.refreshSaved())
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

    component PillField: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder: ""
        property int echoMode: TextInput.Normal
        property bool disabled: false
        signal accepted()

        function focusInput() { input.forceActiveFocus() }

        implicitHeight: 38
        radius: 12
        color: input.activeFocus
            ? Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.07)
            : (fieldHover.hovered ? panel.theme.bgItemHover : panel.theme.bgItem)
        Behavior on color { ColorAnimation { duration: 150 } }
        border.width: 1
        border.color: input.activeFocus ? panel.theme.accent : panel.theme.outline
        Behavior on border.color { ColorAnimation { duration: 150 } }
        opacity: field.disabled ? 0.55 : 1.0
        clip: true

        HoverHandler { id: fieldHover; cursorShape: Qt.IBeamCursor }
        TapHandler { onTapped: input.forceActiveFocus() }

        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            enabled: !field.disabled
            verticalAlignment: TextInput.AlignVCenter
            font.family:    panel.theme.textFont
            font.pixelSize: 13
            color:          panel.theme.textPrimary
            selectionColor: Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.35)
            echoMode:       field.echoMode
            selectByMouse:  true
            activeFocusOnTab: true
            Keys.onReturnPressed: field.accepted()
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: field.placeholder
            font.family:    panel.theme.textFont
            font.pixelSize: 13
            color:          panel.theme.textSecondary
            visible:        input.text.length === 0 && !input.activeFocus
        }
    }

    // Network row
    component NetworkRow: Rectangle {
        id: row
        property string title: ""
        property string subtitle: ""
        property string leadIcon: "󰤨"
        property string trailIcon: ""
        signal triggered()
        signal forgetRequested()

        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: 12
        color: rowHover.hovered && !panel.isBusy ? panel.theme.bgItemHover : "transparent"
        opacity: panel.isBusy ? 0.6 : 1.0
        Behavior on color { ColorAnimation { duration: 200 } }

        HoverHandler { id: rowHover; enabled: !panel.isBusy; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: !panel.isBusy; onTapped: row.triggered() }
        TapHandler {
            enabled: !panel.isBusy
            acceptedButtons: Qt.RightButton
            onTapped: row.forgetRequested()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 11

            Text {
                text: row.leadIcon
                font.family:    panel.theme.iconFont
                font.pixelSize: 15
                color:          panel.theme.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: row.title
                    font.family:    panel.theme.textFont
                    font.pixelSize: 13
                    font.weight:    Font.Medium
                    color:          panel.theme.textPrimary
                    elide:          Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: row.subtitle
                    font.family:    panel.theme.textFont
                    font.pixelSize: 10
                    color:          panel.theme.textSecondary
                    visible:        row.subtitle.length > 0
                }
            }

            Text {
                visible: row.trailIcon.length > 0
                text: row.trailIcon
                font.family:    panel.theme.iconFont
                font.pixelSize: 12
                color:          panel.theme.textSecondary
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
                    text: "Internet"
                    font.family:    panel.theme.textFont
                    font.pixelSize: 26
                    font.weight:    Font.DemiBold
                    color:          panel.theme.textPrimary
                }

                Item { Layout.fillWidth: true }

                // Radio switch
                Rectangle {
                    width: 44; height: 24
                    radius: 12
                    color: panel.wifiEnabled ? panel.theme.accent : panel.theme.bgItem
                    border.width: 1
                    border.color: panel.wifiEnabled ? panel.theme.accent : panel.theme.outline
                    opacity: panel.isBusy ? 0.6 : 1.0
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        color: panel.wifiEnabled ? panel.theme.textOnAccent : panel.theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                        x: panel.wifiEnabled ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    HoverHandler { enabled: !panel.isBusy; cursorShape: Qt.PointingHandCursor }
                    TapHandler { enabled: !panel.isBusy; onTapped: panel.toggleWifi() }
                }

                LinkText {
                    Layout.leftMargin: 12
                    text: "Back"
                    onTriggered: panel.closeRequested()
                }
            }

            // CURRENT CONNECTION
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                radius: 12
                color: panel.theme.subtleFill
                border.width: 1
                border.color: panel.wifiEnabled && panel.activeConnectionUuid !== ""
                    ? panel.theme.accent : panel.theme.outline
                Behavior on border.color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 12

                    Text {
                        text: panel.wifiEnabled ? panel.signalIcon(panel.currentSignalVal) : "󰤮"
                        font.family:    panel.theme.iconFont
                        font.pixelSize: 24
                        color:          panel.wifiEnabled ? panel.theme.accent : panel.theme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: panel.currentSsid
                            font.family:    panel.theme.textFont
                            font.pixelSize: 14
                            font.weight:    Font.DemiBold
                            color:          panel.theme.textPrimary
                            elide:          Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (panel.currentIp && panel.currentIp.length > 0)
                                ? panel.currentIp
                                : (panel.wifiEnabled ? "No IP address" : "Wi-Fi disabled")
                            font.family:    panel.theme.textFont
                            font.pixelSize: 11
                            color:          panel.theme.textSecondary
                            elide:          Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        visible: panel.wifiEnabled && panel.activeConnectionUuid !== ""
                        width: 34; height: 34
                        radius: 11
                        color: discHover.hovered
                            ? Qt.rgba(panel.theme.accentRed.r, panel.theme.accentRed.g, panel.theme.accentRed.b, 0.14)
                            : "transparent"
                        opacity: panel.isBusy ? 0.6 : 1.0
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅙"
                            font.family:    panel.theme.iconFont
                            font.pixelSize: 16
                            color:          panel.theme.accentRed
                        }

                        HoverHandler { id: discHover; enabled: !panel.isBusy; cursorShape: Qt.PointingHandCursor }
                        TapHandler { enabled: !panel.isBusy; onTapped: panel.disconnectNetwork() }
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

            // ERROR DETAIL
            Rectangle {
                Layout.fillWidth: true
                visible: panel.errorText.length > 0
                implicitHeight: errText.implicitHeight + 18
                radius: 12
                color: Qt.rgba(panel.theme.accentRed.r, panel.theme.accentRed.g, panel.theme.accentRed.b, 0.10)
                border.width: 1
                border.color: Qt.rgba(panel.theme.accentRed.r, panel.theme.accentRed.g, panel.theme.accentRed.b, 0.25)

                Text {
                    id: errText
                    anchors { fill: parent; margins: 9 }
                    text: panel.errorText
                    wrapMode: Text.Wrap
                    font.family:    panel.theme.textFont
                    font.pixelSize: 11
                    color:          panel.theme.accentRed
                }
            }

            // ------- VIEW 0: NETWORK LISTS -------
            ColumnLayout {
                Layout.fillWidth: true
                visible: panel.view === 0
                spacing: 14

                // SAVED
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: savedModel.count > 0
                    spacing: 4

                    SectionLabel { text: "Saved" }

                    Repeater {
                        model: savedModel

                        NetworkRow {
                            required property string ssid
                            required property string uuid
                            required property string name

                            title: name || ssid
                            subtitle: "Saved"
                            onTriggered: panel.connectSaved(uuid, ssid)
                            onForgetRequested: panel.askForget(uuid, ssid)
                        }
                    }
                }

                // AVAILABLE
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        SectionLabel { text: panel.scanRunning ? "Scanning…" : "Available" }
                        Item { Layout.fillWidth: true }
                        LinkText {
                            text: "Rescan"
                            disabled: panel.scanRunning || panel.isBusy || !panel.wifiEnabled
                            onTriggered: panel.rescanNow()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        visible: !panel.scanRunning && networkModel.count === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: panel.wifiEnabled ? "No networks in range" : "Turn Wi-Fi on to scan"
                        font.family:    panel.theme.textFont
                        font.pixelSize: 12
                        color:          panel.theme.textSecondary
                    }

                    Repeater {
                        model: networkModel

                        NetworkRow {
                            required property string ssid
                            required property string security
                            required property int strength
                            required property bool isEnterprise
                            required property bool isSaved

                            title: ssid
                            subtitle: isSaved ? "Saved" : panel.securityLabel(security, isEnterprise)
                            leadIcon: panel.signalIcon(strength)
                            trailIcon: {
                                const sec = String(security || "").trim()
                                return (isSaved || (sec !== "" && sec !== "--")) ? "󰌾" : "󰦝"
                            }
                            onTriggered: {
                                if (isSaved) {
                                    const entry = panel.savedBySsid[ssid]
                                    if (entry && entry.uuid) panel.connectSaved(entry.uuid, ssid)
                                    return
                                }

                                const sec = String(security || "").trim()
                                if (sec === "" || sec === "--") {
                                    panel.pendingSavedUuid = ""
                                    panel.pendingSavedSsid = ssid
                                    panel.connectNew(ssid, "", "", isEnterprise)
                                    return
                                }

                                panel.askForCredentials(ssid, isEnterprise)
                            }
                            onForgetRequested: {
                                if (isSaved) panel.askForget(panel.savedUuidFor(ssid), ssid)
                            }
                        }
                    }
                }

                PillButton {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    label: "Advanced settings"
                    disabled: panel.isBusy
                    onTriggered: panel.openAdvancedEditor()
                }
            }

            // ------- VIEW 1: CREDENTIALS -------
            ColumnLayout {
                Layout.fillWidth: true
                visible: panel.view === 1
                spacing: 10

                SectionLabel {
                    text: panel.targetIsEnterprise ? "Log in to " + panel.targetSsid
                                                   : "Password for " + panel.targetSsid
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                PillField {
                    id: userField
                    Layout.fillWidth: true
                    visible: panel.targetIsEnterprise
                    placeholder: "Username"
                    text: panel.enteredUser
                    disabled: panel.isBusy
                    onTextChanged: panel.enteredUser = text
                    onAccepted: passField.focusInput()
                }

                PillField {
                    id: passField
                    Layout.fillWidth: true
                    placeholder: "Password"
                    echoMode: TextInput.Password
                    text: panel.enteredPass
                    disabled: panel.isBusy
                    onTextChanged: panel.enteredPass = text
                    onAccepted: panel.submitCredentials()
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    PillButton {
                        Layout.fillWidth: true
                        label: "Back"
                        disabled: panel.isBusy
                        onTriggered: panel.view = 0
                    }

                    PillButton {
                        Layout.fillWidth: true
                        primary: true
                        label: panel.isBusy ? "Connecting…" : "Connect"
                        disabled: panel.isBusy
                        onTriggered: panel.submitCredentials()
                    }
                }
            }
        }
    }

    // -------- Forget confirmation --------
    Item {
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: panel.forgetSsid !== "" ? 1 : 0
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

            // keep click on the card itself
            TapHandler { }

            ColumnLayout {
                id: promptCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.margins: 16
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Remove this saved network?"
                    font.family:    panel.theme.textFont
                    font.pixelSize: 14
                    font.weight:    Font.DemiBold
                    color:          panel.theme.textPrimary
                    wrapMode:       Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    text: "“" + panel.forgetSsid + "” will be forgotten. You will need its password to connect again."
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
