import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../lib" as Lib
import "../config.js" as Config
// Lib.Configuration singleton provides persistent settings

PanelWindow {
    id: win
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

        // Hides window borders when the hub is open 
        function setBordersHidden(hidden) {
            Quickshell.execDetached(["hyprctl", "keyword", "general:border_size", hidden ? "0" : "1"])
        }

        function closeAll() {
            if (header) header.expanded = false
            win.settingsPanelOpen = false
            win.wallpaperMode = false
            exitAnim.start()
        }

        onVisibleChanged: {
            setBordersHidden(visible)

            if (visible) {
                root.forceActiveFocus()

                // Instantly move panel off-screen before first render
                panelTranslate.y = panel.height
                panel.opacity  = 0
                panelScale.xScale = 0.97
                panelScale.yScale = 0.97
                layout.opacity = 0

                enterAnim.start()
            } else {
                win.batteryCardActive = false
                win.settingsPanelOpen = false
                win.wallpaperMode = false
                if (header) header.expanded = false
            }
        }
    
    property int barStrip: 2
    property bool isDarkMode: theme.isDarkMode

    Lib.ThemeEngine {
        id: theme
    }
    
// ---------------------------------------------------------------------------------------------------------------------------
    margins { top: barStrip }
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: visible
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "snes-hub"

    property string profileName: Config.PROFILE_NAME
    property string profileImage: Lib.Configuration.profileImageOverride !== ""
        ? Lib.Configuration.profileImageOverride
        : Config.PROFILE_IMG
    property bool batteryCardActive: false
    property bool settingsPanelOpen: false
    property bool wallpaperMode: false
    property bool _wpEverOpened: false
    // Drops the wallpaper panel's per-thumbnail blur/mask layers while the panel
    // animates in/out
    property bool _wpTransitioning: false
    Timer { id: wpTransTimer; interval: 300; onTriggered: win._wpTransitioning = false }
    onWallpaperModeChanged: {
        if (win.wallpaperMode) win._wpEverOpened = true
        win._wpTransitioning = true
        wpTransTimer.restart()
    }
    property bool _settingsEverOpened: false
    onSettingsPanelOpenChanged: if (win.settingsPanelOpen) win._settingsEverOpened = true
    property QtObject hubTheme: theme
    property int topGap: 21
    property int rightGap: 10
    property int panelW: win.wallpaperMode ? 540 : (win.settingsPanelOpen ? 620 : 520)
// ---------------------------------------------------------------------------------------------------------------------------
        function executeAction(action) {
            var cmd = ""
            switch(action) {
                case "shutdown":  cmd = "systemctl poweroff"; break;
                case "reboot":    cmd = "systemctl reboot"; break;
                case "hibernate": cmd = "systemctl hibernate"; break;
                case "suspend":   cmd = "mpc -q pause; amixer set Master mute; systemctl suspend"; break;
                case "logout":    cmd = "hyprctl dispatch 'hl.dsp.exit()'"; break;
                case "lock":
                    cmd = "if command -v hyprlock >/dev/null; then hyprlock; " +
                        "elif command -v betterlockscreen >/dev/null; then betterlockscreen -l; " +
                        "elif command -v i3lock >/dev/null; then i3lock; fi";
                    break;
            }

            if (cmd !== "") Quickshell.execDetached(["bash", "-lc", cmd])
            closeAll()
        }

        Item {
            id: root
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: closeAll()
            Keys.onPressed: (event) => {
                // Press 'P' to toggle the power menu
                if (event.key === Qt.Key_P) {
                    if (header) {
                        header.expanded = !header.expanded
                        event.accepted = true
                    }
                }
                // Press 'S' to toggle settings panel
                else if (event.key === Qt.Key_S) {
                    if (win.wallpaperMode) {
                        win.wallpaperMode = false
                    } else {
                        win.settingsPanelOpen = !win.settingsPanelOpen
                        if (win.settingsPanelOpen) header.expanded = false
                    }
                    event.accepted = true
                }
                // Press 'W' to toggle wallpaper panel
                else if (event.key === Qt.Key_W) {
                    win.wallpaperMode = !win.wallpaperMode
                    if (win.wallpaperMode) {
                        win.settingsPanelOpen = false
                        header.expanded = false
                    }
                    event.accepted = true
                }
                // Press 'B' to toggle battery/system stats card
                else if (event.key === Qt.Key_B) {
                    win.batteryCardActive = !win.batteryCardActive
                    event.accepted = true
                }
                // Press 'L' to switch to light theme
                else if (event.key === Qt.Key_L) {
                    if (theme.isDarkMode) theme.toggle()
                    event.accepted = true
                }
                // Press 'D' to switch to dark theme
                else if (event.key === Qt.Key_D) {
                    if (!theme.isDarkMode) theme.toggle()
                    event.accepted = true
                }
                // Press 'N' to expand/collapse notifications
                else if (event.key === Qt.Key_N) {
                    var isCollapsed = notifs.overrideCollapse || (notifs.compactMode && !notifs.expanded)
                    if (isCollapsed) {
                        notifs.overrideCollapse = false
                        notifs.expanded = true
                    } else if (notifs.notifCount > 1) {
                        notifs.overrideCollapse = true
                    }
                    event.accepted = true
                }
            }

        // click outside closes
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            preventStealing: true
            onPressed: closeAll()
        }

        Rectangle {
            id: panel
            width: win.panelW
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            readonly property int maxH: Math.round(panel.parent.height - 20)
            height: Math.min(Math.ceil(layout.implicitHeight + 24), maxH)
            radius: 12
            color: theme.bgMain
            layer.enabled: enterAnim.running || exitAnim.running

            // ANIMATION TRANSFORMS
            transform: [
                Scale {
                    id: panelScale
                    xScale: 1; yScale: 1
                    // Scale origin: bottom-centre -- panel grows up on enter, sinks on exit
                    origin.x: panel.width / 2
                    origin.y: panel.height
                },
                Translate { id: panelTranslate }
            ]

            // -- Enter: slide up + scale to full + panel fade, then content fades in--
            ParallelAnimation {
                id: enterAnim

                // Panel slides up from below
                NumberAnimation {
                    target: panelTranslate; property: "y"
                    from: panel.height; to: 0
                    duration: 320; easing.type: Easing.OutCubic
                }
                // Panel fades in
                NumberAnimation {
                    target: panel; property: "opacity"
                    from: 0; to: 1
                    duration: 280; easing.type: Easing.OutCubic
                }
                // Panel scales up from 0.97 --> 1.0
                NumberAnimation {
                    target: panelScale; property: "xScale"
                    from: 0.97; to: 1.0
                    duration: 320; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: panelScale; property: "yScale"
                    from: 0.97; to: 1.0
                    duration: 320; easing.type: Easing.OutCubic
                }
                // Content fades in after a short delay so it shows inside the panel
                SequentialAnimation {
                    PauseAnimation { duration: 70 }
                    NumberAnimation {
                        target: layout; property: "opacity"
                        from: 0; to: 1
                        duration: 230; easing.type: Easing.OutCubic
                    }
                }
            }

            // -- Exit: content disappears first, then panel sinks and fades --
            ParallelAnimation {
                id: exitAnim
                onFinished: win.visible = false

                // Content fades out quickly -- leaves a momentary empty shell
                NumberAnimation {
                    target: layout; property: "opacity"
                    from: 1; to: 0
                    duration: 140; easing.type: Easing.OutCubic
                }
                // Panel nudges down slightly
                NumberAnimation {
                    target: panelTranslate; property: "y"
                    from: 0; to: 20
                    duration: 260; easing.type: Easing.OutCubic
                }
                // Panel fades out
                NumberAnimation {
                    target: panel; property: "opacity"
                    from: 1; to: 0
                    duration: 250; easing.type: Easing.OutCubic
                }
                // Panel shrinks slightly as it disappears
                NumberAnimation {
                    target: panelScale; property: "xScale"
                    from: 1.0; to: 0.97
                    duration: 260; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: panelScale; property: "yScale"
                    from: 1.0; to: 0.97
                    duration: 260; easing.type: Easing.OutCubic
                }
            }

            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: win.rightGap
                bottomMargin: 10
            }

            // block clicks inside panel from closing
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                preventStealing: true
                onPressed: (mouse) => mouse.accepted = true
            }

            // -- CARDS ----------------------------------------------------------------------------------------------------

            ColumnLayout {
                id: layout
                anchors.fill: parent
                anchors.margins: 12
                spacing: theme.gapCard

            // HEADER (USER, SETTINGS, SS, POWER)
                Header {
                    id: header
                    theme: theme
                    Layout.fillWidth: true
                    profileName: win.profileName
                    profileImage: win.profileImage
                    active: win.visible
                    settingsOpen: win.settingsPanelOpen
                    batteryActive: win.batteryCardActive
                    onCloseRequested: closeAll()
                    onBatteryToggleRequested: win.batteryCardActive = !win.batteryCardActive
                    onPowerAction: function(act, lbl) {
                        header.expanded = false
                        executeAction(act)
                    }
                    onSettingsRequested: {
                        if (win.wallpaperMode) {
                            win.wallpaperMode = false
                        } else {
                            win.settingsPanelOpen = !win.settingsPanelOpen
                            if (win.settingsPanelOpen) header.expanded = false
                        }
                    }
                }

            // CONTENT AREA (cards / settings / wallpaper)
                Item {
                    id: contentArea
                    Layout.fillWidth: true
                    readonly property real maxContentH: Math.max(160, panel.maxH - header.height - layout.spacing - 24)
                    implicitHeight: win.wallpaperMode
                        ? (wallpaperLoader.height > 0 ? wallpaperLoader.height : cardsColumn.implicitHeight)
                        : win.settingsPanelOpen
                            ? (settingsLoader.height > 0 ? settingsLoader.height : cardsColumn.implicitHeight)
                            : cardsColumn.implicitHeight
                    Behavior on implicitHeight { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    // Regular cards
                    ColumnLayout {
                        id: cardsColumn
                        width: parent.width
                        spacing: theme.gapCard
                        opacity: (!win.settingsPanelOpen && !win.wallpaperMode) ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        // Stay rendered instead of visible:false
                        enabled: opacity > 0.01

            // MEDIA CARD
                MediaCard {
                    id: media
                    Layout.fillWidth: true
                    theme: theme
                    onCloseRequested: closeAll()
                    radius: 10
                }

            // CALENDAR | BUTTONS
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 250 
                    spacing: theme.gapCard

                    CalendarWeatherCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        
                        active: win.visible
                        theme: theme
                        onCloseRequested: closeAll()
                        radius: 10
                    }

                    ButtonsSlidersCard {
                        id: buttons
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        
                        active: win.visible
                        theme: theme
                        onCloseRequested: closeAll()
                        onBatteryToggleRequested: win.batteryCardActive = !win.batteryCardActive
                        radius: 10
                    }
                }

            // SYSTEM INFO CARD
                BatteryHealthCard {
                    id: battery
                    Layout.fillWidth: true
                    theme: theme
                    active: win.batteryCardActive
                    onActiveChanged: if (!active && !win.visible) win.batteryCardActive = false
                    radius: 10
                }
            
            // EVENTS FROM VDIR
                Events {
                    id: eventsCard
                    Layout.fillWidth: true
                    active: win.visible
                    theme: theme
                    onCloseRequested: closeAll()
                    radius: 10
                }

            // NOTIFICATIONS
                NotificationsCard {
                    id: notifs
                    Layout.fillWidth: true
                    active: win.visible
                    compactMode: media.visible || battery.visible || header.expanded
                    dndActive: buttons.dnd
                    theme: theme
                    radius: 10
                }
                    } // close cardsColumn

                    // SETTINGS LOADER
                    Loader {
                        id: settingsLoader
                        active: win._settingsEverOpened
                        width: parent.width
                        height: Math.min(item ? item.implicitHeight : 0, contentArea.maxContentH)
                        opacity: (win.settingsPanelOpen && !win.wallpaperMode) ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        visible: opacity > 0.01
                        sourceComponent: settingsPanelComponent
                    }

                    Component {
                        id: settingsPanelComponent
                        SettingsPanel {
                            theme: win.hubTheme
                            width: settingsLoader.width
                            height: settingsLoader.height
                            profileImagePath: win.profileImage
                        }
                    }

                    Connections {
                        target: settingsLoader.item
                        function onWallpaperRequested() {
                            win.wallpaperMode = true
                        }
                        function onToastRequested(msg) {
                            panel.triggerToast(msg)
                        }
                    }

                    // WALLPAPER LOADER — stays alive after first open so thumbnails stay cached
                    Loader {
                        id: wallpaperLoader
                        active: win._wpEverOpened
                        width: parent.width
                        opacity: win.wallpaperMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        sourceComponent: wallpaperPanelComponent
                    }

                    Component {
                        id: wallpaperPanelComponent
                        WallpaperPanel {
                            theme: win.hubTheme
                            width: wallpaperLoader.width
                            live: !win._wpTransitioning
                            onCloseRequested: win.wallpaperMode = false
                        }
                    }
                } // close content area Item
            } // close layout ColumnLayout

            // Panel-level toast
            property bool   _showToast: false
            property string _toastText: ""
            function triggerToast(msg) { _toastText = msg; _showToast = true; panelToastTimer.restart() }
            Timer { id: panelToastTimer; interval: 3500; onTriggered: panel._showToast = false }

            Rectangle {
                z: 99
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 10
                height: 26; radius: 7
                width: panelToastLabel.implicitWidth + 22
                color: Qt.rgba(theme.bgCard.r, theme.bgCard.g, theme.bgCard.b, 0.94)
                border.width: 1; border.color: theme.accent
                opacity: panel._showToast ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Text {
                    id: panelToastLabel
                    anchors.centerIn: parent
                    text: panel._toastText
                    color: theme.accent
                    font.family: "DM Mono"; font.pixelSize: 11
                }
            }
        } // close panel Rectangle
    } // close root Item
} // close PanelWindow
