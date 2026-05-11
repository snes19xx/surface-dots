import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Hyprland

import "../lib" as Lib

PanelWindow {
    id: win
    signal requestHubToggle()

    anchors { top: true; left: true; right: true }
    height: 40
    color: "transparent"

    // 1. GLOBAL STATE 
    // Theme mode: default is always dark, false will activate light mode
    property bool isDarkMode: true
    readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"
    FileView {
        id: themeModeFile
        path: win._themeModePath
        watchChanges: true
        preload: true
        // Update local property when file loads or changes
        onLoaded: {
            var m = String(text() || "").trim().toLowerCase()
            win.isDarkMode = (m !== "light")
        }
        onTextChanged: {
             var m = String(text() || "").trim().toLowerCase()
             win.isDarkMode = (m !== "light")
        }
        onFileChanged: reload()
    }
//--------------------------------------------------------------------------------
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: 38
    WlrLayershell.namespace: "shell-bar"
//--------------------------------------------------------------------------------
    function sh(cmd) { return ["bash", "-c", cmd] }
    function det(cmd) { Quickshell.execDetached(sh(cmd)) }

    // get active workspace ID 
    property int activeWsId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1

    // 2. THEME
    QtObject {
        id: palette
        property color bg: win.isDarkMode ? Qt.rgba(0.23, 0.25, 0.22, 0.25) : '#edc5c6b0'
        property color textPrimary: win.isDarkMode ? "#d5c9b2" : "#1e2326"
        property color textSecondary: win.isDarkMode ? "#6a6f75" : "#5c6a72"
        property color accent: win.isDarkMode ? "#a7c080" : "#273018"
        property color activePill: win.isDarkMode ? "#a7c080" : "#87C080"
        property color hoverSpotlight: win.isDarkMode ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.10)
        property color border: win.isDarkMode ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.1)

        property color hoverPillG0: win.isDarkMode ? Qt.rgba(167/255, 192/255, 128/255, 0.15) : Qt.rgba(39/255, 48/255, 24/255, 0.14)
        property color hoverPillG1: win.isDarkMode ? Qt.rgba(230/255, 255/255, 200/255, 0.25) : Qt.rgba(39/255, 48/255, 24/255, 0.22)
        property color hoverPillG2: win.isDarkMode ? Qt.rgba(167/255, 192/255, 128/255, 0.15) : Qt.rgba(39/255, 48/255, 24/255, 0.14)
    }

    // 2b. THEME ENGINE (font & sizing constants for the bar)
    Lib.ThemeEngine {
        id: barTheme
        isDarkMode: win.isDarkMode
    }

    // 3. HYPRLAND CACHE
    QtObject {
        id: hyCache
        property var wsMap: ({}) // wsId
        property bool pending: false

        function rebuild() {
            const m = {}
            const list = Hyprland.toplevels?.values ?? []
            for (const tl of list) {
                const id = tl?.workspace?.id
                if (!id) continue
                if (!m[id]) m[id] = []
                m[id].push(tl)
            }
            wsMap = m
        }

        // Collapses burst events into 1 rebuild per frame
        function scheduleRebuild() {
            if (pending) return
            pending = true
            Qt.callLater(() => {
                pending = false
                rebuild()
            })
        }

        Component.onCompleted: rebuild()
    }

    // 4. HYPR POLLERS
    Timer {
        interval: 500
        running: true; repeat: false
        onTriggered: hyCache.rebuild()
    }

    // Safety Check at 2s
    Timer {
        interval: 2000
        running: true; repeat: false
        onTriggered: hyCache.rebuild()
    }

    // 5. Event Listener + scheduleRebuild)
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev || !ev.name) return

            // Check for events
            if (ev.name === "openwindow" || ev.name === "closewindow" ||
                ev.name === "movewindowv2" || ev.name === "urgent") {

                // Re-fetch the window list from Hyprland immediately
                Hyprland.refreshToplevels()
                hyCache.scheduleRebuild()
            }
        }
    }

    // POLLERS
    // 6.1 UPDATE POLLER
    Lib.CommandPoll {
        id: updates
        // Stop polling while the update terminal is open
        interval: updateProc.running ? 999999999 : 1800000

        command: win.sh(`
            # Don't run checkupdates while pacman is locked
            if [ -e /var/lib/pacman/db.lck ]; then
                cat /tmp/qs_updates_count 2>/dev/null || echo 0
                exit 0
            fi

            n=$(checkupdates 2>/dev/null | wc -l)
            echo "$n" | tee /tmp/qs_updates_count
        `)

        parse: function(o) { return String(o ?? "").trim() }
    }

    // Boot Retry for Updates
    Timer {
        interval: 15000 // 15s wait for internet
        running: true; repeat: false
        onTriggered: {
            if (!updateProc.running) updates.update()
        }
    }
    // 6.2 BATTERY %, STATUS POLLER
    Lib.CommandPoll {
        id: powerPoll
        interval: {
            const s = String(batStatus.value ?? "").trim()
            const cap = Number(batCap.value ?? 0)
            if (s === "Discharging" && cap <= 20) return 2000
            return 6000
        }
        command: ["bash","-lc", `
            cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
            status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)
            ac=$(cat /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online 2>/dev/null | head -n1)
            echo "$cap|$status|$ac"
        `]
        parse: function(o) {
            var s = String(o ?? "").trim()
            var p = s.split("|")
            return { cap: Number(p[0]) || 0, status: (p[1] || "").trim(), ac: (p[2] || "").trim() }
        }
    }

    // 6.2.1 Battery Notifications
    QtObject {
        id: batLogic
        property bool f20: false
        property bool f10: false

        function check(cap, status) {
            if (status !== "Discharging") {
                f20 = false; f10 = false; return
            }
            if (cap === 0) return
            // Critical 10%
            if (cap <= 10 && !f10) {
                win.det("notify-send -u critical 'Battery Critically Low' 'Please Plug in your Charger'")
                f10 = true; f20 = true
            // Warning 20%
            } else if (cap <= 20 && cap > 10 && !f20) {
                win.det("notify-send 'Battery Low' 'Please Plug in your Charger'")
                f20 = true
            }
        }
    }
    QtObject {
        id: batCap
        property var value: (powerPoll.value ? powerPoll.value.cap : 0)
        onValueChanged: batLogic.check(value, batStatus.value)
    }
    QtObject {
        id: batStatus
        property var value: (powerPoll.value ? powerPoll.value.status : "")
        onValueChanged: batLogic.check(batCap.value, value)
    }
    QtObject { id: acOnline; property var value: (powerPoll.value ? powerPoll.value.ac : "") }

    // --- ICON MAP ---
    function getIcon(cls) {
        var c = (cls || "").toLowerCase()
        if (c.includes("firefox") || c.includes("zen") || c.includes("librewolf")) return "󰈹"
        if (c.includes("chromium") || c.includes("chrome") || c.includes("thorium")) return ""
        if (c.includes("brave")) return ""
        if (c.includes("qutebrowser")) return "󰖟"
        if (c.includes("kitty")) return "󰄛"
        if (c.includes("alacritty") || c.includes("foot") || c.includes("terminal") || c.includes("ghostty") || c.includes("wezterm")) return ""
        if (c.includes("code") || c.includes("codium")) return ""
        if (c.includes("sublime")) return "󰅳"
        if (c.includes("neovide") || c.includes("nvim")) return ""
        if (c.includes("idea") || c.includes("jetbrains")) return ""
        if (c.includes("pycharm")) return ""
        if (c.includes("webstorm")) return ""
        if (c.includes("clion")) return ""
        if (c.includes("android")) return "󰀴"
        if (c.includes("kate") || c.includes("texteditor")) return "󰈔"
        if (c.includes("nautilus") || c.includes("org.gnome.nautilus") || c.includes("files")) return ""
        if (c.includes("thunar") || c.includes("dolphin") || c.includes("nemo")) return ""
        if (c.includes("discord") || c.includes("vesktop")) return "󰙯"
        if (c.includes("slack")) return "󰒱"
        if (c.includes("telegram")) return ""
        if (c.includes("signal")) return "󰭹"
        if (c.includes("element")) return "󰘨"
        if (c.includes("whatsapp")) return "󰖣"
        if (c.includes("spotify")) return ""
        if (c.includes("vlc")) return "󰕼"
        if (c.includes("mpv") || c.includes("haruna") || c.includes("strawberry") || c.includes("rhythmbox") || c.includes("totem")) return ""
        if (c.includes("gimp")) return ""
        if (c.includes("inkscape")) return "󰕙"
        if (c.includes("krita")) return ""
        if (c.includes("blender")) return "󰂫"
        if (c.includes("audacity")) return "󰎈"
        if (c.includes("obs")) return ""
        if (c.includes("kdenlive")) return "󰕧"
        if (c.includes("steam")) return ""
        if (c.includes("lutris")) return "󰺵"
        if (c.includes("heroic")) return "󰊖"
        if (c.includes("prismlauncher")) return "󰍳"
        if (c.includes("libreoffice-writer")) return "󰈬"
        if (c.includes("calc")) return "󰧷"
        if (c.includes("impress")) return "󰈧"
        if (c.includes("libreoffice")) return "󰈙"
        if (c.includes("evince")) return "󰈦"
        if (c.includes("thunderbird")) return ""
        if (c.includes("settings") || c.includes("missioncenter")) return ""
        if (c.includes("look")) return ""
        if (c.includes("systemmonitor")) return "󰄨"
        if (c.includes("pavucontrol")) return "󰕾"
        if (c.includes("calculator")) return "󰃬"
        if (c.includes("weather")) return ""
        if (c.includes("evercal")) return "󰃭"
        if (c.includes("playing")) return "󰎄"
        if (c.includes("photos") || c.includes("org.gnome.loupe") || c.includes("imv") || c.includes("feh") || c.includes("eog") || c.includes("gthumb") || c.includes("qimgv") || c.includes("viewnior")) return ""
        if (c.includes ("swappy")) return "󰫕"
        if (c.includes ("amberol")) return "󱖏"
        if (c.includes ("xdm")) return ""
        if (c.includes ("zathura")) return ""
        if (c.includes ("focuswriter")) return "󱞁"
        if (c.includes ("lollypop")) return "󰎆"

        return ""
    }
