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

    // Bar height + gap excluded from hub window
    property int barStrip: 2

    // Hub theme: default is always dark
    property bool isDarkMode: true
    readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"

    function _applyThemeMode(raw) {
    var m = String(raw || "").trim().toLowerCase()

    // default to dark on empty/garbage
    win.isDarkMode = (m !== "light")
}

    FileView {
        id: themeModeFile
        path: win._themeModePath
        watchChanges: true
        preload: true

        // Initial load
        onLoaded: win._applyThemeMode(text())

        // If the file changes on disk, reload it 
        onFileChanged: reload()

        // When reload completes, apply new text
        onTextChanged: win._applyThemeMode(text())

        // If the file isn't there yet, create it once
        onLoadFailed: {
            win.isDarkMode = true
            setText("dark")   // creates the file
            // setText() will trigger a save; fileChanged/textChanged will handle the rest
        }
    }

    
    // Theme engine 
    Lib.ThemeEngine {
        id: theme
        isDarkMode: win.isDarkMode
    }

    // Make this window start below the bar so the bar stays clickable
    anchors { top: true; bottom: true; left: true; right: true }
    margins { top: barStrip }

    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay

    focusable: visible
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None


    property string profileName: Config.PROFILE_NAME
    property string profileImage: Config.PROFILE_IMG

    property int topGap: 1
    property int rightGap: 10
    property int panelW: 340

    Item {
        id: root
        anchors.fill: parent
        focus: true

        onVisibleChanged: if (win.visible) root.forceActiveFocus()
        Keys.onEscapePressed: win.visible = false

        // Clicking anywhere in this window closes hub
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            preventStealing: true
            onPressed: win.visible = false
        }

        Rectangle {
            id: panel
            width: win.panelW
            height: Math.ceil(layout.implicitHeight + 24)
            radius: Theme.radiusOuter
            // THIS CONTROLS TRANSPARENCY OF HUB BACKGROUND
            color: theme.bgMain
            border.width: 1
            border.color: theme.border

            anchors {
                right: parent.right
                top: parent.top
                rightMargin: win.rightGap
                topMargin: win.topGap
            }

            // Swallow clicks inside panel
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
                    theme: theme
                    Layout.fillWidth: true
                    profileName: win.profileName
                    profileImage: win.profileImage
                    active: win.visible
                    onCloseRequested: win.visible = false
                }

                ButtonsSlidersCard {
                    id: buttons
                    Layout.fillWidth: true
                    active: win.visible
                    theme: theme
                    onCloseRequested: win.visible = false
                }

                MediaCard {
                    id: media
                    Layout.fillWidth: true
                    onCloseRequested: win.visible = false
                }

                CalendarWeatherCard {
                    Layout.fillWidth: true
                    active: win.visible
                    theme: theme
                    onCloseRequested: win.visible = false
                }

                NotificationsCard {
                    id: notifs
                    Layout.fillWidth: true
                    active: win.visible
                    compactMode: media.visible
                    dndActive: buttons.dnd
                    theme: theme
                }
            }
        }
    }
}