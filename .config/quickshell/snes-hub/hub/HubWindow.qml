import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme.js" as Theme
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
    win.visible = false
}
    onVisibleChanged: {
    setBordersHidden(visible)
    if (!visible) {
        win.batteryCardActive = false
        if (header) header.expanded = false
    } else {
        root.forceActiveFocus()
    }
}


    property int barStrip: 2
    property bool isDarkMode: true
    readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"

    function _applyThemeMode(raw) {
        var m = String(raw || "").trim().toLowerCase()
        win.isDarkMode = (m !== "light")
    }

    // Theme toggle watcher
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
        isDarkMode: win.isDarkMode
    }

    margins { top: barStrip }
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: visible
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property string profileName: Config.PROFILE_NAME
    property string profileImage: Config.PROFILE_IMG
    property bool batteryCardActive: false
    property int topGap: 8
    property int rightGap: 10
    property int panelW: 320

    function executeAction(action) {
        var cmd = ""
        switch(action) {
            case "shutdown":  cmd = "systemctl poweroff"; break;
            case "reboot":    cmd = "systemctl reboot"; break;
            case "hibernate": cmd = "systemctl hibernate"; break;
            case "suspend":   cmd = "mpc -q pause; amixer set Master mute; systemctl suspend"; break;
            case "logout":    cmd = "hyprctl dispatch exit"; break;
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
            radius: Theme.radiusOuter
            color: theme.bgMain
            border.width: 1
            border.color: theme.border

            anchors {
                right: parent.right
                top: parent.top
                rightMargin: win.rightGap
                topMargin: win.topGap
            }

            // block clicks inside panel from closing
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                preventStealing: true
                onPressed: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                id: layout
                anchors.fill: parent
                anchors.margins: 12
                spacing: Theme.gapCard

                Header {
                    id: header
                    theme: theme
                    Layout.fillWidth: true
                    profileName: win.profileName
                    profileImage: win.profileImage
                    active: win.visible
                    onCloseRequested: closeAll()

                    onPowerAction: function(act, lbl) {
                        // collapse the expanded header immediately
                        header.expanded = false
                        executeAction(act)
                    }
                }

                ButtonsSlidersCard {
                    id: buttons
                    Layout.fillWidth: true
                    active: win.visible
                    theme: theme
                    onCloseRequested: closeAll()
                    onBatteryToggleRequested: win.batteryCardActive = !win.batteryCardActive
                }

                BatteryHealthCard {
                    id: battery
                    Layout.fillWidth: true
                    active: win.batteryCardActive
                    theme: theme
                }

                MediaCard {
                    id: media
                    Layout.fillWidth: true
                    onCloseRequested: closeAll()
                }

                CalendarWeatherCard {
                    Layout.fillWidth: true
                    active: win.visible
                    theme: theme
                    onCloseRequested: closeAll()
                }

                NotificationsCard {
                    id: notifs
                    Layout.fillWidth: true
                    active: win.visible
                    compactMode: media.visible || battery.visible || header.expanded
                    dndActive: buttons.dnd
                    theme: theme
                }
            }
        }
    }
}
