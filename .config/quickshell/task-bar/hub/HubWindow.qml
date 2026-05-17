import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../lib" as Lib
import "../config.js" as Config

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
            //win.visible = false
            exitAnim.start()
        }

        onVisibleChanged: {
            setBordersHidden(visible)

            if (visible) {
                root.forceActiveFocus()
                
                // Instantly move panel off-screen before first render
                panelTranslate.y = panel.height
                panel.opacity = 0
                
                // Start sliding UP
                enterAnim.start()
            } else {
                // Cleanup after window is hidden
                win.batteryCardActive = false
                if (header) header.expanded = false
            }
        }
    
    property int barStrip: 2
    property bool isDarkMode: theme.isDarkMode
    readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"

        function _applyThemeMode(raw) {
            var m = String(raw || "").trim().toLowerCase()
            win.isDarkMode = (m !== "light")
        }

    // Watcher for theme toggle
    FileView {
        id: themeModeFile
        path: win._themeModePath
        watchChanges: true
        preload: true
        onLoaded: win._applyThemeMode(text())
        onFileChanged: reload()
        onTextChanged: win._applyThemeMode(text())
        onLoadFailed: {
            win.isDarkMode = true
            setText("dark")
        }
    }

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
    property string profileImage: Config.PROFILE_IMG
    property bool batteryCardActive: false
    property int topGap: 21
    property int rightGap: 10
    property int panelW: 520
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
            height: Math.ceil(layout.implicitHeight + 24)
            radius: 12
            color: theme.bgMain
            layer.enabled: enterAnim.running || exitAnim.running

            // ANIMATION TRANSFORM
            transform: Translate { id: panelTranslate }

            // Slide UP (Enter)
            ParallelAnimation {
                id: enterAnim
                NumberAnimation {
                    target: panelTranslate
                    property: "y"
                    from: panel.height; to: 0
                    duration: 300
                    easing.type: Easing.OutCubic 
                }
                NumberAnimation {
                    target: panel
                    property: "opacity"
                    from: 0; to: 1
                    duration: 300
                }
            }

            // Slide DOWN (Exit)
            ParallelAnimation {
                id: exitAnim
                onFinished: win.visible = false // Actually hide window here
                NumberAnimation {
                    target: panelTranslate
                    property: "y"
                    from: 0; to: panel.height
                    duration: 200
                    easing.type: Easing.InCubic // Accelerate out
                }
                NumberAnimation {
                    target: panel
                    property: "opacity"
                    from: 1; to: 0
                    duration: 100
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

            // HEADER (USER, THEME SWITC, SS, POWER)
                Header {
                    id: header
                    theme: theme
                    Layout.fillWidth: true
                    profileName: win.profileName
                    profileImage: win.profileImage
                    active: win.visible
                    onCloseRequested: closeAll()
                    onPowerAction: function(act, lbl) {
                        header.expanded = false
                        executeAction(act)
                    }
                }
            
            // MEDIA CARD
                MediaCard {
                    id: media
                    Layout.fillWidth: true
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
            }
        }
    }
}