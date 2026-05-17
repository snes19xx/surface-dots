import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Hyprland

import "../lib" as Lib

PanelWindow {
    id: taskbar
    anchors { bottom: true; left: true; right: true }
    height: 50
    margins { bottom: -14 }
    color: "transparent"    
    WlrLayershell.exclusiveZone: 47


    // -----------------------------------------------
    // SIGNALS
    // -----------------------------------------------
        signal launcherClicked()
        signal requestHubToggle()
    
    // -----------------------------------------------
    // STATE MANAGEMENT
    // -----------------------------------------------
        property bool forceDockMode: false   // testing toggle   (switch to `true` if you always want it to be in dockmode for some reason)

        property bool isDockMode: forceDockMode
        //property bool isDockMode: truerue
        property bool hasWindows: false
        property int activeWsId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
        property bool isDarkMode: theme.isDarkMode
    

    // Instantiate the engine from ../lib/ThemeEngine.qml  
    Lib.ThemeEngine {
        id: theme
    }

    // -----------------------------------------------
    // COLOURS
    // -----------------------------------------------
    
    QtObject {
        id: palette
        property color bg: taskbar.isDarkMode ? '#c4242b23' : '#7e789867'
        property color workspaces: taskbar.isDarkMode ? '#0e92b79d' : '#e3ded6'
        property color textPrimary: taskbar.isDarkMode ? "#d5c9b2" : '#261e23'
        property color textSecondary: taskbar.isDarkMode ? "#6a6f75" : '#060506'
        property color textAlternate: taskbar.isDarkMode ? "#2b3033" : '#2b3033'
        property color accent: taskbar.isDarkMode ? "#789867" : "#273018"
        property color activePill: taskbar.isDarkMode ? "#789867" : "#87C080"
        property color hoverSpotlight: taskbar.isDarkMode ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.10)
        property color border: taskbar.isDarkMode ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.1)
        property color hoverPillG0: taskbar.isDarkMode ? Qt.rgba(167/255, 192/255, 128/255, 0.15) : Qt.rgba(39/255, 48/255, 24/255, 0.14)
        property color hoverPillG1: taskbar.isDarkMode ? Qt.rgba(230/255, 255/255, 200/255, 0.25) : Qt.rgba(39/255, 48/255, 24/255, 0.22)
        property color hoverPillG2: taskbar.isDarkMode ? Qt.rgba(167/255, 192/255, 128/255, 0.15) : Qt.rgba(39/255, 48/255, 24/255, 0.14)
    }

    // -----------------------------------------------
    // Shared Battery object across doc and workspace modes
    // -----------------------------------------------

    QtObject {
    id: batteryState
    
    property string status: String(batStatus.value).trim()
    property int rawCap: Number(batCap.value) || 0
    property int cap: (rawCap === 0 && status !== "Discharging") ? 50 : rawCap
    property bool plugged: (String(acOnline.value).trim() === "1")
    property bool isCharging: plugged || status === "Charging" || status === "Full"
    
    property string battColor: {
        const dark = taskbar.isDarkMode
        if (isCharging) return palette.accent
        const crit = dark ? '#ff0004' : '#ff001e'
        const low  = dark ? "#e69875" : '#a55524'
        const mid  = dark ? "#dbbc7f" : "#7a5b00"
        if (cap <= 10) return crit
        if (cap <= 20) return low
        if (cap <= 30) return mid
        return palette.textPrimary
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
}

    
     // -----------------------------------------------
    // HYPRLAND WINDOW CACHE
   // -----------------------------------------------
    QtObject {
        id: hyCache
        property var wsMap: ({})
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
            
            // Update hasWindows state
            taskbar.hasWindows = list.length > 0
            // xxx remove this xxx this xxx here xxx
            //taskbar.isDockMode = !taskbar.hasWindows
            if (!taskbar.forceDockMode)
    taskbar.isDockMode = !taskbar.hasWindows
        }

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

    Timer {
        interval: 500
        running: true; repeat: false
        onTriggered: hyCache.rebuild()
    }

    Timer {
        interval: 2000
        running: true; repeat: false
        onTriggered: hyCache.rebuild()
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev || !ev.name) return
            if (ev.name === "openwindow" || ev.name === "closewindow" ||
                ev.name === "movewindowv2" || ev.name === "urgent") {
                Hyprland.refreshToplevels()
                hyCache.scheduleRebuild()
            }
        }
    }
    
    // -----------------------------------------------
    // POLLERS
    // ----------------------------------------------- 
    
    // Updates
    Lib.CommandPoll {
        id: updates
        interval: updateProc.running ? 999999999 : 1800000
        command: sh(`
            if [ -e /var/lib/pacman/db.lck ]; then
                cat /tmp/qs_updates_count 2>/dev/null || echo 0
                exit 0
            fi
            n=$(checkupdates 2>/dev/null | wc -l)
            echo "$n" | tee /tmp/qs_updates_count
        `)
        parse: function(o) { return String(o ?? "").trim() }
    }

    Timer {
        interval: 15000
        running: true; repeat: false
        onTriggered: { if (!updateProc.running) updates.update() }
    }
    
    // Battery
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

    QtObject {
        id: batLogic
        property bool f20: false
        property bool f10: false

        function check(cap, status) {
            if (status !== "Discharging") {
                f20 = false; f10 = false; return
            }
            if (cap === 0) return
            if (cap <= 10 && !f10) {
                det("notify-send -u critical 'Battery Critically Low' 'Please Plug in your Charger'")
                f10 = true; f20 = true
            } else if (cap <= 20 && cap > 10 && !f20) {
                det("notify-send 'Battery Low' 'Please Plug in your Charger'")
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
    
    // ----------------------------------------------- 
    // UTILITIES
    // ----------------------------------------------- 
    function sh(cmd) { return ["bash", "-c", cmd] }
    function det(cmd) { Quickshell.execDetached(sh(cmd)) }
    
    // ICONS
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
    
    // ----------------------------------------------- 
    // MAIN CONTAINER
    // ----------------------------------------------- 
    Item {
        id: container
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        
        width: taskbar.isDockMode ? (parent.width - 20) : (parent.width - 20)
        height: 56
        
        Behavior on width {
            NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
        }
        
        // ----------------------------------------------- 
        // BACKGROUND PILL
        // ----------------------------------------------- 
        Item {
            id: pillWrapper
            height: 58
            width: parent.width
            clip: true
            
            Rectangle {
                id: pill
                anchors.fill: parent
                anchors.bottomMargin: -12
                radius: 9
                color: taskbar.isDarkMode ? '#00ff0000' : '#00949689'
            }
            
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                onPressed: mouse.accepted = false
            }

// ============================================================================================================================================================================================================================================================================================================================
            // ----------------------------------------------- 
            // DOCK MODE LAYOUT
            // ----------------------------------------------- 
            RowLayout {
                id: dockContent
                visible: taskbar.isDockMode
                opacity: taskbar.isDockMode ? 1.0 : 0.0
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 4
                spacing: -5
                
                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.OutQuart }
                }
                
                // Launcher
                Item {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    
                    DockButton {
                        anchors.centerIn: parent
                        iconPath: "../lib/arch.svg"
                        tooltipText: "Applications"
                        onClicked: taskbar.launcherClicked()
                    }
                }
                
                Rectangle { 
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 32
                    color: taskbar.isDarkMode ? "#25FFFFFF" : "#25000000"
                }
//--------------------------------------------------------------------------------------------------------------------------------------------
                
                // Pinned Apps  /* change this if you want different apps*/
                Row {
                    spacing: -10
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.topMargin:0
                    
                    DockAppIcon {
                        iconName: "firefox"
                        appName: "Firefox"
                        onClicked: det("firefox")
                    }
                    
                    DockAppIcon {
                        iconName: "vscode"
                        appName: "VS Code"
                        onClicked: det("code")
                    }
                    
                    DockAppIcon {
                        iconName: "spotify"
                        appName: "Spotify"
                        onClicked: det("spotify")
                    }
                    
                    DockAppIcon {
                        iconName: "kitty"
                        appName: "Terminal"
                        onClicked: det("kitty")
                    }
                }
//-------------------------------------------------------------------------------------------------------------------------------------------
                // uncomment if you want a separator between icons and clock
                /*
                // Separator 
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 32
                    color: taskbar.isDarkMode ? "#25FFFFFF" : "#25000000"
                }
                */
                
                // CLOCK SEGMENT (DOCK)
                Item {
                    id: clockContainer
                    Layout.preferredWidth: dockClockSegment.width
                    Layout.preferredHeight: 32
                    
                    // Visual feedback scaling
                    scale: dockClockSegment.containsMouse ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                    MouseArea {
                        id: dockClockSegment
                        width: dockTimeContent.width + 24 // + padding
                        height: parent.height
                        hoverEnabled: true
                        onClicked: taskbar.requestHubToggle()

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: parent.containsMouse
                                ? (taskbar.isDarkMode ? "#18FFFFFF" : "#18000000")
                                : "transparent"

                            Column {
                                id: dockTimeContent
                                anchors.centerIn: parent
                                spacing: 0

                                Text {
                                    id: dockTimeText
                                    text: Qt.formatDateTime(new Date(), "h:mm AP")
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: palette.textPrimary
                                }
                                
                                /* date
                                Text {
                                    id: dockDateText
                                    text: Qt.formatDateTime(new Date(), "yyyy, MMM d")
                                    font.pixelSize: 9
                                    opacity: 0.7
                                    color: palette.textSecondary
                                }

                                */
                            }

                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: {
                                    const now = new Date()
                                    dockTimeText.text = Qt.formatDateTime(now, "h:mm AP")
                                    //dockDateText.text = Qt.formatDateTime(now, "yyyy, MMM d")
                                }
                            }
                        }
                    }
                }   
            }

            // BATTERY (DOCK MODE) - anchored to right
            Item {
                visible: taskbar.isDockMode
                opacity: taskbar.isDockMode ? 1.0 : 0.0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 0
                anchors.verticalCenterOffset: 5
                width: dockBatteryArea.width
                height: 32
                
                
                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.OutQuart }
                }
                
                MouseArea {
                    id: dockBatteryArea
                    width: dockBatteryContent.width + 14
                    height: parent.height
                    hoverEnabled: true
                    onClicked: taskbar.requestHubToggle()
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: parent.containsMouse
                            ? (taskbar.isDarkMode ? "#18FFFFFF" : "#18000000")
                            : "transparent"
                        
                        Row {
                            id: dockBatteryContent
                            anchors.centerIn: parent
                            spacing: 4
                            
                            Text {
                                text: batteryState.dynamicIcon
                                font.family: theme.iconFont
                                font.pixelSize: 17
                                color: batteryState.battColor
                                //rotation: -90
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: batteryState.cap + "%"
                                font.family: theme.textFont
                                font.pixelSize: 11
                                font.bold: true
                                color: batteryState.battColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                        }
                        
                        SequentialAnimation {
                            running: batteryState.cap <= 10 && !batteryState.isCharging
                            loops: Animation.Infinite
                            NumberAnimation { target: dockBatteryArea.parent; property: "opacity"; to: 0.3; duration: 500 }
                            NumberAnimation { target: dockBatteryArea.parent; property: "opacity"; to: 1.0; duration: 500 }
                        }
                    }
                }
            }
                                                         // Dock mode ends here