// ------------------ THE BAR ---------------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: 10
// LEFT----------------------------------------------------------------------------------------------------------

            // 7. LAUNCHER
            Item {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                scale: launchPress.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                HoverHandler { id: hoverLaunch }
                
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(launchIcon.color.r, launchIcon.color.g, launchIcon.color.b, 1)
                    opacity: launchPress.pressed ? 0.10 : (hoverLaunch.hovered ? 0.08 : 0.0)
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Item {
                    id: launchIcon
                    anchors.centerIn: parent
                    width: 22; height: 22
                    property color color: {
                        if (hoverLaunch.hovered) return win.isDarkMode ? "#89b4fa" : "#1e66f5"
                        return win.isDarkMode ? "#89b4fa" : "#1e66f5"
                    }

                    Image { 
                        id: lImg
                        source: "../lib/arch.svg"
                        visible: false
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        // Rasterize at 2x (44px) relative to container (22px)
                        sourceSize: Qt.size(44, 44)
                        smooth: false
                    }
                    ColorOverlay {
                        anchors.fill: parent
                        source: lImg
                        color: parent.color
                        cached: true
                        antialiasing: true
                    }
                    rotation: hoverLaunch.hovered ? -14 : 0
                    scale: hoverLaunch.hovered ? 1.20 : 1.0
                    y: hoverLaunch.hovered ? -2 : 0
                    Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                    Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                MouseArea {
                    id: launchPress
                    anchors.fill: parent
                    hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) win.det("pkill -x rofi || " + (win.isDarkMode ? "~/.config/rofi/launcher.sh" : "~/.config/rofi/launcher_2.sh"))
                        else if (mouse.button === Qt.RightButton) {
                            win.isDarkMode = !win.isDarkMode
                            win.det("bash /home/snes/.config/quickshell/top-bar/bar/theme-mode.sh " + (win.isDarkMode ? "dark" : "light"))
                        }
                    }
                }
            }

            // 8. WORKSPACES
            Rectangle {
                id: wsContainer
                Layout.preferredHeight: 34
                Layout.preferredWidth: wsRow.width + 22
                Layout.alignment: Qt.AlignVCenter
                radius: 17
                color: palette.bg
                clip: true
                property int hoveredId: 0
                property var hoveredItem: (hoveredId > 0) ? wsRepeater.itemAt(hoveredId - 1) : null
                property int pressedId: 0
                property var pressedItem: (pressedId > 0) ? wsRepeater.itemAt(pressedId - 1) : null

                // ACTIVE PILL
                Rectangle {
                    id: activePill
                    property int currentId: win.activeWsId
                    property var targetItem: wsRepeater.itemAt(currentId - 1)
                    x: targetItem ? (wsRow.x + targetItem.x) : 0
                    width: targetItem ? targetItem.width : 0
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 13
                    color: palette.activePill
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                }

                // HOVER PILL
                Item {
                    id: hoverPillLayer
                    anchors.fill: parent
                    visible: wsContainer.hoveredId > 0 && wsContainer.hoveredId !== win.activeWsId
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Rectangle {
                        property var t: wsContainer.hoveredItem
                        x: t ? (wsRow.x + t.x) : 0; width: t ? t.width : 0; height: 25
                        anchors.verticalCenter: parent.verticalCenter; radius: 13
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: palette.hoverPillG0 }
                            GradientStop { position: 0.45; color: palette.hoverPillG1 }
                            GradientStop { position: 1.0; color: palette.hoverPillG2 }
                        }
                        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.10 } }
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                    }
                }

                Item {
                    id: pressPillLayer
                    anchors.fill: parent
                    visible: wsContainer.pressedId > 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                    Rectangle {
                        property var t: wsContainer.pressedItem
                        x: t ? (wsRow.x + t.x) : 0
                        width: t ? t.width : 0
                        height: 25
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 13
                        color: Qt.rgba(palette.textPrimary.r, palette.textPrimary.g, palette.textPrimary.b, 1)
                        opacity: 0.10
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                Row {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        id: wsRepeater
                        model: 10
                        Item {
                            id: wsDelegate
                            property int wsId: index + 1
                            property bool isActive: win.activeWsId === wsId

                            // --- READ FROM CACHE ---
                            property var wsWindows: hyCache.wsMap[wsId] ?? []
                            property int winCount: wsWindows.length
                            property bool hasWindows: winCount > 0
                            property bool isUrgent: wsWindows.some(tl => tl.urgent)

                            width: hasWindows ? (winCount * 22 + 12) : 26
                            height: 34

                            HoverHandler {
                                id: wsHover
                                onHoveredChanged: {
                                    if (hovered) wsContainer.hoveredId = wsId
                                    else if (wsContainer.hoveredId === wsId) wsContainer.hoveredId = 0
                                }
                            }

                            y: wsPress.pressed ? 1 : ((!isActive && wsHover.hovered) ? -2 : 0)
                            scale: (wsPress.pressed ? 0.96 : 1.0) * ((!isActive && wsHover.hovered) ? 1.10 : 1.0)
                            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                            Text {
                                anchors.centerIn: parent
                                visible: !wsDelegate.hasWindows
                                text: "•"
                                font.family: barTheme.iconFont; font.pixelSize: 14; lineHeight: 0.8
                                verticalAlignment: Text.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 140 } }
                                color: isActive ? "#2d353b" : (wsHover.hovered ? (win.isDarkMode ? "#f2f2f2" : palette.accent) : (win.isDarkMode ? "#d5c9b2" : "#5c6a72"))
                            }

                            Row {
                                anchors.centerIn: parent; spacing: 0
                                visible: wsDelegate.hasWindows
                                Repeater {
                                    model: wsDelegate.wsWindows
                                    Item {
                                        width: 22; height: 22

                                        // --- ipc ---
                                        property string safeClass: {
                                            const o = modelData?.lastIpcObject;
                                            var c = o?.class ?? "";
                                            if (!c) c = o?.initialClass ?? "";
                                            if (!c) c = o?.initialTitle ?? "";
                                            if (!c) c = modelData?.title ?? "";
                                            return String(c);
                                        }

                                        QtObject {
                                            id: flashColor
                                            property color val: win.isDarkMode ? "#d5c9b2" : "#1e2326"
                                            SequentialAnimation on val {
                                                running: modelData.urgent
                                                loops: Animation.Infinite
                                                ColorAnimation { to: "#e67e80"; duration: 200 }
                                                ColorAnimation { to: "#dbbc7f"; duration: 200 }
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: win.getIcon(parent.safeClass)
                                            font.family: barTheme.iconFont; font.pixelSize: 18; lineHeight: 0.8
                                            verticalAlignment: Text.AlignVCenter
                                            font.hintingPreference: Font.PreferNoHinting
                                            layer.enabled: true
                                            layer.smooth: true
                                            layer.mipmap: true
                                            Behavior on color { enabled: !modelData.urgent; ColorAnimation { duration: 140 } }
                                            scale: (wsDelegate.isActive && wsHover.hovered) ? 1.25 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                                            color: wsDelegate.isActive ? "#2d353b" :
                                                   (modelData.urgent ? flashColor.val :
                                                   (wsHover.hovered ? (win.isDarkMode ? "#f2f2f2" : palette.accent) :
                                                   (win.isDarkMode ? "#d5c9b2" : "#1e2326")))
                                        }

                                    }
                                }
                            }
                            MouseArea {
                                id: wsPress
                                anchors.fill: parent
                                hoverEnabled: true
                                onPressed: wsContainer.pressedId = wsId
                                onReleased: if (wsContainer.pressedId === wsId) wsContainer.pressedId = 0
                                onCanceled: if (wsContainer.pressedId === wsId) wsContainer.pressedId = 0
                                onClicked: det("hyprctl dispatch 'hl.dsp.focus({ workspace = " + wsId + " })'")
                            }
                        }
                    }
                }
            }