// ============================================================================================================================================================================================================================================================================================================================
            // ---------------------------------------------- 
            // WORKSPACE MODE LAYOUT                        
            // --------------------------------------------

            RowLayout {
                id: workspaceContent
                visible: !taskbar.isDockMode
                opacity: !taskbar.isDockMode ? 1.0 : 0.0
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 0   
                anchors.rightMargin: 0    
                anchors.topMargin: 14 
                spacing: 10
                
                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.OutQuart }
                }
                
                // LEFT SIDE: Launcher + Workspaces
                RowLayout {
                    spacing: 8
                    
                    // Launcher
                    Item {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        
                        scale: launchPress.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                        
                        HoverHandler { id: hoverLaunch }
                        Rectangle {
                                    anchors.fill: parent
                                    radius: 9
                                    color: taskbar.isDarkMode ? palette.bg : "transparent"
                                }
                        
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
                            width:21; height: 21
                            property color color: {
                                if (hoverLaunch.hovered) return taskbar.isDarkMode ? "#89b4fa" : "#1e66f5"
                                return taskbar.isDarkMode ? "#89b4fa" : "#1e66f5"
                            }

                            Image { 
                                id: lImg
                                source: "../lib/arch.svg"
                                visible: false
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectFit
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
                            scale: launchPress.pressed ? 0.92 : (hoverLaunch.hovered ? 1.12 : 1.0)
                            y: launchPress.pressed ? 1 : (hoverLaunch.hovered ? -3 : 0)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on y {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }

                        }
                        
                        MouseArea {
                            id: launchPress
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton 
                            
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                     taskbar.launcherClicked()
                                } 
                                
                            }
                        }
                    }
                    
                    // Workspaces
                    Rectangle {
                        id: wsContainer
                        Layout.preferredHeight: 29
                        Layout.preferredWidth: wsRow.width + 22
                        Layout.alignment: Qt.AlignVCenter
                        radius: 9
                        color: palette.workspaces
                        clip: true
                        
                        property int hoveredId: 0
                        property var hoveredItem: (hoveredId > 0) ? wsRepeater.itemAt(hoveredId - 1) : null
                        property int pressedId: 0
                        property var pressedItem: (pressedId > 0) ? wsRepeater.itemAt(pressedId - 1) : null

                        Rectangle {
                            id: activePill
                            property int currentId: taskbar.activeWsId
                            property var targetItem: wsRepeater.itemAt(currentId - 1)
                            x: targetItem ? (wsRow.x + targetItem.x) : 0
                            width: targetItem ? targetItem.width : 0
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 9
                            color: palette.activePill
                            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        }

                        Item {
                            id: hoverPillLayer
                            anchors.fill: parent
                            visible: wsContainer.hoveredId > 0 && wsContainer.hoveredId !== taskbar.activeWsId
                            opacity: visible ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            
                            Rectangle {
                                property var t: wsContainer.hoveredItem
                                x: t ? (wsRow.x + t.x) : 0
                                width: t ? t.width : 0
                                height: 25
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 9
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
                                radius: 9
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
                                    property bool isActive: taskbar.activeWsId === wsId
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
                                        font.family: theme.iconFont
                                        font.pixelSize: 14
                                        lineHeight: 0.8
                                        verticalAlignment: Text.AlignVCenter
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                        color: isActive ? "#2d353b" : (wsHover.hovered ? (taskbar.isDarkMode ? "#f2f2f2" : palette.accent) : (taskbar.isDarkMode ? "#d5c9b2" : "#5c6a72"))
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 0
                                        visible: wsDelegate.hasWindows
                                        
                                        Repeater {
                                            model: wsDelegate.wsWindows
                                            
                                            Item {
                                                width: 22
                                                height: 22

                                                property string safeClass: {
                                                    const o = modelData?.lastIpcObject
                                                    var c = o?.class ?? ""
                                                    if (!c) c = o?.initialClass ?? ""
                                                    if (!c) c = o?.initialTitle ?? ""
                                                    if (!c) c = modelData?.title ?? ""
                                                    return String(c)
                                                }

                                                QtObject {
                                                    id: flashColor
                                                    property color val: taskbar.isDarkMode ? "#d5c9b2" : "#1e2326"
                                                    SequentialAnimation on val {
                                                        running: modelData.urgent
                                                        loops: Animation.Infinite
                                                        ColorAnimation { to: "#e67e80"; duration: 200 }
                                                        ColorAnimation { to: "#dbbc7f"; duration: 200 }
                                                    }
                                                }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: taskbar.getIcon(parent.safeClass)
                                                    font.family: theme.iconFont
                                                    font.pixelSize: 18
                                                    lineHeight: 0.8
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.hintingPreference: Font.PreferNoHinting
                                                    layer.enabled: true
                                                    layer.smooth: true
                                                    layer.mipmap: true
                                                    Behavior on color { enabled: !modelData.urgent; ColorAnimation { duration: 140 } }
                                                    scale: (wsDelegate.isActive && wsHover.hovered) ? 1.25 : 1.0
                                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                                                    color: wsDelegate.isActive ? '#2b3033' :
                                                           (modelData.urgent ? flashColor.val :
                                                           (wsHover.hovered ? (taskbar.isDarkMode ? "#f2f2f2" : palette.accent) :
                                                           (taskbar.isDarkMode ? "#d5c9b2" : "#1e2326")))
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
                }

                //FILLER
                Item { Layout.fillWidth: true }
                

                // RIGHT SIDE: App Name + Status
                RowLayout {
                    spacing: 10
                    
                    // App/Media Name 
                    Item {
                        Layout.preferredWidth: 300 // Constrain width so it doesn't push others off
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignRight
                        clip: true 
                        
                        property var player: Mpris.players.values[0] ?? null
                        property bool isPlaying: player && player.playbackState === MprisPlaybackState.Playing
                        property string trackTitle: player ? player.trackTitle : ""
                        property string trackArtist: player ? player.trackArtist : ""

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !parent.isPlaying
                            text: Hyprland.activeToplevel?.title ?? "Desktop"
                            font.family: theme.textFont
                            font.weight: 600
                            font.pixelSize: 12
                            color: palette.textPrimary
                            width: Math.min(implicitWidth, parent.width)
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft 
                        }

                        RowLayout {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: parent.isPlaying
                            spacing: 8
                            
                            Text { 
                                text: ""
                                font.family: theme.iconFont
                                font.pixelSize: 13
                                color: palette.accent
                            }
                            
                            Text {
                                text: parent.parent.trackTitle + " <font color='" + palette.textSecondary + "'>- " + parent.parent.trackArtist + "</font>"
                                textFormat: Text.StyledText
                                font.family: theme.textFont
                                font.weight: 600
                                font.pixelSize: 12
                                color: palette.textPrimary
                                Layout.maximumWidth: 280
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Updates
                    TaskbarItem {
                        property color updatesBg: taskbar.isDarkMode ? palette.accent : '#be7f9b58'
                        property color updatesFg: taskbar.isDarkMode ? "#2d353b" : "#1e2326"

                        visible: updateProc.running || (updates.value !== "0" && updates.value !== "")
                        iconSource: "../lib/pacman.svg"
                        text: updateProc.running ? "…" : updates.value
                        bgColor: updatesBg
                        textColor: updatesFg
                        iconColor: updatesFg

                        Process {
                            id: updateProc
                            command: ["kitty", "-e", "bash", "-lc", "sudo pacman -Syu"]
                            onRunningChanged: { if (!running) updates.update() }
                        }

                        onClicked: updateProc.running = true
                    }
                    
                    // System Tray
                    Rectangle {
                        visible: SystemTray.items.length > 0
                        height: 24
                        width: (SystemTray.items.length * 22) + 10
                        radius: 9
                        color: palette.bg
                        border.width: 1
                        border.color: palette.border
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Repeater {
                                model: SystemTray.items
                                
                                Item {
                                    width: 16
                                    height: 16
                                    scale: trayPress.pressed ? 0.94 : (trayPress.containsMouse ? 1.06 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: palette.hoverSpotlight
                                        opacity: trayPress.pressed ? 1.0 : (trayPress.containsMouse ? 0.8 : 0.0)
                                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    }

                                    Image {
                                        anchors.centerIn: parent
                                        width: 14
                                        height: 14
                                        source: modelData.icon
                                    }
                                    
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
                    
                    // Battery
                    TaskbarItem {
                    Layout.preferredWidth: 60
                    
                    icon: batteryState.dynamicIcon
                    text: batteryState.cap + "%"
                    bgColor: palette.bg
                    iconColor: batteryState.battColor
                    textColor: batteryState.battColor

                    SequentialAnimation {
                        running: batteryState.cap <= 10 && !batteryState.isCharging
                        loops: Animation.Infinite
                        NumberAnimation { target: parent; property: "opacity"; to: 0.3; duration: 500 }
                        NumberAnimation { target: parent; property: "opacity"; to: 1.0; duration: 500 }
                    }
                }
                    
                    // Clock
                    Item {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: clockRow.implicitWidth + 24
                        
                        // Effects
                        scale: clockArea.pressed ? 0.82 : (clockHover.hovered ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                        // Background
                        Rectangle {
                            id: clockBg
                            anchors.fill: parent
                            radius: 9
                            color: palette.bg
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: palette.hoverSpotlight
                                opacity: clockHover.hovered ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }

                        

                        // Content
                        RowLayout {
                            id: clockRow
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                id: dateText
                                text: Qt.formatDateTime(new Date(), "ddd, MMM d")
                                font.family: theme.textFont
                                font.pixelSize: 10
                                font.weight: 600
                                color: palette.accent
                            }
                            
                            Text {
                                text: "•"
                                font.pixelSize: 8
                                color: palette.textSecondary
                            }
                            
                            Text {
                                id: timeText
                                text: Qt.formatDateTime(new Date(), "h:mm AP")
                                font.family: theme.textFont
                                font.pixelSize: 11
                                font.weight: 800
                                color: palette.textPrimary
                            }
                            
                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: {
                                    var now = new Date()
                                    dateText.text = Qt.formatDateTime(now, "ddd, MMM d")
                                    timeText.text = Qt.formatDateTime(now, "h:mm AP")
                                }
                            }
                        }
                        
                        MouseArea {
                            id: clockArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onPressed: (mouse) => { taskbar.requestHubToggle(); mouse.accepted = true }
                        }
                        
                        HoverHandler {
                            id: clockHover
                        }
                    }
                }
            }
        }
    }
// ============================================================================================================================================================================================================================================================================================================================
    // --------------------------------------------
    // COMPONENTS
    // -------------------------------------------
    
    component DockButton: MouseArea {
        id: btn
        property string iconPath: ""
        property string tooltipText: ""
        
        width: 33
        height: 32
        hoverEnabled: true
        
        Rectangle {
            id: btnBg
            anchors.fill: parent
            radius: 8
            color: parent.containsMouse ? (taskbar.isDarkMode ? "#18FFFFFF" : "#18000000") : "transparent"
            
            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutQuart }
            }
            
            scale: parent.pressed ? 0.92 : (parent.containsMouse ? 1.08 : 1.0)
            
            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
            
            Image {
                id: launcherIcon
                anchors.centerIn: parent
                width: 24
                height: 24
                source: btn.iconPath
                sourceSize: Qt.size(128, 128)
                smooth: true
                antialiasing: true
                mipmap: true
                visible: taskbar.isDarkMode
            }
            

            ColorOverlay {
                anchors.fill: launcherIcon
                source: launcherIcon
                color: '#5b000000'
                visible: !taskbar.isDarkMode
            }
        }
        
        Rectangle {
            id: tooltip
            visible: parent.containsMouse && tooltipText !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 8
            
            width: tooltipLabel.implicitWidth + 16
            height: 24
            radius: 6
            color: taskbar.isDarkMode ? "#F01a1a1a" : "#F0f5f5f5"
            
            opacity: parent.containsMouse ? 1.0 : 0.0
            scale: parent.containsMouse ? 1.0 : 0.9
            
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
            }
            
            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
            
            transform: Translate {
                y: parent.containsMouse ? 0 : -4
                Behavior on y {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
                }
            }
            
            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                text: btn.tooltipText
                color: palette.textPrimary
                font.pixelSize: 9
                font.weight: Font.Medium
            }
        }
    }
    
    component DockAppIcon: Item {
    id: appIcon
    property string iconName: ""
    property string appName: ""
    property bool isActive: false
    
    width: 46
    height: 46
    
    HoverHandler { id: iconHover }
    scale: iconPress.pressed ? 0.85 : (iconHover.hovered ? 1.13 : 1.0)
    y: iconPress.pressed ? 2 : (iconHover.hovered ? -5 : 0)
    
    Behavior on scale {
        NumberAnimation { duration: 240; 
        easing.type: Easing.OutBack; 
        easing.overshoot: 1.4 }
    }
    
    Behavior on y {
        NumberAnimation { duration: 220; 
        easing.type: Easing.OutCubic }
    }
    
    Rectangle {
        id: iconBg
        width: 29  
        height: 29
        anchors.centerIn: parent
        radius: 6 
        color: iconHover.hovered ? (taskbar.isDarkMode ? "transparent" : "transparent") : "transparent"
        
        Behavior on color {
            ColorAnimation { duration: 180; 
            easing.type: Easing.OutQuart }
        }
        
        Image {
            id: appIconImg
            anchors.centerIn: parent
            width: 24
            height: 24
            source: "image://icon/" + appIcon.iconName
            sourceSize: Qt.size(128, 128)
            smooth: true
            antialiasing: true
            mipmap: true
            cache: true
            visible: taskbar.isDarkMode
        }

        ColorOverlay {
            anchors.fill: appIconImg
            source: appIconImg
            color: '#25000000'
            visible: !taskbar.isDarkMode
        }
        
    }
    
    MouseArea {
        id: iconPress
        anchors.fill: parent
        hoverEnabled: true
        onClicked: appIcon.clicked()
    }
    
    signal clicked()
    
    Rectangle {
        visible: iconHover.hovered && appName !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 12
        
        width: appNameLabel.implicitWidth + 16
        height: 24
        radius: 8
        color: taskbar.isDarkMode ? "#F01a1a1a" : "#F0f5f5f5"
        
        opacity: iconHover.hovered ? 1.0 : 0.0
        scale: iconHover.hovered ? 1.0 : 0.85
        
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuart }
        }
        
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        
        transform: Translate {
            y: iconHover.hovered ? 0 : -6
            Behavior on y {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuart }
            }
        }
        
        Text {
            id: appNameLabel
            anchors.centerIn: parent
            text: appIcon.appName
            color: palette.textPrimary
            font.pixelSize: 9
            font.weight: Font.Medium
        }
    }
}
    
    component TaskbarItem: Rectangle {
        id: root
        property string icon: ""
        property string text: ""
        property string iconSource: ""
        property color textColor: "#d5c9b2"
        property color iconColor: root.textColor
        property color bgColor: Qt.rgba(0.23, 0.25, 0.22, 0.25)
        
        signal clicked(var mouse)

        height: 28
        implicitWidth: layout.implicitWidth + 20
        radius: 9
        color: bgColor
        
        HoverHandler { id: hover }
        
        scale: press.pressed ? 0.94 : (hover.hovered ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 6
            
            Text {
                visible: root.icon !== ""
                text: root.icon
                font.family: theme.iconFont
                font.pixelSize: 12
                color: root.iconColor
            }
            
            Item {
                visible: root.iconSource !== ""
                Layout.alignment: Qt.AlignVCenter
                width: 14
                height: 14
                
                Image {
                    id: iSrc
                    anchors.fill: parent
                    source: root.iconSource
                    sourceSize: Qt.size(28, 28)
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: parent
                    source: iSrc
                    color: root.iconColor
                    cached: true
                    antialiasing: true
                }
            }
            
            Text {
                visible: root.text !== ""
                text: root.text
                font.family: theme.textFont
                font.pixelSize: 11
                font.weight: 700
                color: root.textColor
            }
        }
        
        MouseArea {
            id: press
            anchors.fill: parent
            hoverEnabled: true
            onClicked: (mouse) => root.clicked(mouse)
        }
    }
}