//------------------------------------------------- CENTER -----------------------------------------------------

            // 9. MEDIA & TITLE 
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                property var player: Mpris.players.values[0] ?? null
                property bool isPlaying: player && player.playbackState === MprisPlaybackState.Playing
                property string trackTitle: player ? player.trackTitle : ""
                property string trackArtist: player ? player.trackArtist : ""

                Text {
                    anchors.centerIn: parent
                    visible: !parent.isPlaying
                    text: Hyprland.activeToplevel?.title ?? "Desktop"
                    font.family: barTheme.iconFont; font.weight: 700; font.pixelSize: 13
                    color: palette.textPrimary
                    width: Math.min(implicitWidth, 500)
                    elide: Text.ElideRight
                }

                RowLayout {
                    anchors.centerIn: parent
                    visible: parent.isPlaying
                    spacing: 10
                    Text { text: ""; font.family: barTheme.iconFont; font.pixelSize: 14; color: palette.accent }
                    Text {
                        text: parent.parent.trackTitle + " <font color='" + palette.textSecondary + "'>- " + parent.parent.trackArtist + "</font>"
                        textFormat: Text.StyledText
                        font.family: barTheme.iconFont; font.weight: 700; font.pixelSize: 13
                        color: palette.textPrimary
                        Layout.maximumWidth: 350
                        elide: Text.ElideRight
                    }
                }
            }

//----------------------------------------------------------------------------------------RIGHT----------

            // 10. UPDATES
            BarItem {
                property color updatesBg: win.isDarkMode ? '#ce829469' : '#be7f9b58'
                property color updatesFg: win.isDarkMode ? "#2d353b" : "#1e2326"

                // Keep visible while update process is running
                visible: updateProc.running || (updates.value !== "0" && updates.value !== "")
                iconSource: "../lib/pacman.svg"
                text: updateProc.running ? "…" : updates.value
                bgColor: updatesBg; textColor: updatesFg; iconColor: updatesFg
                borderWidth: 0; borderColor: "transparent"; hoverColor: palette.hoverSpotlight

                Process {
                    id: updateProc
                    // The process stays 'running' as long as the window is open.
                    command: ["kitty", "-e", "bash", "-lc", "sudo pacman -Syu"]

                    // When running changes to false (window closed),
                    onRunningChanged: {
                        if (!running) {
                            updates.update()
                        }
                    }
                }

                onClicked: {
                    updateProc.running = true
                }
            }

            // 11. TRAY
            Rectangle {
                visible: SystemTray.items.length > 0
                height: 30
                width: (SystemTray.items.length * 28) + 12
                radius: 15
                color: palette.bg
                border.width: 1
                border.color: palette.border
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Repeater {
                        model: SystemTray.items
                        Item {
                            width: 20; height: 20
                            scale: trayPress.pressed ? 0.94 : (trayPress.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: palette.hoverSpotlight
                                opacity: trayPress.pressed ? 1.0 : (trayPress.containsMouse ? 0.8 : 0.0)
                                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            }

                            Image { anchors.centerIn: parent; width: 16; height: 16; source: modelData.icon }
                            MouseArea {
                                id: trayPress
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => modelData.activate(mouse.button)
                                onPressed: (mouse) => { if (mouse.button === Qt.RightButton) modelData.menu.open(this) }
                            }
                        }
                    }
                }
            }

            // 12. BATTERY
            BarItem {
                Layout.preferredWidth: 74
                property string status: String(batStatus.value).trim()
                property int rawCap: Number(batCap.value) || 0
                property int cap: (rawCap === 0 && status !== "Discharging") ? 50 : rawCap
                property bool plugged: (String(acOnline.value).trim() === "1")
                property bool isCharging: plugged || status === "Charging" || status === "Full"

                property string battColor: {
                    const dark = win.isDarkMode;
                    if (isCharging) return palette.accent;
                    const crit = dark ? '#ff0004' : '#ff001e';
                    const low  = dark ? "#e69875" : '#a55524';
                    const mid  = dark ? "#dbbc7f" : "#7a5b00";
                    if (cap <= 10) return crit;
                    if (cap <= 20) return low;
                    if (cap <= 30) return mid;
                    return palette.textPrimary;
                }
                property string dynamicIcon: {
                    if (isCharging) return "󰂄"
                    if (cap >= 98) return "󰁹"
                    if (cap >= 90) return "󰂂"; if (cap >= 80) return "󰂁"
                    if (cap >= 70) return "󰂀"; if (cap >= 60) return "󰁿"
                    if (cap >= 50) return "󰁾"; if (cap >= 40) return "󰁽"
                    if (cap >= 30) return "󰁼"; if (cap >= 20) return "󰁻"
                    return "󰁺"
                }

                icon: dynamicIcon; text: cap + "%"
                bgColor: palette.bg; iconColor: battColor; textColor: battColor
                borderWidth: 0; borderColor: "transparent"; hoverColor: palette.hoverSpotlight

                SequentialAnimation {
                    running: cap <= 10 && !isCharging
                    loops: Animation.Infinite
                    NumberAnimation { target: parent; property: "opacity"; to: 0.3; duration: 500 }
                    NumberAnimation { target: parent; property: "opacity"; to: 1.0; duration: 500 }
                }

                Rectangle {
                    id: powerSurge
                    anchors.centerIn: parent; width: parent.width; height: parent.height
                    radius: parent.height / 2; color: "transparent"
                    border.width: 0; border.color: "transparent"
                    opacity: 0; scale: 1.0
                }
                onPluggedChanged: if (plugged) surgeAnim.restart()
                ParallelAnimation {
                    id: surgeAnim
                    NumberAnimation { target: powerSurge; property: "scale"; from: 1.0; to: 1.45; duration: 520; easing.type: Easing.OutCubic }
                    NumberAnimation { target: powerSurge; property: "opacity"; from: 1.0; to: 0.0; duration: 520; easing.type: Easing.OutCubic }
                }
            }

            // 13. CLOCK/DATE
            Item {
                id: clockContainer
                Layout.preferredHeight: 34
                Layout.preferredWidth: clockRow.implicitWidth + 30
                
                scale: clockArea.pressed ? 0.98 : (clockArea.containsMouse ? 1.02 : 1.0)
                y: clockArea.pressed ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                // MASKED BACKGROUND LAYER 
                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: clockMask }

                    Rectangle {
                        anchors.fill: parent
                        color: palette.bg
                    }

                    // Shimmer 
                    Rectangle {
                        id: clockShimmer
                        width: 44; height: parent.height * 2; rotation: 20
                        x: -100; y: -parent.height/2
                        color: "transparent"
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: win.isDarkMode ? Qt.rgba(1,1,1,0.20) : Qt.rgba(0,0,0,0.1) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        color: win.isDarkMode ? "#ffffff" : "#000000"
                        opacity: clockArea.pressed ? 0.18 : (clockArea.containsMouse ? 0.12 : 0.0)
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                // Mask Source (Hidden)
                Rectangle {
                    id: clockMask
                    anchors.fill: parent
                    radius: 17
                    visible: false
                    antialiasing: true
                }

                // CONTENT (Unmasked)
                RowLayout {
                    id: clockRow
                    anchors.centerIn: parent; spacing: 8
                    Text { id: dateText; text: Qt.formatDateTime(new Date(), "ddd, MMM d"); font.family: barTheme.textFont; font.pixelSize: 12; font.weight: 600; color: palette.accent }
                    Text { text: "•"; font.pixelSize: 10; color: palette.textSecondary }
                    Text { id: timeText; text: Qt.formatDateTime(new Date(), "h:mm AP"); font.family: barTheme.textFont; font.pixelSize: 13; font.weight: 800; color: palette.textPrimary }
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: { var now = new Date(); dateText.text = Qt.formatDateTime(now, "ddd, MMM d"); timeText.text = Qt.formatDateTime(now, "h:mm AP") }
                    }
                }

                NumberAnimation { id: clockShimmerAnim; target: clockShimmer; property: "x"; from: -60; to: clockContainer.width + 60; duration: 800; easing.type: Easing.InOutQuad }
                
                MouseArea {
                    id: clockArea
                    anchors.fill: parent; hoverEnabled: true
                    onPressed: (mouse) => { win.requestHubToggle(); mouse.accepted = true }
                    onEntered: clockShimmerAnim.restart()
                }
            }
        }
    }
}